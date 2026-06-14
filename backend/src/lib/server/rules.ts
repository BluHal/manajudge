import { getDb, toVecBlob } from './db.ts';
import { embed } from './embeddings.ts';

export type RuleHit = {
	rowid: number;
	rule_id: string;
	parent_id: string | null;
	header_path: string;
	text: string;
	kind: string;
	refs: string;
};

export type RetrievalResult = {
	hits: RuleHit[];
	confidence: 'alta' | 'media' | 'bassa';
	bestSimilarity: number;
};

type Row = RuleHit & { distance?: number };

const RRF_K = 60; // costante standard della Reciprocal Rank Fusion

/** Costruisce una query FTS5 MATCH dai termini significativi della domanda. */
function buildFtsMatch(query: string): string {
	const tokens = query.toLowerCase().match(/[\p{L}\p{N}.]+/gu) ?? [];
	const terms = tokens
		.filter((t) => t.length > 2)
		.map((t) => `"${t.replace(/"/g, '')}"`);
	return terms.length ? terms.join(' OR ') : '';
}

function vectorSearch(queryVec: number[], k: number): Row[] {
	// Il LIMIT deve stare sulla query KNN diretta a vec0 (non dopo un JOIN): uso una CTE.
	return getDb()
		.prepare(
			`WITH knn AS (
				SELECT rule_rowid, distance FROM vec_rules
				WHERE embedding MATCH ? ORDER BY distance LIMIT ?
			 )
			 SELECT r.rowid, r.rule_id, r.parent_id, r.header_path, r.text, r.kind, r.refs, knn.distance
			 FROM knn JOIN rules r ON r.rowid = knn.rule_rowid
			 ORDER BY knn.distance`
		)
		.all(toVecBlob(queryVec), k) as Row[];
}

function ftsSearch(match: string, k: number): Row[] {
	if (!match) return [];
	try {
		return getDb()
			.prepare(
				`SELECT r.rowid, r.rule_id, r.parent_id, r.header_path, r.text, r.kind, r.refs
				 FROM rules_fts JOIN rules r ON r.rowid = rules_fts.rowid
				 WHERE rules_fts MATCH ? ORDER BY bm25(rules_fts) LIMIT ?`
			)
			.all(match, k) as Row[];
	} catch {
		return []; // query FTS malformata: il lato vettoriale copre comunque
	}
}

/** Distanza L2 su vettori normalizzati -> similarità coseno. */
function l2ToCosine(distance: number): number {
	return 1 - (distance * distance) / 2;
}

function fetchByRuleIds(ruleIds: string[]): Row[] {
	if (ruleIds.length === 0) return [];
	const placeholders = ruleIds.map(() => '?').join(',');
	return getDb()
		.prepare(
			`SELECT rowid, rule_id, parent_id, header_path, text, kind, refs
			 FROM rules WHERE rule_id IN (${placeholders})`
		)
		.all(...ruleIds) as Row[];
}

/**
 * Ricerca ibrida sulle regole: vettoriale (sqlite-vec) + full-text (FTS5/BM25),
 * fuse con RRF, più espansione dei rimandi citati e uno score di confidenza.
 */
export async function retrieveRules(query: string, topN = 8): Promise<RetrievalResult> {
	const queryVec = await embed(query);
	const pool = Math.max(topN * 3, 20);
	const vec = vectorSearch(queryVec, pool);
	const fts = ftsSearch(buildFtsMatch(query), pool);

	// Reciprocal Rank Fusion: combina i ranking delle due liste.
	const scores = new Map<number, number>();
	const byRow = new Map<number, Row>();
	const add = (list: Row[]) =>
		list.forEach((row, rank) => {
			scores.set(row.rowid, (scores.get(row.rowid) ?? 0) + 1 / (RRF_K + rank));
			byRow.set(row.rowid, row);
		});
	add(vec);
	add(fts);

	const fused = [...scores.entries()]
		.sort((a, b) => b[1] - a[1])
		.slice(0, topN)
		.map(([rowid]) => byRow.get(rowid)!);

	// Espansione rimandi: aggiunge le regole citate dai migliori risultati.
	const present = new Set(fused.map((r) => r.rule_id));
	const refIds = new Set<string>();
	for (const r of fused.slice(0, 4)) {
		for (const ref of (r.refs || '').split(',').filter(Boolean)) {
			if (!present.has(ref)) refIds.add(ref);
		}
	}
	const expanded = fetchByRuleIds([...refIds].slice(0, 4)).filter((r) => !present.has(r.rule_id));

	const bestDistance = vec[0]?.distance;
	const bestSimilarity = bestDistance === undefined ? 0 : l2ToCosine(bestDistance);
	const confidence: RetrievalResult['confidence'] =
		bestSimilarity >= 0.45 ? 'alta' : bestSimilarity >= 0.3 ? 'media' : 'bassa';

	return {
		hits: [...fused, ...expanded].map(({ distance, ...h }) => h),
		confidence,
		bestSimilarity
	};
}
