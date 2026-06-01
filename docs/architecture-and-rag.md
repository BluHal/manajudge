# Architecture & RAG — manajudge

This document describes the **technology stack** of manajudge and **how the RAG**
(Retrieval-Augmented Generation) was implemented to let the chatbot answer as a Magic judge,
citing the official Comprehensive Rules and the real text of the cards.

---

## 1. Technology stack

| Layer | Technology | Role |
|---|---|---|
| **Web framework** | SvelteKit 2 + Svelte 5 | chat UI + server endpoint (`+server.ts`) |
| **Runtime / build** | Vite 8, TypeScript, `tsx` for scripts | dev server, bundling, running the data-ingestion scripts |
| **Database** | SQLite via `better-sqlite3` (synchronous) | single store: cards, rules, indexes |
| **Vector search** | `sqlite-vec` (`vec0` extension) | KNN over the rule embeddings |
| **Full-text search** | FTS5 (built-in SQLite, BM25) | lexical match on rules and card names |
| **Embeddings** | `@huggingface/transformers` (transformers.js) | **local** multilingual model, zero cost |
| **LLM** | Google Gemini (`@google/genai`, free tier) | preprocessing + the judge's answer |

**Design principle:** everything runs **locally at zero cost**, except the calls to the LLM
(Gemini free tier). Embeddings, indexes and search require no external services or paid APIs.

### Data model (SQLite)

The schema lives in [`src/lib/server/db.ts`](../src/lib/server/db.ts). Five "areas":

- **`cards`** — unique (oracle) cards from Scryfall, ~37k records. No embeddings: they are looked
  up by name via exact lookup + FTS.
- **`cards_fts`** — FTS5 index over the names (English + printed Italian) for fuzzy matching.
- **`rules`** — Comprehensive Rules split into **atomic chunks** (one sub-rule per record) +
  glossary entries. Each record has `rule_id`, `parent_id`, `header_path` (hierarchical context)
  and `refs` (rule numbers cited in the text).
- **`rules_fts`** — *external-content* FTS5 index over `rules` (the BM25 side of the hybrid
  search), with the `porter unicode61` tokenizer (English stemming).
- **`vec_rules`** — `vec0` virtual table with the `FLOAT[384]` rule embeddings (the vector side of
  the hybrid search).

The LLM provider abstraction is in [`src/lib/server/llm/provider.ts`](../src/lib/server/llm/provider.ts):
a simple interface with `completeJSON()` and `stream()`, so Gemini can be swapped for Groq/Ollama
without touching the judge logic.

---

## 2. The RAG, step by step

manajudge's RAG has two phases: **offline indexing** (DB build, one-off) and **retrieval +
generation at runtime** (on every question).

### 2.1 Offline indexing (`npm run data:rules`)

Script: [`scripts/fetch-rules.ts`](../scripts/fetch-rules.ts).

1. **Source** — download the Comprehensive Rules `.txt` from the official Wizards site (with
   auto-discovery of the link, local cache, or a manually-passed file).
2. **Parsing → atomic chunks** — the text is split into **one sub-rule per record**
   (e.g. `601.2a`). This fine granularity is the key retrieval choice: chunks are small and
   semantically coherent. During parsing the **hierarchical context** is tracked
   (chapter › section, e.g. `601. Casting Spells`) and stored in `header_path`.
3. **Glossary** — each glossary entry becomes a `kind = 'glossary'` chunk (term + definition),
   useful for keywords like *Deathtouch*, *Trample*, etc.
4. **Cross-reference extraction** — a regex finds the rule numbers cited in each chunk's text and
   stores them in `refs`. These power the **cross-reference expansion** at runtime.
5. **Embeddings** — for each chunk the embedding is computed over the text **enriched with the
   header** (`embedText`: `header_path + rule_id + text`), so the vector "knows" the context the
   rule lives in. Embeddings are computed **in batches (64)** with the local model and inserted into
   `vec_rules`.
6. **FTS rebuild** — the `rules_fts` index is rebuilt from the `rules` table.

The embedding model (`src/lib/server/embeddings.ts`) is
**`Xenova/paraphrase-multilingual-MiniLM-L12-v2`** (384 dimensions). It is **multilingual**: it maps
many languages into the **same vector space**. This is what lets you **ask in one language** and
retrieve **English rules**. Embeddings are normalized, so cosine similarity equals the dot product.

### 2.2 Runtime pipeline (on every question)

Orchestrated by [`src/lib/server/judge.ts`](../src/lib/server/judge.ts) → `runJudge()`.

```
user question
   │
   ▼
[1] PREPROCESSING (LLM)  ── rewrites the follow-up · extracts card names · extracts EN terms
   │
   ├─────────────► [2] CARD LOOKUP (SQLite, no embeddings)
   │
   ▼
[3] HYBRID RETRIEVAL over the rules
      ├─ vector search (sqlite-vec, KNN)
      ├─ full-text search (FTS5/BM25)
      ├─ RRF fusion
      └─ cross-reference expansion (refs)
   │
   ▼
[4] PROMPT BUILDING  ── retrieved rules + card oracle texts + confidence note
   │
   ▼
[5] GENERATION (Gemini, streaming) ── answer constrained to the sources
   │
   ▼
answer + cited sources
```

