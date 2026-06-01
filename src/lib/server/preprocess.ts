import type { ChatMessage, LLMProvider } from './llm/provider.ts';

export type Preprocessed = {
	/** L'ultimo messaggio reso una domanda autonoma (in italiano), risolti i riferimenti. */
	domanda_riscritta: string;
	/** Nomi di carte Magic citati, normalizzati al nome ufficiale inglese. */
	carte_citate: string[];
	/** Terminologia di regole MTG in INGLESE rilevante (per potenziare il retrieval EN). */
	termini_inglesi: string[];
};

const SYSTEM = `Prepari le domande per un giudice di Magic: The Gathering.
Dato lo storico della chat e l'ultimo messaggio dell'utente, restituisci SOLO un oggetto JSON con:
- "domanda_riscritta": l'ultimo messaggio riformulato come domanda autonoma e completa in ITALIANO, risolvendo pronomi e riferimenti al contesto precedente (es. "e se invece fosse un Doom Blade?" va espanso usando la domanda precedente).
- "carte_citate": array dei nomi di CARTE Magic citate, normalizzati al nome UFFICIALE INGLESE (es. "Fulmine" -> "Lightning Bolt"). Non inventare carte e non includere parole comuni che non siano davvero nomi di carte. Se non ci sono carte, usa [].
- "termini_inglesi": array della terminologia di REGOLE pertinente, espressa in INGLESE come compare nelle Comprehensive Rules (es. "protezione dal rosso" -> ["protection", "protection from red"]; "indistruttibile" -> ["indestructible", "destroy"]; "tocco letale" -> ["deathtouch", "lethal damage"]; "priorità" -> ["priority"]). Includi parole chiave, azioni e zone rilevanti. Se nessuna, usa [].`;

function renderHistory(history: ChatMessage[]): string {
	if (history.length === 0) return '(nessuno)';
	return history
		.slice(-6)
		.map((m) => `${m.role === 'user' ? 'Utente' : 'Giudice'}: ${m.text}`)
		.join('\n');
}

/** Riscrive il follow-up ed estrae i nomi carta in un'unica chiamata LLM. */
export async function preprocess(
	llm: LLMProvider,
	history: ChatMessage[],
	message: string
): Promise<Preprocessed> {
	const prompt = `Storico:\n${renderHistory(history)}\n\nUltimo messaggio:\n${message}`;
	try {
		const out = await llm.completeJSON<Preprocessed>({ system: SYSTEM, prompt });
		return {
			domanda_riscritta: out.domanda_riscritta?.trim() || message,
			carte_citate: Array.isArray(out.carte_citate) ? out.carte_citate.filter(Boolean) : [],
			termini_inglesi: Array.isArray(out.termini_inglesi) ? out.termini_inglesi.filter(Boolean) : []
		};
	} catch {
		// In caso di errore, prosegui con il messaggio grezzo: il retrieval funziona comunque.
		return { domanda_riscritta: message, carte_citate: [], termini_inglesi: [] };
	}
}
