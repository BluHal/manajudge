import { describe, it, expect, beforeEach } from 'vitest';
import Database, { type Database as DB } from 'better-sqlite3';
import * as sqliteVec from 'sqlite-vec';
import { initSchema, toVecBlob, EMBED_DIM } from './db.ts';
import { searchCards } from './cardSearch.ts';

/** Vettore base e_i (1 nella posizione i, 0 altrove): già normalizzato (unit). */
function basis(i: number): number[] {
	const v = new Array(EMBED_DIM).fill(0);
	v[i] = 1;
	return v;
}

function makeDb(): DB {
	const db = new Database(':memory:');
	sqliteVec.load(db);
	initSchema(db);
	return db;
}

type SeedCard = {
	oracle_id: string;
	name: string;
	type_line?: string;
	oracle_text?: string;
	core: number[]; // embedding del core
	rulings?: number[][]; // embedding di eventuali ruling
	legalities?: Record<string, string>;
};

function seedCard(db: DB, c: SeedCard): void {
	db.prepare(
		`INSERT INTO cards (oracle_id, name, type_line, oracle_text, legalities) VALUES (?, ?, ?, ?, ?)`
	).run(
		c.oracle_id,
		c.name,
		c.type_line ?? null,
		c.oracle_text ?? null,
		c.legalities ? JSON.stringify(c.legalities) : null
	);
	const insVec = db.prepare(`INSERT INTO vec_cards (embedding, oracle_id) VALUES (?, ?)`);
	insVec.run(toVecBlob(c.core), c.oracle_id);
	for (const r of c.rulings ?? []) insVec.run(toVecBlob(r), c.oracle_id);
}

describe('searchCards', () => {
	let db: DB;
	beforeEach(() => {
		db = makeDb();
	});

	it('restituisce le carte rankate per vicinanza semantica al vettore query', () => {
		seedCard(db, { oracle_id: 'A', name: 'Alpha', core: basis(0) });
		seedCard(db, { oracle_id: 'B', name: 'Beta', core: basis(1) });

		const results = searchCards(db, basis(0), {});

		expect(results.map((r) => r.oracle_id)).toEqual(['A', 'B']);
	});

	it('fa emergere una carta quando un suo ruling matcha, anche se il core è lontano', () => {
		seedCard(db, { oracle_id: 'A', name: 'Alpha', core: basis(2) });
		// Il core di B è lontano dalla query, ma un suo ruling le sta sopra.
		seedCard(db, { oracle_id: 'B', name: 'Beta', core: basis(5), rulings: [basis(0)] });

		const results = searchCards(db, basis(0), {});

		expect(results[0].oracle_id).toBe('B');
		expect(results.map((r) => r.oracle_id)).toEqual(['B', 'A']);
	});

	it('restituisce ogni carta una sola volta, col punteggio del vettore migliore', () => {
		// A ha due vettori: il core lontano e un ruling esattamente sulla query.
		seedCard(db, { oracle_id: 'A', name: 'Alpha', core: basis(1), rulings: [basis(0)] });
		seedCard(db, { oracle_id: 'B', name: 'Beta', core: basis(3) });

		const results = searchCards(db, basis(0), {});

		expect(results.filter((r) => r.oracle_id === 'A')).toHaveLength(1);
		const a = results.find((r) => r.oracle_id === 'A')!;
		expect(a.similarity).toBeCloseTo(1, 5); // il ruling, non il core
	});

	it('esclude le carte che non passano il filtro di tipo (filtra-poi-ranka)', () => {
		// La Terra è la più vicina, ma il filtro la toglie: resta Alpha, più in basso.
		seedCard(db, { oracle_id: 'L', name: 'Forest', type_line: 'Basic Land — Forest', core: basis(0) });
		seedCard(db, { oracle_id: 'A', name: 'Alpha', type_line: 'Instant', core: basis(1) });

		const results = searchCards(db, basis(0), { excludeTypes: ['Land'] });

		expect(results.map((r) => r.oracle_id)).toEqual(['A']);
	});

	it('esclude le carte non legali nel formato richiesto', () => {
		seedCard(db, {
			oracle_id: 'M', name: 'ModernCard', type_line: 'Instant',
			legalities: { modern: 'legal' }, core: basis(0)
		});
		seedCard(db, {
			oracle_id: 'S', name: 'OldCard', type_line: 'Instant',
			legalities: { modern: 'not_legal' }, core: basis(1)
		});

		const results = searchCards(db, basis(0), { legalIn: 'modern' });

		expect(results.map((r) => r.oracle_id)).toEqual(['M']);
	});
});
