<script lang="ts">
	type CardHit = {
		oracle_id: string;
		name: string;
		mana_cost: string | null;
		type_line: string | null;
		oracle_text: string | null;
		power: string | null;
		toughness: string | null;
		loyalty: string | null;
		similarity: number;
	};
	type Filters = { excludeTypes?: string[]; legalIn?: string };
	type Result = { semanticQuery: string; filters: Filters; cards: CardHit[] };

	let query = $state('');
	let busy = $state(false);
	let error = $state('');
	let result = $state<Result | null>(null);

	const filterChips = (f: Filters): string[] => {
		const chips: string[] = [];
		for (const t of f.excludeTypes ?? []) chips.push(`senza ${t}`);
		if (f.legalIn) chips.push(`legali in ${f.legalIn}`);
		return chips;
	};

	async function search() {
		const q = query.trim();
		if (!q || busy) return;
		error = '';
		busy = true;
		try {
			const res = await fetch('/api/search', {
				method: 'POST',
				headers: { 'content-type': 'application/json' },
				body: JSON.stringify({ query: q })
			});
			const body = await res.json();
			if (!res.ok) throw new Error(body.error ?? `HTTP ${res.status}`);
			result = body as Result;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Errore sconosciuto';
			result = null;
		} finally {
			busy = false;
		}
	}

	function onKey(e: KeyboardEvent) {
		if (e.key === 'Enter') {
			e.preventDefault();
			search();
		}
	}
</script>

<svelte:head><title>manajudge — ricerca carte</title></svelte:head>

<main>
	<header>
		<h1>🔍 Ricerca carte</h1>
		<a class="ghost" href="/">⚖️ Giudice</a>
	</header>
	<p class="sub">Cerca carte per <em>effetto</em> in linguaggio naturale. Es. "carte che copiano gli spell avversari", "ramp senza usare terre in modern".</p>

	<div class="composer">
		<input
			bind:value={query}
			onkeydown={onKey}
			placeholder="Cosa devono fare le carte?"
			disabled={busy}
		/>
		<button onclick={search} disabled={busy || !query.trim()}>{busy ? 'Cerco…' : 'Cerca'}</button>
	</div>

	{#if error}<div class="error">⚠️ {error}</div>{/if}

	{#if result}
		<div class="intent">
			<span class="label">Intento:</span> <strong>{result.semanticQuery}</strong>
			{#each filterChips(result.filters) as chip}<span class="chip">{chip}</span>{/each}
		</div>

		{#if result.cards.length === 0}
			<p class="empty">Nessuna carta trovata con questi criteri.</p>
		{:else}
			<div class="grid">
				{#each result.cards as c (c.oracle_id)}
					<div class="card">
						<div class="card-head">
							<strong>{c.name}</strong>
							<span class="mana">{c.mana_cost ?? ''}</span>
						</div>
						<div class="type">{c.type_line ?? ''}</div>
						{#if c.oracle_text}<div class="oracle">{c.oracle_text}</div>{/if}
						<div class="foot">
							{#if c.power}<span class="pt">{c.power}/{c.toughness}</span>{/if}
							{#if c.loyalty}<span class="pt">Lealtà {c.loyalty}</span>{/if}
							<span class="sim" title="similarità semantica">{(c.similarity * 100).toFixed(0)}%</span>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	{/if}
</main>

<style>
	:global(body) {
		margin: 0;
		background: #f6f8fa;
		font-family: ui-sans-serif, system-ui, -apple-system, sans-serif;
		color: #1f2328;
	}
	main {
		max-width: 960px;
		margin: 0 auto;
		padding: 1.5rem 1rem 2rem;
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
	.composer {
		display: flex;
		gap: 0.5rem;
	}
	input {
		flex: 1;
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
	.ghost {
		color: #0969da;
		border: 1px solid #d0d7de;
		border-radius: 8px;
		padding: 0.35rem 0.75rem;
		font-size: 0.85rem;
		text-decoration: none;
	}
	.intent {
		margin: 1rem 0;
		font-size: 0.9rem;
		color: #24292f;
	}
	.intent .label {
		color: #57606a;
	}
	.chip {
		display: inline-block;
		margin-left: 0.4rem;
		font-size: 0.75rem;
		background: #eaeef2;
		border-radius: 999px;
		padding: 0.1rem 0.55rem;
		color: #24292f;
	}
	.empty {
		color: #57606a;
		font-size: 0.9rem;
	}
	.grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
		gap: 0.75rem;
	}
	.card {
		background: #fff;
		border: 1px solid #d0d7de;
		border-radius: 10px;
		padding: 0.7rem 0.8rem;
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
	}
	.card-head {
		display: flex;
		justify-content: space-between;
		gap: 0.5rem;
	}
	.mana {
		color: #57606a;
		font-size: 0.8rem;
		white-space: nowrap;
	}
	.type {
		color: #57606a;
		font-size: 0.78rem;
	}
	.oracle {
		font-size: 0.82rem;
		line-height: 1.4;
		white-space: pre-wrap;
	}
	.foot {
		margin-top: auto;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding-top: 0.3rem;
	}
	.pt {
		font-size: 0.78rem;
		font-weight: 600;
	}
	.sim {
		margin-left: auto;
		font-size: 0.72rem;
		color: #1a7f37;
		border: 1px solid #1a7f3733;
		border-radius: 999px;
		padding: 0.05rem 0.45rem;
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
</style>
