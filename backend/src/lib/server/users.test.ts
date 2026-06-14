import { describe, it, expect, beforeEach } from 'vitest';
import Database, { type Database as DB } from 'better-sqlite3';
import * as sqliteVec from 'sqlite-vec';
import { initSchema, DEFAULT_FREE_QUOTA } from './db.ts';
import { getOrCreateUser, incrementAiRequest, getUsage, getPlan } from './users.ts';

function makeDb(): DB {
	const db = new Database(':memory:');
	sqliteVec.load(db);
	initSchema(db);
	return db;
}

describe('identity + metering', () => {
	let db: DB;
	beforeEach(() => {
		db = makeDb();
	});

	it('semina i Plan free e paid', () => {
		expect(getPlan('free', db)).toMatchObject({ quota_limit: DEFAULT_FREE_QUOTA, reset_cadence: 'monthly' });
		expect(getPlan('paid', db)).toMatchObject({ quota_limit: -1 });
	});

	it('crea la riga users al primo contatto, sul piano free con conteggio 0', () => {
		const user = getOrCreateUser('device-A', db);
		expect(user.id).toBe('device-A');
		expect(user.plan_id).toBe('free');
		expect(user.ai_request_count).toBe(0);

		const count = db.prepare('SELECT COUNT(*) AS n FROM users').get() as { n: number };
		expect(count.n).toBe(1);
	});

	it('è idempotente: lo stesso token non crea un duplicato', () => {
		getOrCreateUser('device-A', db);
		getOrCreateUser('device-A', db);
		const count = db.prepare('SELECT COUNT(*) AS n FROM users').get() as { n: number };
		expect(count.n).toBe(1);
	});

	it('incrementa il contatore e appende al ledger per ogni AI Request', () => {
		getOrCreateUser('device-A', db);
		incrementAiRequest('device-A', 'judge', db);
		incrementAiRequest('device-A', 'search', db);

		expect(getUsage('device-A', db).used).toBe(2);
		const ledger = db.prepare('SELECT surface FROM ai_requests ORDER BY id').all() as { surface: string }[];
		expect(ledger.map((r) => r.surface)).toEqual(['judge', 'search']);
	});

	it('conta in modo indipendente per User', () => {
		getOrCreateUser('device-A', db);
		getOrCreateUser('device-B', db);
		incrementAiRequest('device-A', 'judge', db);
		incrementAiRequest('device-A', 'judge', db);
		incrementAiRequest('device-B', 'search', db);

		expect(getUsage('device-A', db).used).toBe(2);
		expect(getUsage('device-B', db).used).toBe(1);
	});

	it('riporta la Quota residua del Plan free e la decrementa con l’uso', () => {
		getOrCreateUser('device-A', db);
		const before = getUsage('device-A', db);
		expect(before.quotaLimit).toBe(DEFAULT_FREE_QUOTA);
		expect(before.remaining).toBe(DEFAULT_FREE_QUOTA);

		incrementAiRequest('device-A', 'judge', db);
		expect(getUsage('device-A', db).remaining).toBe(DEFAULT_FREE_QUOTA - 1);
	});
});
