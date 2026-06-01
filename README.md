---
title: Manajudge
emoji: ⚖️
colorFrom: purple
colorTo: blue
sdk: docker
app_port: 7860
pinned: false
---

# ⚖️ manajudge

AI tournament judge for **Magic: The Gathering**. A text chatbot that answers questions
about rules and card interactions by citing the official **Comprehensive Rules** and the real
oracle text of the cards.

Everything runs locally at zero cost, except the calls to the LLM (Google Gemini free tier).

> The judge currently replies in **Italian**, but the retrieval pipeline is **multilingual**:
> thanks to the multilingual embedding model you can ask in any language and the rules are still
> matched in English.

## How it works

- **Rules** → **hybrid** search (vector `sqlite-vec` + full-text BM25 `FTS5`) over the
  Comprehensive Rules, split into atomic chunks with hierarchical context + cross-reference expansion.
- **Embeddings** → a local **multilingual** model (`transformers.js`): you can ask in any
  language while the rules stay in **English**.
- **Cards** → the LLM extracts the card names mentioned (in any language) and normalizes them to
  the English name, then the DB fetches the exact oracle text (Scryfall bulk, ~37k cards).
- **Answer** → Gemini answers, constrained to use only the retrieved sources, to cite rule
  numbers and to declare uncertainty. The **sources** are always shown.

Stack: SvelteKit + SQLite (`better-sqlite3` + `sqlite-vec`). The LLM provider sits behind an
interface (`src/lib/server/llm/`), so Gemini can be swapped for Groq/Ollama.

## Setup

1. Dependencies:
   ```bash
   npm install
   ```
2. Free API key from Google AI Studio → https://aistudio.google.com/apikey
   ```bash
   cp .env.example .env
   # then set GEMINI_API_KEY=... in .env
   ```
   > **Free tier limits:** on top of the daily cap there is a limit of **a few requests per
   > minute** (~5–10 RPM on `gemini-2.5-flash`). The app makes 2 calls per question, so
   > interactive use is fine; 429s are handled anyway with automatic **retry/backoff**. The `eval`
   > is bursty: it has a throttle configurable via `EVAL_DELAY_MS` (default 12s between questions).
3. Build the database (only once; rerun when a new set is released):
   ```bash
   npm run data:cards    # download cards from Scryfall (~37k) -> data/judge.db
   npm run data:rules    # download and index the Comprehensive Rules (local embeddings)
   ```
   > If `data:rules` cannot find the file automatically, download the `.txt` from
   > https://magic.wizards.com/en/rules and run:
   > `npm run data:rules -- /path/to/file.txt`

4. Start:
   ```bash
   npm run dev
   ```

## Example questions

In [`docs/example-questions.md`](docs/example-questions.md) you'll find a collection of real
questions by category (basic rules, the stack, combat, card interactions, advanced cases,
conversational follow-ups, and ambiguous questions to test the judge's honesty).

## Evaluation

A set of ~24 judge questions with expected rules in `data/eval/eval-set.json`.

```bash
npm run eval
```

- **Retrieval hit-rate** (always): is the expected rule among the retrieved ones?
- **AI-judge** (if `GEMINI_API_KEY` is set): an LLM rates the correctness of the answer.

Use the score as a baseline before changing prompts, chunking, or retrieval.

## Structure

```
scripts/        fetch-cards.ts · fetch-rules.ts · eval.ts
src/lib/server/ db.ts · embeddings.ts · rules.ts · cards.ts · preprocess.ts · judge.ts · llm/
src/routes/     +page.svelte (chat UI) · api/chat/+server.ts (streaming endpoint)
data/           (gitignored) downloaded sources + judge.db · data/eval/ versioned
```

## Out of scope (v1)

Persistent conversation history across sessions, card recognition from photos, other TCGs,
authentication. The provider abstraction and the DB schema leave room to add them.
