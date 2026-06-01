import type { Handle } from '@sveltejs/kit';

/**
 * Gate di accesso (HTTP Basic Auth) per il deploy pubblico su HF Spaces.
 *
 * Lo Space è pubblico, quindi senza protezione chiunque potrebbe consumare la quota
 * gratuita di Gemini. Se è impostata la variabile APP_PASSWORD, ogni richiesta deve
 * presentare quella password via Basic Auth (username ignorato). Se APP_PASSWORD non è
 * impostata (es. sviluppo locale) il gate è disattivato e tutto passa liberamente.
 */
const PASSWORD = process.env.APP_PASSWORD;

export const handle: Handle = async ({ event, resolve }) => {
	if (PASSWORD) {
		const auth = event.request.headers.get('authorization');
		if (!auth?.startsWith('Basic ')) {
			return unauthorized();
		}
		const decoded = Buffer.from(auth.slice('Basic '.length), 'base64').toString('utf-8');
		const password = decoded.slice(decoded.indexOf(':') + 1);
		if (password !== PASSWORD) {
			return unauthorized();
		}
	}
	return resolve(event);
};

function unauthorized(): Response {
	return new Response('Autenticazione richiesta', {
		status: 401,
		headers: { 'www-authenticate': 'Basic realm="manajudge", charset="UTF-8"' }
	});
}
