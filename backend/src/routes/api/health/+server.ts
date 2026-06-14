import type { RequestHandler } from './$types';
import { getDb } from '$lib/server/db';
import { embed } from '$lib/server/embeddings';

/**
 * GET -> readiness della VM warm (#4). Verifica che il DB sia raggiungibile e popolato e
 * forza il caricamento del modello di embedding in RAM (warm: niente cold start sulle
 * superfici AI). Pensato per l'healthcheck del deploy: chiamandolo a boot la VM resta calda.
 * Non richiede identità User.
 */
export const GET: RequestHandler = async () => {
	const started = Date.now();
	try {
		const db = getDb();
		const cards = (db.prepare('SELECT COUNT(*) AS n FROM cards').get() as { n: number }).n;
		const rules = (db.prepare('SELECT COUNT(*) AS n FROM rules').get() as { n: number }).n;

		// Forza il warm del modello: la prima chiamata lo carica, le successive sono veloci.
		const vec = await embed('health');

		const ready = cards > 0 && rules > 0 && vec.length > 0;
		return new Response(
			JSON.stringify({
				status: ready ? 'ok' : 'degraded',
				cards,
				rules,
				embedDim: vec.length,
				ms: Date.now() - started
			}),
			{
				status: ready ? 200 : 503,
				headers: { 'content-type': 'application/json', 'cache-control': 'no-store' }
			}
		);
	} catch (err) {
		const message = err instanceof Error ? err.message : 'errore sconosciuto';
		return new Response(JSON.stringify({ status: 'error', error: message }), {
			status: 503,
			headers: { 'content-type': 'application/json', 'cache-control': 'no-store' }
		});
	}
};
