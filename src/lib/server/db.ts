import Database, { type Database as DB } from 'better-sqlite3';
import * as sqliteVec from 'sqlite-vec';
import { resolve } from 'node:path';
import { mkdirSync } from 'node:fs';

/** Dimensione degli embedding del modello multilingue (paraphrase-multilingual-MiniLM-L12-v2). */
export const EMBED_DIM = 384;

/** Percorso del file DB. Sia gli script che il server girano dalla root del progetto. */
export const DB_PATH = process.env.DB_PATH ?? resolve(process.cwd(), 'data/judge.db');

let _db: DB | null = null;

/** Apre (una sola volta) la connessione a judge.db con sqlite-vec caricato. */
export function getDb(): DB {
	if (_db) return _db;
	mkdirSync(resolve(DB_PATH, '..'), { recursive: true });
	const db = new Database(DB_PATH);
	db.pragma('journal_mode = WAL');
	db.pragma('synchronous = NORMAL');
	sqliteVec.load(db);
	initSchema(db);
	_db = db;
	return db;
}

/** Crea le tabelle se non esistono. Idempotente. */
export function initSchema(db: DB): void {
	db.exec(`
		-- Carte di gioco uniche (Scryfall oracle_cards). Nessun embedding: lookup per nome.
		CREATE TABLE IF NOT EXISTS cards (
			oracle_id      TEXT PRIMARY KEY,
			name           TEXT NOT NULL,          -- nome inglese (oracle)
			printed_name_it TEXT,                  -- nome italiano stampato, se esiste
			mana_cost      TEXT,
			cmc            REAL,
			type_line      TEXT,
			oracle_text    TEXT,
			colors         TEXT,                   -- es. "W,U"
			color_identity TEXT,
			power          TEXT,
			toughness      TEXT,
			loyalty        TEXT,
			keywords       TEXT,                   -- CSV
			layout         TEXT,
			card_faces_json TEXT                   -- per carte fronte/retro / split
		);

		-- Indice full-text per il match fuzzy dei nomi (EN + IT).
		CREATE VIRTUAL TABLE IF NOT EXISTS cards_fts USING fts5(
			name, printed_name_it,
			oracle_id UNINDEXED,
			tokenize = 'unicode61'
		);

		-- Regole atomiche delle Comprehensive Rules + voci di glossario.
		CREATE TABLE IF NOT EXISTS rules (
			rowid       INTEGER PRIMARY KEY,
			rule_id     TEXT,                       -- es. "601.2a" oppure "glossary:Deathtouch"
			parent_id   TEXT,                       -- es. "601.2"
			kind        TEXT NOT NULL,              -- 'rule' | 'glossary'
			header_path TEXT,                       -- "601. Casting Spells › 601.2"
			text        TEXT NOT NULL,
			refs        TEXT                        -- numeri di regola citati nel testo, CSV
		);
		CREATE INDEX IF NOT EXISTS idx_rules_rule_id ON rules(rule_id);

		-- Lato BM25 della ricerca ibrida sulle regole.
		CREATE VIRTUAL TABLE IF NOT EXISTS rules_fts USING fts5(
			rule_id, header_path, text,
			content = 'rules', content_rowid = 'rowid',
			tokenize = 'porter unicode61'
		);

		-- Coppia chiave/valore per metadati (versione CR, data import, ...).
		CREATE TABLE IF NOT EXISTS meta (
			key   TEXT PRIMARY KEY,
			value TEXT
		);
	`);

	// Tabella vettoriale (sqlite-vec). Va creata a parte: la dimensione è interpolata.
	db.exec(`
		CREATE VIRTUAL TABLE IF NOT EXISTS vec_rules USING vec0(
			rule_rowid INTEGER PRIMARY KEY,
			embedding  FLOAT[${EMBED_DIM}]
		);
	`);
}

/** Converte un vettore di embedding in BLOB float32 little-endian per sqlite-vec. */
export function toVecBlob(vec: number[] | Float32Array): Buffer {
	return Buffer.from(new Float32Array(vec).buffer);
}

export function setMeta(db: DB, key: string, value: string): void {
	db.prepare('INSERT INTO meta(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value').run(
		key,
		value
	);
}

export function getMeta(db: DB, key: string): string | undefined {
	const row = db.prepare('SELECT value FROM meta WHERE key = ?').get(key) as { value: string } | undefined;
	return row?.value;
}
