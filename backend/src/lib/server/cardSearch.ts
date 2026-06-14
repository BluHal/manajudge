import type { Database as DB } from 'better-sqlite3';
import { getDb, toVecBlob } from './db.ts';
import { embed } from './embeddings.ts';
import { preprocessSearch } from './preprocessSearch.ts';
import type { LLMProvider } from './llm/provider.ts';
import type { Card } from './cards.ts';

/** Una carta restituita dalla Card Search, con la similarità del suo miglior vettore. */
export type CardHit = Card & { similarity: number };

/** Filtri strutturati estratti dalla query (tutti opzionali). */
export type CardFilters = {
	/** Esclude le carte il cui type_line contiene uno di questi tipi (es. ['Land']). */
	excludeTypes?: string[];
	/** Tiene solo le carte legali nel formato indicato (es. 'modern'). */
	legalIn?: string;
};

const CARD_COLS = 'oracle_id, name, mana_cost, type_line, oracle_text, power, toughness, loyalty';

/**
 * Traduce i filtri in un insieme di oracle_id candidati interrogando la tabella `cards`
 * con SQL pieno. Restituisce `null` se nessun filtro è attivo (= nessuna restrizione).
 */
function candidateOracleIds(db: DB, filters: CardFilters): string[] | null {
	const where: string[] = [];
	const params: unknown[] = [];

	for (const t of filters.excludeTypes ?? []) {
		where.push('type_line NOT LIKE ?');
		params.push(`%${t}%`);
	}

	if (filters.legalIn) {
		where.push(`json_extract(legalities, '$.' || ?) = 'legal'`);
		params.push(filters.legalIn);
	}

	if (where.length === 0) return null;
	const rows = db
		.prepare(`SELECT oracle_id FROM cards WHERE ${where.join(' AND ')}`)
		.all(...params) as Array<{ oracle_id: string }>;
	return rows.map((r) => r.oracle_id);
}

/**
 * Ricerca per effetto: KNN su `vec_cards` (multi-vettore) con max-pool per `oracle_id`,
 * così una carta è rankata col suo vettore migliore (core o ruling). I filtri strutturati
 * pre-filtrano i candidati *prima* della KNN (filtra-poi-ranka). Vedi docs/adr/0001.
 */
export function searchCards(db: DB, queryVec: number[], filters: CardFilters, topN = 20): CardHit[] {
	const candidates = candidateOracleIds(db, filters);
	if (candidates !== null && candidates.length === 0) return [];

	const pool = topN * 10;
	let sql = `SELECT oracle_id, distance FROM vec_cards WHERE embedding MATCH ?`;
	const params: unknown[] = [toVecBlob(queryVec)];
	if (candidates !== null) {
		sql += ` AND oracle_id IN (${candidates.map(() => '?').join(',')})`;
		params.push(...candidates);
	}
	sql += ` ORDER BY distance LIMIT ?`;
	params.push(pool);
	const knn = db.prepare(sql).all(...params) as Array<{ oracle_id: string; distance: number }>;

	// Max-pool: distanza minima (= similarità massima) per oracle_id.
	const best = new Map<string, number>();
	for (const row of knn) {
		const cur = best.get(row.oracle_id);
		if (cur === undefined || row.distance < cur) best.set(row.oracle_id, row.distance);
	}

	const ranked = [...best.entries()].sort((a, b) => a[1] - b[1]).slice(0, topN);

	const getCard = db.prepare(`SELECT ${CARD_COLS} FROM cards WHERE oracle_id = ?`);
	return ranked.map(([oracle_id, distance]) => {
		const card = getCard.get(oracle_id) as Card;
		return { ...card, similarity: 1 - (distance * distance) / 2 };
	});
}

export type CardSearchResult = {
	/** L'intento semantico estratto dalla query (utile da mostrare in UI). */
	semanticQuery: string;
	filters: CardFilters;
	cards: CardHit[];
};

/**
 * Orchestrazione completa della Card Search: preprocess LLM (intento + filtri) ->
 * embedding dell'intento -> retrieval con max-pool e filtra-poi-ranka. È il punto
 * d'ingresso riusabile (endpoint oggi, companion app domani). Vedi docs/adr/0001.
 */
export async function runCardSearch(llm: LLMProvider, query: string, topN = 20): Promise<CardSearchResult> {
	const { semanticQuery, filters } = await preprocessSearch(llm, query);
	const queryVec = await embed(semanticQuery);
	const cards = searchCards(getDb(), queryVec, filters, topN);
	return { semanticQuery, filters, cards };
}
