import type { ChatMessage, LLMProvider } from './llm/provider.ts';
import { preprocess } from './preprocess.ts';
import { retrieveRules, type RuleHit } from './rules.ts';
import { lookupCards, getRulings, type Card } from './cards.ts';

export type Source = { rule_id: string; header_path: string; text: string };
export type JudgeResult = {
	rewritten: string;
	confidence: 'alta' | 'media' | 'bassa';
	cards: Card[];
	sources: Source[];
	answer: AsyncIterable<string>;
};

const SYSTEM = `Sei un giudice di torneo certificato di Magic: The Gathering. Rispondi in ITALIANO con precisione e autorità.

REGOLE DI CONDOTTA (vincolanti):
1. Basa la risposta SOLO sulle Comprehensive Rules, sui testi delle carte e sui rulings ufficiali forniti nel contesto. Non inventare regole, testi di carte o rulings. I rulings ufficiali (le note "Notes and Rules Information" di Scryfall, datate) sono chiarimenti autorevoli su casi specifici: quando un ruling copre il caso, usalo e dichiaralo.
2. Cita sempre i numeri di regola pertinenti (es. "509.1a", "702.2b") tra parentesi. I numeri e i nomi delle regole restano in inglese. Quando ti basi su un ruling, citalo indicando la data, es. "(ruling ufficiale, 2021-03-19)".
3. Se le regole/carte fornite NON bastano a rispondere con certezza, dillo apertamente: "Non trovo una regola che copra con certezza questo caso — conviene consultare un giudice umano." Non riempire i vuoti con supposizioni.
4. Distingui chiaramente ciò che è stabilito dalle regole citate da ciò che è una tua inferenza.
5. Sii conciso e concreto: prima il verdetto, poi la spiegazione passo-passo (stack, priorità, ecc.) quando serve.`;

function rulesBlock(rules: RuleHit[]): string {
	if (rules.length === 0) return '(nessuna regola recuperata)';
	return rules
		.map((r) => {
			const head = r.kind === 'glossary' ? 'Glossary' : `${r.rule_id} — ${r.header_path}`;
			// Tronca le regole-elenco molto lunghe per contenere i token in input (free tier TPM).
			const text = r.text.length > 900 ? r.text.slice(0, 900) + ' […]' : r.text;
			return `[${head}]\n${text}`;
		})
		.join('\n\n');
}

// Tetto totale di rulings iniettati nel prompt (su tutte le carte citate): valvola di
// sicurezza sul budget token del free-tier. Soglia alta: nei casi normali non scatta.
const MAX_RULINGS_TOTAL = 12;

function cardsBlock(cards: Card[]): string {
	if (cards.length === 0) return '(nessuna carta rilevata)';
	let rulingBudget = MAX_RULINGS_TOTAL;
	return cards
		.map((c) => {
			let block =
				`${c.name} ${c.mana_cost ?? ''}\n${c.type_line ?? ''}\n${c.oracle_text ?? ''}` +
				(c.power ? `\n${c.power}/${c.toughness}` : '') +
				(c.loyalty ? `\nLealtà: ${c.loyalty}` : '');
			const rulings = rulingBudget > 0 ? getRulings(c.oracle_id).slice(0, rulingBudget) : [];
			if (rulings.length) {
				rulingBudget -= rulings.length;
				const lines = rulings.map((r) => `- (${r.published_at ?? 's.d.'}) ${r.comment}`).join('\n');
				block += `\nRulings ufficiali:\n${lines}`;
			}
			return block;
		})
		.join('\n\n');
}

/** Pipeline completa: pre-elaborazione -> retrieval ibrido -> carte -> risposta in streaming. */
export async function runJudge(
	llm: LLMProvider,
	history: ChatMessage[],
	message: string
): Promise<JudgeResult> {
	const { domanda_riscritta, carte_citate, termini_inglesi } = await preprocess(llm, history, message);
	const cards = lookupCards(carte_citate);
	// La query di retrieval unisce la domanda italiana ai termini di regola inglesi:
	// così il lato vettoriale e il lato BM25 (inglese) agganciano le regole pertinenti.
	const retrievalQuery = [domanda_riscritta, ...termini_inglesi].join(' ');
	const retrieval = await retrieveRules(retrievalQuery, 6);

	const lowConfidenceNote =
		retrieval.confidence === 'bassa'
			? '\n\nNOTA: il recupero delle regole è risultato di BASSA CONFIDENZA; se le regole sotto non coprono il caso, dichiaralo esplicitamente.'
			: '';

	const userTurn =
		`Domanda: ${domanda_riscritta}\n\n` +
		`=== COMPREHENSIVE RULES (estratti rilevanti) ===\n${rulesBlock(retrieval.hits)}\n\n` +
		`=== CARTE CITATE (testo oracle ufficiale) ===\n${cardsBlock(cards)}` +
		lowConfidenceNote;

	const messages: ChatMessage[] = [
		...history.slice(-6),
		{ role: 'user', text: userTurn }
	];

	return {
		rewritten: domanda_riscritta,
		confidence: retrieval.confidence,
		cards,
		sources: retrieval.hits.map((r) => ({
			rule_id: r.rule_id,
			header_path: r.header_path,
			text: r.text
		})),
		answer: llm.stream({ system: SYSTEM, messages })
	};
}
