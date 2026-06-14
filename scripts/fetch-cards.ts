/**
 * Scarica il bulk `oracle_cards` di Scryfall (una carta di gioco unica per oracle id)
 * e popola la tabella `cards` + l'indice full-text `cards_fts`. Subito dopo scarica anche
 * il bulk `rulings` (le note "Notes and Rules Information" delle pagine carta) e popola la
 * tabella `rulings`: carte e rulings restano così sempre allineati alla stessa release.
 *
 * Uso: npm run data:cards
 *
 * Nota: oracle_cards è in inglese. I nomi italiani NON sono in questo bulk, quindi
 * `printed_name_it` resta vuoto: la normalizzazione "Fulmine" -> "Lightning Bolt"
 * la fa il modello LLM in fase di pre-elaborazione (vedi src/lib/server/preprocess.ts).
 */
import { createWriteStream } from 'node:fs';
import { readFile, mkdir } from 'node:fs/promises';
import { Readable } from 'node:stream';
import { pipeline as streamPipeline } from 'node:stream/promises';
import { resolve } from 'node:path';
import { getDb, setMeta } from '../src/lib/server/db.ts';

const UA = 'manajudge/0.1 (https://github.com/BluHal; prototype)';
const BULK_INDEX = 'https://api.scryfall.com/bulk-data';
const OUT = resolve(process.cwd(), 'data/oracle_cards.json');
const OUT_RULINGS = resolve(process.cwd(), 'data/rulings.json');

type ScryfallFace = { name?: string; oracle_text?: string; mana_cost?: string; type_line?: string };
type ScryfallRuling = {
	oracle_id?: string;
	source?: string; // 'wotc' | 'scryfall'
	published_at?: string;
	comment?: string;
};
type ScryfallCard = {
	oracle_id?: string;
	name: string;
	mana_cost?: string;
	cmc?: number;
	type_line?: string;
	oracle_text?: string;
	colors?: string[];
	color_identity?: string[];
	power?: string;
	toughness?: string;
	loyalty?: string;
	keywords?: string[];
	layout?: string;
	card_faces?: ScryfallFace[];
	legalities?: Record<string, string>;
};

async function resolveDownloadUri(type: string): Promise<string> {
	const res = await fetch(BULK_INDEX, { headers: { 'User-Agent': UA, Accept: 'application/json' } });
	if (!res.ok) throw new Error(`Scryfall bulk index HTTP ${res.status}`);
	const body = (await res.json()) as { data: Array<{ type: string; download_uri: string }> };
	const entry = body.data.find((d) => d.type === type);
	if (!entry) throw new Error(`Bulk type "${type}" non trovato`);
	return entry.download_uri;
}

async function download(uri: string, out: string, label: string): Promise<void> {
	console.log(`↓ Scarico ${label} da ${uri}`);
	const res = await fetch(uri, { headers: { 'User-Agent': UA, Accept: 'application/json' } });
	if (!res.ok || !res.body) throw new Error(`Download ${label} HTTP ${res.status}`);
	await mkdir(resolve(out, '..'), { recursive: true });
	await streamPipeline(Readable.fromWeb(res.body as any), createWriteStream(out));
	console.log(`✓ Salvato in ${out}`);
}

/** Costruisce un oracle_text utilizzabile anche per le carte multi-faccia. */
function combinedOracleText(card: ScryfallCard): string {
	if (card.oracle_text && card.oracle_text.trim()) return card.oracle_text;
	if (card.card_faces?.length) {
		return card.card_faces
			.map((f) => `${f.name ?? ''}${f.type_line ? ` — ${f.type_line}` : ''}\n${f.oracle_text ?? ''}`.trim())
			.join('\n//\n');
	}
	return '';
}

