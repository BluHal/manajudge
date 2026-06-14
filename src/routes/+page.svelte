<script lang="ts">
	type Source = { rule_id: string; header_path: string; text: string };
	type CardRef = { name: string; oracle_text: string | null; type_line: string | null };
	type Meta = { rewritten: string; confidence: 'alta' | 'media' | 'bassa'; cards: CardRef[]; sources: Source[] };
	type Msg = {
		role: 'user' | 'model';
		text: string;
		meta?: Meta;
		showSources?: boolean;
	};

	let messages = $state<Msg[]>([]);
	let input = $state('');
	let busy = $state(false);
	let error = $state('');

	const confColor = (c: string) => (c === 'alta' ? '#1a7f37' : c === 'media' ? '#9a6700' : '#cf222e');
	const confLabel = (c: string) => (c === 'alta' ? 'Confidenza alta' : c === 'media' ? 'Confidenza media' : 'Bassa confidenza');

	function reset() {
		messages = [];
		error = '';
	}

	async function send() {
		const text = input.trim();
		if (!text || busy) return;
		error = '';
		input = '';
		busy = true;

		const history = messages.map((m) => ({ role: m.role, text: m.text }));
		messages = [...messages, { role: 'user', text }, { role: 'model', text: '' }];
		const idx = messages.length - 1;

		try {
			const res = await fetch('/api/chat', {
				method: 'POST',
				headers: { 'content-type': 'application/json' },
				body: JSON.stringify({ message: text, history })
			});

			if (!res.ok || !res.body) {
				const body = await res.json().catch(() => ({ error: `HTTP ${res.status}` }));
				throw new Error(body.error ?? `HTTP ${res.status}`);
			}

			const reader = res.body.getReader();
			const decoder = new TextDecoder();
			let buffer = '';
			let metaParsed = false;

			while (true) {
				const { done, value } = await reader.read();
				if (done) break;
				buffer += decoder.decode(value, { stream: true });

				if (!metaParsed) {
					const nl = buffer.indexOf('\n');
					if (nl === -1) continue;
					messages[idx].meta = JSON.parse(buffer.slice(0, nl));
					buffer = buffer.slice(nl + 1);
					metaParsed = true;
				}
				messages[idx].text += buffer;
				buffer = '';
			}
		} catch (e) {
			error = e instanceof Error ? e.message : 'Errore sconosciuto';
			messages = messages.slice(0, -1); // rimuove la bolla vuota del giudice
		} finally {
			busy = false;
		}
	}

	function onKey(e: KeyboardEvent) {
		if (e.key === 'Enter' && !e.shiftKey) {
			e.preventDefault();
			send();
		}
	}
</script>

<svelte:head><title>manajudge — giudice MTG</title></svelte:head>

