/**
 * Scarica e indicizza le Comprehensive Rules (CR) di Magic.
 *
 * Uso:
 *   npm run data:rules                       # prova a scoprire il .txt dalla pagina ufficiale
 *   npm run data:rules -- ./MagicCompRules.txt   # usa un file locale già scaricato
 *   CR_TXT_URL=https://.../rules.txt npm run data:rules
 *
 * Produce: chunk atomici (una sotto-regola per record) con header gerarchico, voci di
 * glossario, espansione dei rimandi, ed embedding multilingue locali in vec_rules.
 */
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { getDb, toVecBlob, setMeta, EMBED_DIM } from '../src/lib/server/db.ts';
import { embedBatch } from '../src/lib/server/embeddings.ts';

const UA = 'manajudge/0.1 (prototype)';
const RULES_PAGE = 'https://magic.wizards.com/en/rules';
const CACHE = resolve(process.cwd(), 'data/comprehensive-rules.txt');

const RULE_RE = /^(\d{3}\.\d+[a-z]?)\.?\s+(.*)$/; // 601.2  oppure  601.2a
const HEADER_RE = /^(\d{1,3})\.\s+(\D.*)$/; // "1. Game Concepts" / "601. Casting Spells"
const REF_RE = /\b(\d{3}\.\d+[a-z]?|\d{3})\b/g;

type Entry = {
	rule_id: string;
	parent_id: string | null;
	kind: 'rule' | 'glossary';
	header_path: string;
	text: string;
	refs: string[];
};

function parentId(id: string): string | null {
	if (/[a-z]$/.test(id)) return id.slice(0, -1); // 601.2a -> 601.2
	const i = id.lastIndexOf('.');
	return i > 0 ? id.slice(0, i) : null; // 601.2 -> 601
}

function extractRefs(text: string, selfId: string): string[] {
	const found = new Set<string>();
	for (const m of text.matchAll(REF_RE)) {
		if (m[1] !== selfId) found.add(m[1]);
	}
	return [...found];
}

