import type { RequestHandler } from './$types';
import { getUsage } from '$lib/server/users';

/**
 * GET -> JSON snapshot dell'uso del caller: { plan, used, remaining, ... }.
 * Osservabilità del metering (#5): il conteggio AI Request è interrogabile per User.
 * Richiede l'identità User (device token via Authorization: Bearer o X-Device-Id).
 */
export const GET: RequestHandler = async ({ locals }) => {
	if (!locals.user) {
		return new Response(JSON.stringify({ error: 'device token mancante' }), {
			status: 401,
			headers: { 'content-type': 'application/json' }
		});
	}

	return new Response(JSON.stringify(getUsage(locals.user.id)), {
		headers: { 'content-type': 'application/json', 'cache-control': 'no-store' }
	});
};
