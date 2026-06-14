import type { Handle } from '@sveltejs/kit';
import { getOrCreateUser } from '$lib/server/users';

/** Header alternativo all'Authorization per il device token anonimo. */
const DEVICE_HEADER = 'x-device-id';

/**
 * Identity middleware (ADR 0002). Ogni richiesta può portare un'identità User anonima,
 * device-scoped, come `Authorization: Bearer <token>` oppure header `X-Device-Id`. Al primo
 * contatto crea la riga `users` ed espone lo User su `event.locals.user`. Nessuna enforcement:
 * gli endpoint AI lo usano per il metering (issue #5); il gating arriva con la #12.
 */
export const handle: Handle = async ({ event, resolve }) => {
	const auth = event.request.headers.get('authorization');
	const bearer = auth?.toLowerCase().startsWith('bearer ') ? auth.slice(7).trim() : null;
	const token = bearer || event.request.headers.get(DEVICE_HEADER);

	if (token) {
		event.locals.user = getOrCreateUser(token);
	}

	return resolve(event);
};