async function resolveSource(): Promise<string> {
	// 1) argomento CLI o env: file locale o URL.
	const arg = process.argv[2] ?? process.env.CR_TXT_FILE;
	if (arg && existsSync(arg)) {
		console.log(`Uso file locale: ${arg}`);
		return readFile(arg, 'utf8');
	}
	const urlArg = (arg && arg.startsWith('http') ? arg : undefined) ?? process.env.CR_TXT_URL;
	if (urlArg) return downloadTxt(urlArg);

	// 2) cache locale già scaricata.
	if (existsSync(CACHE)) {
		console.log(`Uso cache: ${CACHE}`);
		return readFile(CACHE, 'utf8');
	}

	// 3) auto-discovery dal sito ufficiale.
	console.log(`Cerco il link .txt su ${RULES_PAGE} …`);
	const res = await fetch(RULES_PAGE, { headers: { 'User-Agent': UA } });
	if (res.ok) {
		const html = await res.text();
		const m = html.match(/https?:\/\/[^\s"']+?\.txt/i);
		if (m) return downloadTxt(m[0]);
	}
	throw new Error(
		'Impossibile trovare automaticamente le Comprehensive Rules.\n' +
			'Scaricale da https://magic.wizards.com/en/rules (link "TXT") e lancia:\n' +
			'  npm run data:rules -- /percorso/al/file.txt'
	);
}

async function downloadTxt(url: string): Promise<string> {
	console.log(`↓ Scarico CR da ${url}`);
	const res = await fetch(url, { headers: { 'User-Agent': UA } });
	if (!res.ok) throw new Error(`Download CR HTTP ${res.status}`);
	const txt = await res.text();
	await mkdir(resolve(CACHE, '..'), { recursive: true });
	await writeFile(CACHE, txt, 'utf8');
	return txt;
}

function parse(raw: string): Entry[] {
	const lines = raw.replace(/\r\n/g, '\n').split('\n');

	// Confini: ultima occorrenza di "Glossary" e "Credits".
	let glossaryStart = -1;
	let creditsStart = -1;
	lines.forEach((l, i) => {
		const t = l.trim();
		if (t === 'Glossary') glossaryStart = i;
		if (t === 'Credits' && glossaryStart >= 0 && i > glossaryStart) creditsStart = i;
	});

	// Prima sotto-regola reale: salta indice/Contents.
	const firstRuleIdx = lines.findIndex((l) => RULE_RE.test(l.trim()));
	if (firstRuleIdx < 0) throw new Error('Nessuna regola riconosciuta: formato CR inatteso?');

	const entries: Entry[] = [];
	let chapter = '';
	let section = '';

	// Contesto iniziale: header più vicino sopra la prima regola.
	for (let i = firstRuleIdx; i >= 0; i--) {
		const m = lines[i].trim().match(HEADER_RE);
		if (m) {
			if (m[1].length === 3 && !section) section = `${m[1]}. ${m[2].trim()}`;
			else if (m[1].length <= 2 && !chapter) chapter = `${m[1]}. ${m[2].trim()}`;
			if (section && chapter) break;
		}
	}

	const headerPath = () => [chapter, section].filter(Boolean).join(' › ');
	const rulesEnd = glossaryStart > 0 ? glossaryStart : lines.length;
	let current: Entry | null = null;
	const push = () => {
		if (current) {
			current.text = current.text.replace(/\n{2,}/g, '\n').trim();
			current.refs = extractRefs(current.text, current.rule_id);
			if (current.text) entries.push(current);
			current = null;
		}
	};

	for (let i = firstRuleIdx; i < rulesEnd; i++) {
		const line = lines[i];
		const trimmed = line.trim();
		const rule = trimmed.match(RULE_RE);
		const header = trimmed.match(HEADER_RE);

		if (rule) {
			push();
			current = {
				rule_id: rule[1],
				parent_id: parentId(rule[1]),
				kind: 'rule',
				header_path: headerPath(),
				text: rule[2] ?? '',
				refs: []
			};
		} else if (header) {
			push();
			if (header[1].length === 3) section = `${header[1]}. ${header[2].trim()}`;
			else if (header[1].length <= 2) {
				chapter = `${header[1]}. ${header[2].trim()}`;
				section = '';
			}
		} else if (current) {
			current.text += '\n' + line;
		}
	}
	push();

	// Glossario: ogni blocco (separato da riga vuota) = termine + definizione.
	if (glossaryStart > 0) {
		const end = creditsStart > glossaryStart ? creditsStart : lines.length;
		const block: string[] = [];
		const flush = () => {
			const nonEmpty = block.filter((l) => l.trim());
			block.length = 0;
			if (nonEmpty.length < 2) return; // serve termine + definizione
			const term = nonEmpty[0].trim();
			const def = nonEmpty.slice(1).join(' ').replace(/\s+/g, ' ').trim();
			entries.push({
				rule_id: `glossary:${term}`,
				parent_id: null,
				kind: 'glossary',
				header_path: 'Glossary',
				text: `${term}: ${def}`,
				refs: extractRefs(def, '')
			});
		};
		for (let i = glossaryStart + 1; i < end; i++) {
			if (lines[i].trim() === '') flush();
			else block.push(lines[i]);
		}
		flush();
	}

	return entries;
}

/** Testo dato in pasto all'embedding: include header gerarchico per contestualizzare. */
function embedText(e: Entry): string {
	return e.kind === 'rule' ? `${e.header_path}\n${e.rule_id} ${e.text}` : e.text;
}

async function main() {
	const raw = await resolveSource();
	console.log('Parsing delle regole…');
	const entries = parse(raw);
	const rules = entries.filter((e) => e.kind === 'rule').length;
	const gloss = entries.length - rules;
	console.log(`Trovati ${entries.length} chunk (${rules} regole, ${gloss} glossario). Calcolo embedding…`);

	const db = getDb();
	const insRule = db.prepare(
		`INSERT INTO rules (rowid, rule_id, parent_id, kind, header_path, text, refs)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`
	);
	const insVec = db.prepare('INSERT INTO vec_rules (rule_rowid, embedding) VALUES (?, ?)');

	// Reset + reimport in transazione, embedding a batch.
	db.exec('DELETE FROM rules; DELETE FROM vec_rules;');
	const BATCH = 64;
	for (let start = 0; start < entries.length; start += BATCH) {
		const slice = entries.slice(start, start + BATCH);
		const vecs = await embedBatch(slice.map(embedText));
		const tx = db.transaction(() => {
			slice.forEach((e, j) => {
				const rowid = start + j + 1;
				insRule.run(rowid, e.rule_id, e.parent_id, e.kind, e.header_path, e.text, e.refs.join(','));
				if (vecs[j].length !== EMBED_DIM) throw new Error(`Dim embedding inattesa: ${vecs[j].length}`);
				insVec.run(BigInt(rowid), toVecBlob(vecs[j]));
			});
		});
		tx();
		process.stdout.write(`\r  embedded ${Math.min(start + BATCH, entries.length)}/${entries.length}`);
	}
	process.stdout.write('\n');

	// Ricostruisce l'indice full-text (external content) dalla tabella rules.
	db.exec("INSERT INTO rules_fts(rules_fts) VALUES('rebuild')");
	setMeta(db, 'rules_imported_at', new Date().toISOString());
	setMeta(db, 'rules_count', String(entries.length));
	console.log(`✓ Indicizzati ${entries.length} chunk (rules + rules_fts + vec_rules).`);
}

main().catch((err) => {
	console.error(err);
	process.exit(1);
});
