import type { RequestHandler } from './$types';
import { gemini } from '$lib/server/llm/gemini';
import { runJudge } from '$lib/server/judge';
import type { ChatMessage } from '$lib/server/llm/provider';

/**
 * POST { message, history } -> stream di testo.
 * La PRIMA riga della risposta è un JSON con i metadati (domanda riscritta, confidenza,
 * carte, fonti); tutto ciò che segue la prima newline è la risposta del giudice in streaming.
 */
export const POST: RequestHandler = async ({ request }) => {
	const { message, history } = (await request.json()) as {
		message: string;
		history?: ChatMessage[];
	};

	if (!message || typeof message !== 'string') {
		return new Response('message mancante', { status: 400 });
	}

	let result;
	try {
		result = await runJudge(gemini, history ?? [], message);
	} catch (err) {
		const msg = err instanceof Error ? err.message : 'Errore interno';
		return new Response(JSON.stringify({ error: msg }), {
			status: 500,
			headers: { 'content-type': 'application/json' }
		});
	}

	const meta = {
		rewritten: result.rewritten,
		confidence: result.confidence,
		cards: result.cards.map((c) => ({ name: c.name, oracle_text: c.oracle_text, type_line: c.type_line })),
		sources: result.sources
	};

	const stream = new ReadableStream<Uint8Array>({
		async start(controller) {
			const enc = new TextEncoder();
			controller.enqueue(enc.encode(JSON.stringify(meta) + '\n'));
			try {
				for await (const token of result.answer) {
					controller.enqueue(enc.encode(token));
				}
			} catch (err) {
				const msg = err instanceof Error ? err.message : 'Errore di streaming';
				controller.enqueue(enc.encode(`\n\n⚠️ ${msg}`));
			}
			controller.close();
		}
	});

	return new Response(stream, {
		headers: { 'content-type': 'text/plain; charset=utf-8', 'cache-control': 'no-store' }
	});
};