function importCards(cards: ScryfallCard[]): number {
	const db = getDb();
	const insCard = db.prepare(`
		INSERT INTO cards (oracle_id, name, printed_name_it, mana_cost, cmc, type_line, oracle_text,
			colors, color_identity, power, toughness, loyalty, keywords, layout, card_faces_json, legalities)
		VALUES (@oracle_id, @name, NULL, @mana_cost, @cmc, @type_line, @oracle_text,
			@colors, @color_identity, @power, @toughness, @loyalty, @keywords, @layout, @card_faces_json, @legalities)
		ON CONFLICT(oracle_id) DO UPDATE SET
			name = excluded.name, mana_cost = excluded.mana_cost, cmc = excluded.cmc,
			type_line = excluded.type_line, oracle_text = excluded.oracle_text, colors = excluded.colors,
			color_identity = excluded.color_identity, power = excluded.power, toughness = excluded.toughness,
			loyalty = excluded.loyalty, keywords = excluded.keywords, layout = excluded.layout,
			card_faces_json = excluded.card_faces_json, legalities = excluded.legalities
	`);
	const insFts = db.prepare('INSERT INTO cards_fts (name, printed_name_it, oracle_id) VALUES (?, NULL, ?)');

	const run = db.transaction((rows: ScryfallCard[]) => {
		db.exec('DELETE FROM cards; DELETE FROM cards_fts;');
		let n = 0;
		for (const c of rows) {
			if (!c.oracle_id) continue; // scarta token/segnalini senza oracle id
			insCard.run({
				oracle_id: c.oracle_id,
				name: c.name,
				mana_cost: c.mana_cost ?? null,
				cmc: c.cmc ?? null,
				type_line: c.type_line ?? null,
				oracle_text: combinedOracleText(c),
				colors: c.colors?.join(',') ?? null,
				color_identity: c.color_identity?.join(',') ?? null,
				power: c.power ?? null,
				toughness: c.toughness ?? null,
				loyalty: c.loyalty ?? null,
				keywords: c.keywords?.join(',') ?? null,
				layout: c.layout ?? null,
				card_faces_json: c.card_faces ? JSON.stringify(c.card_faces) : null,
				legalities: c.legalities ? JSON.stringify(c.legalities) : null
			});
			insFts.run(c.name, c.oracle_id);
			n++;
		}
		setMeta(db, 'cards_imported_at', new Date().toISOString());
		setMeta(db, 'cards_count', String(n));
		return n;
	});

	return run(cards);
}

function importRulings(rulings: ScryfallRuling[]): number {
	const db = getDb();
	const ins = db.prepare(
		'INSERT INTO rulings (oracle_id, source, published_at, comment) VALUES (@oracle_id, @source, @published_at, @comment)'
	);

	const run = db.transaction((rows: ScryfallRuling[]) => {
		db.exec('DELETE FROM rulings;');
		let n = 0;
		for (const r of rows) {
			if (!r.oracle_id || !r.comment) continue; // scarta voci senza carta o senza testo
			ins.run({
				oracle_id: r.oracle_id,
				source: r.source ?? null,
				published_at: r.published_at ?? null,
				comment: r.comment
			});
			n++;
		}
		setMeta(db, 'rulings_imported_at', new Date().toISOString());
		setMeta(db, 'rulings_count', String(n));
		return n;
	});

	return run(rulings);
}

async function main() {
	const cardsUri = await resolveDownloadUri('oracle_cards');
	await download(cardsUri, OUT, 'oracle_cards');
	console.log('Parsing JSON…');
	const cards = JSON.parse(await readFile(OUT, 'utf8')) as ScryfallCard[];
	console.log(`Trovate ${cards.length} carte nel bulk. Importo…`);
	const n = importCards(cards);
	console.log(`✓ Importate ${n} carte in cards/cards_fts.`);

	const rulingsUri = await resolveDownloadUri('rulings');
	await download(rulingsUri, OUT_RULINGS, 'rulings');
	console.log('Parsing JSON…');
	const rulings = JSON.parse(await readFile(OUT_RULINGS, 'utf8')) as ScryfallRuling[];
	console.log(`Trovati ${rulings.length} rulings nel bulk. Importo…`);
	const m = importRulings(rulings);
	console.log(`✓ Importati ${m} rulings in rulings.`);
}

main().catch((err) => {
	console.error(err);
	process.exit(1);
});
