import { GoogleGenAI } from '@google/genai';
import type { ChatMessage, LLMProvider } from './provider.ts';

// Due modelli per usare bucket di rate-limit separati (free tier: pochi req/min per modello):
// il giudice usa il modello "forte", la pre-elaborazione un modello "lite" più veloce e con RPM più alto.
const JUDGE_MODEL = process.env.GEMINI_MODEL ?? 'gemini-2.5-flash-lite';
const FAST_MODEL = process.env.GEMINI_MODEL_FAST ?? 'gemini-2.5-flash-lite';

let _client: GoogleGenAI | null = null;
function client(): GoogleGenAI {
	if (!_client) {
		const apiKey = process.env.GEMINI_API_KEY;
		if (!apiKey) throw new Error('GEMINI_API_KEY mancante: copia .env.example in .env e inserisci la chiave.');
		_client = new GoogleGenAI({ apiKey });
	}
	return _client;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * Esegue `fn` ritentando sui 429 (free tier: pochi req/minuto). Rispetta il retryDelay
 * suggerito da Gemini quando presente, con un tetto di sicurezza.
 */
/** Errore "pulito" da mostrare all'utente quando il free tier è saturo. */
export class RateLimitError extends Error {
	constructor(public retryAfterS: number) {
		super(`Limite del free tier Gemini raggiunto. Riprova tra ~${retryAfterS}s.`);
		this.name = 'RateLimitError';
	}
}

function retryDelayFrom(msg: string): number | null {
	const m = msg.match(/retry(?:Delay)?["\s:]*?(\d+(?:\.\d+)?)s/i);
	return m ? parseFloat(m[1]) : null;
}

async function withRetry<T>(fn: () => Promise<T>, retries = 3): Promise<T> {
	for (let attempt = 0; ; attempt++) {
		try {
			return await fn();
		} catch (err) {
			const msg = err instanceof Error ? err.message : String(err);
			const is429 = msg.includes('429') || msg.includes('RESOURCE_EXHAUSTED');
			if (!is429) throw err;
			const delay = retryDelayFrom(msg);
			if (attempt >= retries) throw new RateLimitError(Math.ceil(delay ?? 30));
			const waitS = Math.min(delay ? delay + 1 : 5 * (attempt + 1), 60);
			await sleep(waitS * 1000);
		}
	}
}

/** Estrae il primo oggetto JSON da una stringa (robusto a eventuali ```json ... ```). */
function parseJson<T>(text: string): T {
	const cleaned = text.replace(/^```(?:json)?/i, '').replace(/```\s*$/, '').trim();
	const start = cleaned.indexOf('{');
	const end = cleaned.lastIndexOf('}');
	if (start < 0 || end < 0) throw new Error(`Risposta non-JSON dal modello: ${text.slice(0, 200)}`);
	return JSON.parse(cleaned.slice(start, end + 1)) as T;
}

export const gemini: LLMProvider = {
	async completeJSON<T>(opts: { system?: string; prompt: string }): Promise<T> {
		const res = await withRetry(() =>
			client().models.generateContent({
				model: FAST_MODEL,
				contents: opts.prompt,
				config: {
					systemInstruction: opts.system,
					responseMimeType: 'application/json',
					temperature: 0
				}
			})
		);
		return parseJson<T>(res.text ?? '');
	},

	async *stream(opts: { system?: string; messages: ChatMessage[] }): AsyncIterable<string> {
		const stream = await withRetry(() =>
			client().models.generateContentStream({
				model: JUDGE_MODEL,
				contents: opts.messages.map((m) => ({ role: m.role, parts: [{ text: m.text }] })),
				config: { systemInstruction: opts.system, temperature: 0.2 }
			})
		);
		for await (const chunk of stream) {
			const t = chunk.text;
			if (t) yield t;
		}
	}
};
