/**
 * Valutazione della Card Search (ricerca per effetto) su un set di query con carte attese.
 *
 *   npm run eval:cards
 *
 * Misura PURA del retriever (nessuna chiamata LLM): embedda la query e applica i filtri
 * dati nel set, così il risultato dipende solo dall'indice e dal modello di embedding.
 * È il test da ri-lanciare dopo aver cambiato modello (es. MiniLM -> multilingual-e5-small)
 * per decidere se lo switch migliora il recall. Richiede vec_cards costruito
 * (`npm run data:card-vectors`).
 *
 * Metriche:
 *  - hit-rate     : query con almeno una carta attesa nei top-N.
 *  - recall medio : frazione media di carte attese trovate nei top-N.
 *  - MRR          : reciproco del rank della prima carta attesa (qualità del posizionamento).
 */
import 'dotenv/config';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { getDb } from '../src/lib/server/db.ts';
import { embed } from '../src/lib/server/embeddings.ts';
import { searchCards, type CardFilters } from '../src/lib/server/cardSearch.ts';

type Case = { q: string; filters?: CardFilters; expected_cards: string[] };

const SET = resolve(process.cwd(), 'data/eval/card-search-eval-set.json');
const TOP_N = Number(process.env.EVAL_TOP_N ?? 20);

const norm = (s: string) => s.trim().toLowerCase();

async function main() {
	const cases = JSON.parse(await readFile(SET, 'utf8')) as Case[];
	// vec_cards deve esistere ed essere popolato.
	const n = getDb().prepare('SELECT count(*) c FROM vec_cards').get() as { c: number };
	if (n.c === 0) {
		console.error('vec_cards è vuoto: esegui prima `npm run data:card-vectors`.');
		process.exit(1);
	}
	console.log(`Eval Card Search su ${cases.length} query (top-${TOP_N}, ${n.c} vettori indicizzati)\n`);

	let hits = 0;
	let recallSum = 0;
	let rrSum = 0;

	for (const [i, c] of cases.entries()) {
		const vec = await embed(c.q);
		const results = searchCards(getDb(), vec, c.filters ?? {}, TOP_N);
		const names = results.map((r) => norm(r.name));

		const found = c.expected_cards.filter((e) => names.includes(norm(e)));
		const firstRank = Math.min(
			...c.expected_cards.map((e) => {
				const idx = names.indexOf(norm(e));
				return idx < 0 ? Infinity : idx + 1;
			})
		);
		const recall = found.length / c.expected_cards.length;
		const ok = found.length > 0;
		if (ok) hits++;
		recallSum += recall;
		rrSum += firstRank === Infinity ? 0 : 1 / firstRank;

		const filterStr = c.filters && Object.keys(c.filters).length ? ` ${JSON.stringify(c.filters)}` : '';
		console.log(`${i + 1}. [${ok ? 'HIT ' : 'MISS'}] ${c.q}${filterStr}`);
		console.log(
			`     attese: ${c.expected_cards.join(', ')}\n` +
				`     trovate: ${found.join(', ') || '—'}` +
				(firstRank !== Infinity ? ` (prima al rank ${firstRank})` : '') +
				` | recall ${(recall * 100).toFixed(0)}%`
		);
	}

	console.log(`\n=== Risultati (top-${TOP_N}) ===`);
	console.log(`Hit-rate:    ${hits}/${cases.length} (${((hits / cases.length) * 100).toFixed(0)}%)`);
	console.log(`Recall medio: ${((recallSum / cases.length) * 100).toFixed(0)}%`);
	console.log(`MRR:          ${(rrSum / cases.length).toFixed(3)}`);
}

main().catch((err) => {
	console.error(err);
	process.exit(1);
});
