import type { LLMProvider } from './llm/provider.ts';
import type { CardFilters } from './cardSearch.ts';

/** Esito del preprocess della Card Search: intento da embeddare + filtri strutturati. */
export type SearchQuery = {
	/** La query ripulita dall'intento, da passare all'embedding (es. "carte che fanno ramp"). */
	semanticQuery: string;
	/** Filtri strutturati estratti dal linguaggio naturale. */
	filters: CardFilters;
};

/** Forma grezza attesa dall'LLM. */
type Raw = {
	intento?: string;
	escludi_tipi?: string[];
	formato?: string | null;
};

const SYSTEM = `Prepari una ricerca semantica di carte Magic: The Gathering.
Data la query dell'utente in linguaggio naturale, restituisci SOLO un oggetto JSON con:
- "intento": la descrizione dell'EFFETTO cercato, ripulita dai vincoli strutturali (es. "carte che fanno ramp senza usare terre in modern" -> "carte che fanno ramp"). Mantieni la lingua dell'utente.
- "escludi_tipi": array di tipi di carta da ESCLUDERE, dedotti da negazioni (es. "senza terre" -> ["Land"], "non creature" -> ["Creature"]). I tipi vanno in INGLESE e con l'iniziale maiuscola. Se nessuno, usa [].
- "formato": il formato di gioco se citato, in minuscolo inglese (es. "in modern" -> "modern", "legale in commander" -> "commander"). Se nessuno, usa null.`;

/** Estrae intento semantico e filtri strutturati dalla query. Su errore: query grezza, nessun filtro. */
export async function preprocessSearch(llm: LLMProvider, query: string): Promise<SearchQuery> {
	try {
		const out = await llm.completeJSON<Raw>({ system: SYSTEM, prompt: query });
		const filters: CardFilters = {};
		const excludeTypes = Array.isArray(out.escludi_tipi) ? out.escludi_tipi.filter(Boolean) : [];
		if (excludeTypes.length) filters.excludeTypes = excludeTypes;
		if (out.formato) filters.legalIn = out.formato;
		return {
			semanticQuery: out.intento?.trim() || query,
			filters
		};
	} catch {
		return { semanticQuery: query, filters: {} };
	}
}
