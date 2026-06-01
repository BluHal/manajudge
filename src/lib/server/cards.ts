import { getDb } from './db.ts';

export type Card = {
	oracle_id: string;
	name: string;
	mana_cost: string | null;
	type_line: string | null;
	oracle_text: string | null;
	power: string | null;
	toughness: string | null;
	loyalty: string | null;
};

const COLS = 'oracle_id, name, mana_cost, type_line, oracle_text, power, toughness, loyalty';
// I segnalini/token/emblemi condividono il nome con carte vere: vanno deprioritizzati.
const TOKEN_LAYOUTS = "('token','double_faced_token','emblem','art_series')";
const IS_TOKEN = `(c.layout IN ${TOKEN_LAYOUTS})`;

function ftsMatch(name: string, joiner: 'AND' | 'OR'): Card | undefined {
	const tokens = name.toLowerCase().match(/[\p{L}\p{N}]+/gu) ?? [];
	if (tokens.length === 0) return undefined;
	const match = tokens.map((t) => `"${t}"`).join(` ${joiner} `);
	try {
		return getDb()
			.prepare(
				`SELECT ${COLS.split(', ')
					.map((c) => 'c.' + c)
					.join(', ')}
				 FROM cards_fts f JOIN cards c ON c.oracle_id = f.oracle_id
				 WHERE cards_fts MATCH ? ORDER BY ${IS_TOKEN}, bm25(cards_fts) LIMIT 1`
			)
			.get(match) as Card | undefined;
	} catch {
		return undefined;
	}
}

/** Risolve un nome (anche con piccole imprecisioni) al record carta canonico. */
export function resolveCard(name: string): Card | undefined {
	const db = getDb();
	const exact = db
		.prepare(`SELECT ${COLS} FROM cards c WHERE lower(name) = lower(?) ORDER BY ${IS_TOKEN} LIMIT 1`)
		.get(name) as Card | undefined;
	if (exact) return exact;
	// AND (tutti i token presenti) è più preciso; OR come ripiego.
	return ftsMatch(name, 'AND') ?? ftsMatch(name, 'OR');
}

/** Risolve una lista di nomi carta in record unici (per oracle_id). */
export function lookupCards(names: string[]): Card[] {
	const seen = new Set<string>();
	const out: Card[] = [];
	for (const name of names) {
		const card = resolveCard(name.trim());
		if (card && !seen.has(card.oracle_id)) {
			seen.add(card.oracle_id);
			out.push(card);
		}
	}
	return out;
}
