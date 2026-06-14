/** Messaggio di conversazione neutro rispetto al provider. */
export type ChatMessage = { role: 'user' | 'model'; text: string };

/**
 * Astrazione del modello LLM. Permette di sostituire Gemini con Groq/Ollama
 * senza toccare la logica del giudice.
 */
export interface LLMProvider {
	/** Una risposta JSON strutturata (non in streaming). Usata per la pre-elaborazione. */
	completeJSON<T>(opts: { system?: string; prompt: string }): Promise<T>;

	/** Risposta in streaming token-per-token. Usata per la risposta del giudice. */
	stream(opts: { system?: string; messages: ChatMessage[] }): AsyncIterable<string>;
}