<main>
	<header>
		<h1>⚖️ manajudge</h1>
		<div class="nav">
			<a class="ghost" href="/search">🔍 Ricerca carte</a>
			<button class="ghost" onclick={reset} disabled={busy || messages.length === 0}>Nuova chat</button>
		</div>
	</header>
	<p class="sub">Giudice AI per Magic: The Gathering. Chiedi di regole e interazioni tra carte.</p>

	<div class="chat">
		{#if messages.length === 0}
			<div class="empty">
				<p>Esempi:</p>
				<ul>
					<li>Come interagiscono Lightning Bolt e una creatura con protection from red?</li>
					<li>Come funziona la priorità sullo stack?</li>
					<li>Trample e deathtouch insieme: quanto danno assegno?</li>
				</ul>
			</div>
		{/if}

		{#each messages as m, i (i)}
			<div class="msg {m.role}">
				<div class="bubble">
					{#if m.text}
						<span class="text">{m.text}</span>
					{:else if busy && i === messages.length - 1}
						<span class="dots">il giudice sta valutando…</span>
					{/if}

					{#if m.meta}
						<div class="meta">
							<span class="badge" style="--c:{confColor(m.meta.confidence)}">{confLabel(m.meta.confidence)}</span>
							{#if m.meta.sources.length || m.meta.cards.length}
								<button class="link" onclick={() => (m.showSources = !m.showSources)}>
									{m.showSources ? 'Nascondi fonti' : `Fonti (${m.meta.sources.length} regole, ${m.meta.cards.length} carte)`}
								</button>
							{/if}
						</div>
						{#if m.showSources}
							<div class="sources">
								{#if m.meta.cards.length}
									<h4>Carte</h4>
									{#each m.meta.cards as c}
										<div class="src"><strong>{c.name}</strong> — {c.type_line}<br /><em>{c.oracle_text}</em></div>
									{/each}
								{/if}
								{#if m.meta.sources.length}
									<h4>Comprehensive Rules</h4>
									{#each m.meta.sources as s}
										<div class="src"><strong>{s.rule_id}</strong> <span class="hp">{s.header_path}</span><br />{s.text}</div>
									{/each}
								{/if}
							</div>
						{/if}
					{/if}
				</div>
			</div>
		{/each}
	</div>

	{#if error}<div class="error">⚠️ {error}</div>{/if}

	<div class="composer">
		<textarea
			bind:value={input}
			onkeydown={onKey}
			placeholder="Scrivi la tua domanda da giudice…"
			rows="2"
			disabled={busy}
		></textarea>
		<button onclick={send} disabled={busy || !input.trim()}>Invia</button>
	</div>
</main>

<style>
	:global(body) {
		margin: 0;
		background: #f6f8fa;
		font-family: ui-sans-serif, system-ui, -apple-system, sans-serif;
		color: #1f2328;
	}
	main {
		max-width: 760px;
		margin: 0 auto;
		padding: 1.5rem 1rem 2rem;
		display: flex;
		flex-direction: column;
		min-height: 100vh;
	}
	header {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}
	h1 {
		font-size: 1.4rem;
		margin: 0;
	}
	.sub {
		color: #57606a;
		margin: 0.25rem 0 1rem;
		font-size: 0.9rem;
	}
	.chat {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}
	.empty {
		color: #57606a;
		font-size: 0.9rem;
		background: #fff;
		border: 1px solid #d0d7de;
		border-radius: 10px;
		padding: 1rem;
	}
	.empty ul {
		margin: 0.5rem 0 0;
		padding-left: 1.2rem;
	}
	.empty li {
		margin: 0.3rem 0;
	}
	.msg {
		display: flex;
	}
	.msg.user {
		justify-content: flex-end;
	}
	.bubble {
		max-width: 88%;
		padding: 0.7rem 0.9rem;
		border-radius: 12px;
		border: 1px solid #d0d7de;
		background: #fff;
		white-space: pre-wrap;
		line-height: 1.45;
	}
	.msg.user .bubble {
		background: #0969da;
		color: #fff;
		border-color: #0969da;
	}
	.dots {
		color: #57606a;
		font-style: italic;
	}
	.meta {
		margin-top: 0.6rem;
		display: flex;
		gap: 0.75rem;
		align-items: center;
		flex-wrap: wrap;
	}
	.badge {
		font-size: 0.72rem;
		font-weight: 600;
		color: var(--c);
		border: 1px solid var(--c);
		border-radius: 999px;
		padding: 0.1rem 0.55rem;
	}
	.link {
		background: none;
		border: none;
		color: #0969da;
		cursor: pointer;
		font-size: 0.8rem;
		padding: 0;
	}
	.sources {
		margin-top: 0.6rem;
		border-top: 1px solid #eaeef2;
		padding-top: 0.5rem;
		font-size: 0.82rem;
		color: #24292f;
	}
	.sources h4 {
		margin: 0.6rem 0 0.3rem;
		font-size: 0.78rem;
		text-transform: uppercase;
		color: #57606a;
		letter-spacing: 0.03em;
	}
	.src {
		padding: 0.35rem 0;
		border-bottom: 1px dashed #eaeef2;
	}
	.src .hp {
		color: #57606a;
		font-size: 0.75rem;
	}
	.error {
		background: #ffebe9;
		border: 1px solid #ff818266;
		color: #cf222e;
		padding: 0.6rem 0.8rem;
		border-radius: 8px;
		margin: 0.75rem 0;
		font-size: 0.9rem;
	}
	.composer {
		display: flex;
		gap: 0.5rem;
		margin-top: 1rem;
		position: sticky;
		bottom: 0.5rem;
	}
	textarea {
		flex: 1;
		resize: vertical;
		padding: 0.6rem 0.7rem;
		border-radius: 10px;
		border: 1px solid #d0d7de;
		font: inherit;
		background: #fff;
	}
	button {
		background: #0969da;
		color: #fff;
		border: none;
		border-radius: 10px;
		padding: 0 1.1rem;
		font-weight: 600;
		cursor: pointer;
	}
	button:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}
	.nav {
		display: flex;
		gap: 0.5rem;
		align-items: center;
	}
	a.ghost {
		color: #0969da;
		border: 1px solid #d0d7de;
		border-radius: 10px;
		padding: 0.35rem 0.75rem;
		font-size: 0.85rem;
		text-decoration: none;
	}
	button.ghost {
		background: none;
		color: #0969da;
		border: 1px solid #d0d7de;
		padding: 0.35rem 0.75rem;
		font-size: 0.85rem;
	}
</style>
