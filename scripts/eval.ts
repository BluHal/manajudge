/**
 * Valutazione del giudice su un set di domande con regole CR attese.
 *
 *   npm run eval
 *
 * Tre livelli:
 *  1) Automatico — "retrieval hit rate": almeno una regola attesa è tra quelle recuperate?
 *  2) AI-judge   — (se GEMINI_API_KEY è presente) un LLM valuta la correttezza della risposta.
 *  3) Umano      — il report stampa le risposte così puoi rivederle a campione.
 */
import 'dotenv/config';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { retrieveRules } from '../src/lib/server/rules.ts';
import { runJudge } from '../src/lib/server/judge.ts';
import { gemini } from '../src/lib/server/llm/gemini.ts';

type Case = { q: string; expected_rules: string[]; cards: string[] };

const SET = resolve(process.cwd(), 'data/eval/eval-set.json');

function hitExpected(expected: string[], hitIds: string[]): string[] {
	return expected.filter((e) => hitIds.some((id) => id === e || id.startsWith(e)));
}

async function aiGrade(question: string, answer: string, expected: string[]): Promise<{ voto: number; motivazione: string }> {
	const system = `Sei un revisore esperto di regole di Magic. Valuta la risposta di un giudice AI.
Restituisci SOLO JSON {"voto": 0|1|2, "motivazione": "..."} dove:
2 = corretta e con citazioni di regole pertinenti; 1 = parzialmente corretta o incompleta; 0 = errata o inventata.`;
	const prompt = `Domanda: ${question}\nAree di regola pertinenti attese: ${expected.join(', ')}\n\nRisposta del giudice:\n${answer}`;
	try {
		return await gemini.completeJSON({ system, prompt });
	} catch (e) {
		return { voto: -1, motivazione: e instanceof Error ? e.message : 'errore' };
	}
}

async function collectAnswer(it: AsyncIterable<string>): Promise<string> {
	let s = '';
	for await (const t of it) s += t;
	return s;
}

async function main() {
	const cases = JSON.parse(await readFile(SET, 'utf8')) as Case[];
	const useAI = !!process.env.GEMINI_API_KEY;
	console.log(`Eval su ${cases.length} domande. AI-judge: ${useAI ? 'attivo' : 'disattivo (manca GEMINI_API_KEY)'}\n`);

	let hits = 0;
	let votes = 0;
	let voteSum = 0;

	// Throttle tra domande: il free tier consente pochi req/minuto (oltre al retry/backoff).
	const delayMs = useAI ? Number(process.env.EVAL_DELAY_MS ?? 12000) : 0;
	const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

	for (const [i, c] of cases.entries()) {
		if (i > 0 && delayMs) await sleep(delayMs);
		// Con la chiave si misura la pipeline REALE (retrieval potenziato dai termini inglesi);
		// senza chiave si usa il retrieval grezzo sulla domanda (baseline automatico).
		const res = useAI ? await runJudge(gemini, [], c.q) : null;
		const r = res ? null : await retrieveRules(c.q, 8);
		const hitIds = res ? res.sources.map((s) => s.rule_id) : r!.hits.map((h) => h.rule_id);
		const confidence = res ? res.confidence : r!.confidence;
		const found = hitExpected(c.expected_rules, hitIds);
		const ok = found.length > 0;
		if (ok) hits++;

		console.log(`${i + 1}. [${ok ? 'HIT ' : 'MISS'}] (${confidence}) ${c.q}`);
		console.log(`     attese: ${c.expected_rules.join(', ')} | trovate: ${found.join(', ') || '—'}`);

		if (res) {
			const answer = await collectAnswer(res.answer);
			const grade = await aiGrade(c.q, answer, c.expected_rules);
			if (grade.voto >= 0) {
				votes++;
				voteSum += grade.voto;
			}
			console.log(`     AI-judge: ${grade.voto}/2 — ${grade.motivazione}`);
		}
	}

	console.log(`\n=== Risultati ===`);
	console.log(`Retrieval hit-rate: ${hits}/${cases.length} (${((hits / cases.length) * 100).toFixed(0)}%)`);
	if (votes > 0) console.log(`AI-judge medio: ${(voteSum / votes).toFixed(2)}/2 su ${votes} risposte`);
}

main().catch((err) => {
	console.error(err);
	process.exit(1);
});