**[1] Preprocessing** ([`preprocess.ts`](../src/lib/server/preprocess.ts)) — a single "lite" LLM
call (temperature 0, JSON output) that does three things:
- **rewrites** the last message into a standalone question, resolving pronouns and references to
  history (*"and what if it were a Doom Blade instead?"* → full question);
- extracts the **card names** mentioned and normalizes them to the **official English name**
  (*"Fulmine"* → *"Lightning Bolt"*);
- extracts the **English rule terms** (*"lethal touch"* → `["deathtouch", "lethal damage"]`).

If the call fails, processing continues with the raw message: retrieval still works.

**[2] Card lookup** ([`cards.ts`](../src/lib/server/cards.ts)) — the extracted names are resolved
to the canonical card record: exact match first, then FTS5 (`AND` of all tokens, falling back to
`OR`), with tokens/emblems deprioritized. It returns the exact **official oracle text** — no
hallucinations about card text.

**[3] Hybrid retrieval** ([`rules.ts`](../src/lib/server/rules.ts) → `retrieveRules()`) is the
heart of the RAG. The query is the rewritten question **joined with the English terms** (so the
BM25/English side latches on well). Then:

1. **Vector search** — embed the query → KNN over `vec_rules` (`MATCH ... ORDER BY distance LIMIT
   k`). Captures **semantic** similarity, even cross-lingually.
2. **Full-text search** — the significant terms become an `FTS5 MATCH` query (BM25). Captures the
   exact **lexical** match (rule numbers, precise keywords).
3. **RRF fusion (Reciprocal Rank Fusion)** — the two result lists are combined by **rank**, not by
   raw score: `score(doc) += 1 / (k + rank)` with `k = 60`. Robust because it does not require
   normalizing different scales (cosine distance vs BM25).
4. **Cross-reference expansion** — for the top results we look at the `refs` (rules cited in the
   text) and add those related rules not already present. Recovers context that neither the vector
   nor the BM25 side would have caught alone (e.g. a rule that says *"see 509.1"*).
5. **Confidence score** — from the best vector distance we derive a cosine similarity and classify
   it as `high / medium / low`. It is used to make the judge **declare uncertainty**.

**[4] Prompt building** — `runJudge()` assembles the user turn with: the rewritten question, the
**Comprehensive Rules** block (retrieved rules, truncated to 900 chars to keep the free-tier token
budget), the **cited cards** block (official oracle text) and, if confidence is low, an **explicit
note** telling the judge to say so. Only the last 6 turns of history are kept.

**[5] Generation** ([`gemini.ts`](../src/lib/server/llm/gemini.ts)) — Gemini answers in
**streaming** (temperature 0.2), guided by a **constraining system prompt**: use **only** the
provided sources, **cite the rule numbers**, **distinguish** rule from inference, and **admit
uncertainty** when the sources are not enough ("it's best to consult a human judge"). This is what
makes the system a true RAG and not an LLM that improvises.

> Note: the system prompt currently instructs the judge to answer in **Italian**. Because the
> embedding model is multilingual, the retrieval and card-lookup steps work regardless of the
> question's language; only the final answer language is fixed by the prompt.

### 2.3 Transport to the client

The endpoint [`api/chat/+server.ts`](../src/routes/api/chat/+server.ts) responds with a text
stream: the **first line** is a JSON metadata blob (rewritten question, confidence, cards,
**sources**), and everything after it is the judge's answer token by token. The UI always shows the
**sources**, so the user can verify the citations.

---

## 3. Notable design choices

- **Hybrid search instead of vector-only.** MTG rules contain precise identifiers (`509.1a`,
  keywords) where BM25 beats embeddings; but natural-language questions need semantic similarity.
  RRF takes the best of both.
- **Local multilingual embeddings.** Question in any language, corpus in English, **no cost** and
  no API for the embeddings. All spend is confined to the 2 LLM calls per question.
- **Atomic chunks + hierarchical header.** Fine granularity for retrieval precision, but the header
  in the embedding text keeps the chunk from losing context.
- **Cross-reference expansion.** Exploits the intrinsic structure of the CR (the dense web of
  cross-references between rules) as a free retrieval signal.
- **LLM provider behind an interface.** Gemini is a swappable detail; with two distinct models
  (a "strong" judge vs a "lite" preprocessor) you exploit separate rate-limit buckets, with
  retry/backoff on the free-tier 429s.
- **Explicit confidence + forced honesty.** The retrieval score steers the prompt away from making
  things up: better an "I don't know" than a hallucinated rule.

---

## 4. Quick file reference

| File | Responsibility |
|---|---|
| `scripts/fetch-rules.ts` | parse CR → atomic chunks → embeddings → indexes |
| `scripts/fetch-cards.ts` | bulk import of Scryfall cards |
| `src/lib/server/db.ts` | SQLite schema + sqlite-vec helpers |
| `src/lib/server/embeddings.ts` | local multilingual embedding model |
| `src/lib/server/rules.ts` | **hybrid retrieval** (vector + BM25 + RRF + cross-refs) |
| `src/lib/server/cards.ts` | card-name resolution → oracle text |
| `src/lib/server/preprocess.ts` | question rewriting + card/term extraction |
| `src/lib/server/judge.ts` | pipeline orchestration + judge prompt |
| `src/lib/server/llm/` | provider abstraction + Gemini implementation |
| `src/routes/api/chat/+server.ts` | streaming endpoint (metadata + answer) |
| `scripts/eval.ts` | evaluation (retrieval hit-rate + AI-judge) |
