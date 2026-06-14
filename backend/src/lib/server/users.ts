import type { Database as DB } from 'better-sqlite3';
import { getDb } from './db';

/** Una superficie AI metered come AI Request. La Companion non è mai metered. */
export type Surface = 'judge' | 'search';

export interface User {
	id: string; // device token anonimo
	plan_id: string;
	ai_request_count: number;
	period_start: string;
	created_at: string;
}

export interface Plan {
	id: string;
	quota_limit: number; // -1 = illimitato
	reset_cadence: string; // 'monthly' | 'none'
}

/** Snapshot d'uso per il caller corrente (endpoint /api/me). */
export interface Usage {
	userId: string;
	plan: string;
	quotaLimit: number | null; // null = illimitato
	used: number;
	remaining: number | null; // null = illimitato
	resetCadence: string;
	periodStart: string;
}

/**
 * Ritorna lo User per un device token, creandone la riga al primo contatto
 * (identity middleware, ADR 0002). Nessuna enforcement qui.
 */
export function getOrCreateUser(token: string, db: DB = getDb()): User {
	const existing = db.prepare('SELECT * FROM users WHERE id = ?').get(token) as User | undefined;
	if (existing) return existing;

	const now = new Date().toISOString();
	db.prepare(
		`INSERT INTO users(id, plan_id, ai_request_count, period_start, created_at)
		 VALUES (?, 'free', 0, ?, ?)
		 ON CONFLICT(id) DO NOTHING`
	).run(token, now, now);

	return db.prepare('SELECT * FROM users WHERE id = ?').get(token) as User;
}

/**
 * Registra una AI Request andata a buon fine: incrementa il contatore dello User
 * e appende al ledger, in transazione. Una chiamata = una AI Request.
 */
export function incrementAiRequest(userId: string, surface: Surface, db: DB = getDb()): void {
	const tx = db.transaction(() => {
		db.prepare('UPDATE users SET ai_request_count = ai_request_count + 1 WHERE id = ?').run(userId);
		db.prepare('INSERT INTO ai_requests(user_id, surface, created_at) VALUES (?, ?, ?)').run(
			userId,
			surface,
			new Date().toISOString()
		);
	});
	tx();
}

export function getPlan(planId: string, db: DB = getDb()): Plan {
	return db.prepare('SELECT * FROM plans WHERE id = ?').get(planId) as Plan;
}

/** Uso corrente dello User, già risolto contro il suo Plan. */
export function getUsage(userId: string, db: DB = getDb()): Usage {
	const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId) as User;
	const plan = getPlan(user.plan_id, db);
	const unlimited = plan.quota_limit < 0;
	return {
		userId: user.id,
		plan: plan.id,
		quotaLimit: unlimited ? null : plan.quota_limit,
		used: user.ai_request_count,
		remaining: unlimited ? null : Math.max(0, plan.quota_limit - user.ai_request_count),
		resetCadence: plan.reset_cadence,
		periodStart: user.period_start
	};
}
