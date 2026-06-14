import type { RequestHandler } from './$types';
import { gemini } from '$lib/server/llm/gemini';
import { runCardSearch } from '$lib/server/cardSearch';
import { incrementAiRequest } from '$lib/server/users';

/**
 * POST { query } -> JSON { semanticQuery, filters, cards }.
 * Ricerca semantica di carte per effetto (vedi docs/adr/0001). A differenza del giudice,
 * la risposta è una lista di carte reali, non testo generato in streaming.
 * Ogni ricerca è una AI Request: richiede l'identità User e incrementa il contatore.
 */
export const POST: RequestHandler = async ({ request, locals }) => {
	if (!locals.user) {
		return new Response(JSON.stringify({ error: 'device token mancante' }), {
			status: 401,
			headers: { 'content-type': 'application/json' }
		});
	}

	const { query } = (await request.json()) as { query?: string };

	if (!query || typeof query !== 'string') {
		return new Response(JSON.stringify({ error: 'query mancante' }), {
			status: 400,
			headers: { 'content-type': 'application/json' }
		});
	}

	try {
		const result = await runCardSearch(gemini, query);
		// Ricerca andata a buon fine = una AI Request (#5, nessun gating).
		incrementAiRequest(locals.user.id, 'search');
		return new Response(JSON.stringify(result), {
			headers: { 'content-type': 'application/json', 'cache-control': 'no-store' }
		});
	} catch (err) {
		const msg = err instanceof Error ? err.message : 'Errore interno';
		return new Response(JSON.stringify({ error: msg }), {
			status: 500,
			headers: { 'content-type': 'application/json' }
		});
	}
};
