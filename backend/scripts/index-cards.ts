/**
 * Costruisce l'indice vettoriale della Card Search (ricerca per effetto) in `vec_cards`.
 *
 * Uso: npm run data:card-vectors   (richiede che `npm run data:cards` sia già stato eseguito)
 *
 * Multi-vettore (vedi docs/adr/0001): per ogni carta indicizza un vettore "core"
 * (type_line + oracle_text) e un vettore per ogni ruling. Tutte le righe condividono lo
 * stesso oracle_id, così a query time si fa max-pool per carta. Embedding multilingue
 * locali, in batch. È un'operazione one-off (lunga: ~centinaia di migliaia di vettori).
 */
import { getDb, toVecBlob, setMeta, EMBED_DIM } from '../src/lib/server/db.ts';
import { embedBatch } from '../src/lib/server/embeddings.ts';

type CardRow = { oracle_id: string; type_line: string | null; oracle_text: string | null };
type RulingRow = { oracle_id: string; comment: string };

/** Testo del vettore "core": type_line dà il contesto (come l'header per le regole). */
function coreText(c: CardRow): string {
	return [c.type_line ?? '', c.oracle_text ?? ''].filter(Boolean).join('\n').trim();
}

async function main() {
	const db = getDb();
	const cards = db
		.prepare(`SELECT oracle_id, type_line, oracle_text FROM cards`)
		.all() as CardRow[];
	const rulings = db.prepare(`SELECT oracle_id, comment FROM rulings`).all() as RulingRow[];

	// Una lista piatta di (oracle_id, testo): core delle carte + ogni ruling.
	const items: Array<{ oracle_id: string; text: string }> = [];
	for (const c of cards) {
		const text = coreText(c);
		if (text) items.push({ oracle_id: c.oracle_id, text });
	}
	for (const r of rulings) {
		if (r.comment?.trim()) items.push({ oracle_id: r.oracle_id, text: r.comment });
	}

	console.log(
		`Indicizzo ${items.length} vettori (${cards.length} carte + ${rulings.length} rulings). Calcolo embedding…`
	);

	const insVec = db.prepare('INSERT INTO vec_cards (embedding, oracle_id) VALUES (?, ?)');
	db.exec('DELETE FROM vec_cards;');

	const BATCH = 64;
	for (let start = 0; start < items.length; start += BATCH) {
		const slice = items.slice(start, start + BATCH);
		const vecs = await embedBatch(slice.map((it) => it.text));
		const tx = db.transaction(() => {
			slice.forEach((it, j) => {
				if (vecs[j].length !== EMBED_DIM) throw new Error(`Dim embedding inattesa: ${vecs[j].length}`);
				insVec.run(toVecBlob(vecs[j]), it.oracle_id);
			});
		});
		tx();
		if (start % (BATCH * 20) === 0 || start + BATCH >= items.length) {
			process.stdout.write(`\r  embedded ${Math.min(start + BATCH, items.length)}/${items.length}`);
		}
	}
	process.stdout.write('\n');

	setMeta(db, 'card_vectors_indexed_at', new Date().toISOString());
	setMeta(db, 'card_vectors_count', String(items.length));
	console.log(`✓ Indicizzati ${items.length} vettori carta in vec_cards.`);
}

main().catch((err) => {
	console.error(err);
	process.exit(1);
});
