/**
 * Token device anonimo per il client web demo. Generato e persistito in localStorage al
 * primo uso; inviato come `Authorization: Bearer <token>` su ogni chiamata alle superfici AI,
 * così il Backend identifica lo User e conta le AI Request (ADR 0002). L'app Flutter farà
 * l'equivalente con un token in secure storage.
 */
const KEY = 'manajudge_device_token';

export function deviceToken(): string {
	if (typeof localStorage === 'undefined') return 'web-ssr';
	let token = localStorage.getItem(KEY);
	if (!token) {
		token = crypto.randomUUID();
		localStorage.setItem(KEY, token);
	}
	return token;
}

/** Header di autenticazione (device token) da aggiungere alle fetch verso le superfici AI. */
export function authHeaders(): Record<string, string> {
	return { Authorization: `Bearer ${deviceToken()}` };
}
