# Card Search as a separate semantic index, not an extension of the Judge RAG

## Status

accepted

## Context

manajudge's existing surface is the **Judge**: it answers a rules/interaction *question* by
retrieving **Rule** chunks (hybrid vector + BM25) and the **oracle text** of cited **Card**s, then
*generating* a prose answer. Cards today have **no embeddings** — they are resolved by name only
(exact + FTS5 over names).

The new **Card Search** feature answers a different need: given a natural-language query, return a
*ranked list of real **Card**s* matching it ("cards that copy opponents' spells", "ramp without
lands"). This is a different retrieval target (cards, not rules) and a different output shape (a
list, not generated prose).

## Decision

Build Card Search as a **second retriever that reuses the existing infrastructure** — the local
multilingual embedding model, `sqlite-vec`, the SQLite database, the LLM-preprocess pattern, the
LLM provider abstraction — but is a **distinct pipeline with its own index, corpus and output**.
The Judge is left untouched (no regression risk on the current product).

Concretely, for v1:

- **Scope = Effect search only.** Semantic similarity of oracle text. **Synergy search**
  ("cards that interact well with Murktide Regent") is explicitly **out of scope** — see below.
- **Separate surface, reusable service.** A standalone `searchCards(query)` service with a clean
  boundary, so the future companion app (which will host both the chat/Judge and search) or a later
  intent router can call it without rework. v1 ships it as a separate UI surface, not as a router
  inside the Judge.
- **Multi-vector index with max-pool.** One vector for the card *core* (`type_line + oracle_text`)
  **plus one vector per Ruling**, all keyed by `oracle_id`. At query time, rank cards by their
  best-matching vector (max-pool). This avoids diluting a card's primary effect with its many
  edge-case Rulings, and mirrors the atomic-chunk granularity already used for Rules.
- **Vector-only retrieval for v1** (no BM25). The differentiating queries are semantic (community
  jargon like "ramp" appears in *no* oracle text). Hybrid is deferred until eval shows exact-keyword
  queries underperforming; the pattern already exists in `rules.ts` to copy when needed.
- **LLM preprocess extracts structured filters.** The preprocess step (extending `preprocess.ts`)
  produces a semantic intent **plus** structured filters (type, color, cmc, p/t, keywords, and
  format **legality**). Negation ("without lands") is handled here as an exclude-`Land` filter — it
  never reaches the embedding, which cannot represent negation.
- **Filter-then-rank.** Structured filters restrict the candidate set *before* the KNN, so selective
  deckbuilding filters (format + color + type) don't silently return too few results — the failure
  mode of post-filtering top-K. Implemented by computing the passing `oracle_id`s with full SQL on
  the `cards` table (`type_line LIKE`, `json_extract(legalities, …)`, etc.) and constraining the KNN
  with `... AND oracle_id IN (…)`. We use the candidate-set approach rather than `vec0` metadata
  columns because metadata columns only support scalar equality/comparison — they cannot express
  `type_line LIKE '%Land%'` or multivalued colors/legalities.
- **Reuse the existing embedding model, measure before swapping.** Keep
  `paraphrase-multilingual-MiniLM-L12-v2` for v1; if the card eval-set shows poor recall on the
  asymmetric query/card case, swap to a retrieval-tuned local model (e.g. `multilingual-e5-small`).

This requires one data-pipeline change: import Scryfall `legalities` (already present in the
`oracle_cards` bulk) into the schema, so the legality filter has data behind it.

## Why not the alternatives

- **Extend the Judge RAG / one unified RAG.** Different corpus, output and prompt; fusing them would
  require an intent router built *before* the two paths it routes exist. Affording a clean separate
  service now keeps the future companion app and a later router cheap to build.
- **One vector per card (core + all Rulings concatenated).** Simpler, but heavily-ruled cards — the
  complex ones users search for — get their primary effect drowned by 20+ edge-case Rulings.
- **Synergy search via embeddings.** Oracle-text similarity does not capture synergy: a card's
  combo pieces have wording nothing like the card itself. Synergy lives in deck co-occurrence / play
  patterns, which needs a different data source (e.g. EDHREC-style data), not another vector index.
  Forcing it into embeddings would ship a feature that quietly returns wrong answers.

## Consequences

- `vec_cards` holds more rows than there are cards (cards + Rulings); the returned unit is still the
  card. Embedding cost is a one-off, local, zero-cost build.
- A schema change + re-run of `npm run data:cards` is needed to add `legalities`.
- A small card-focused eval-set (query → expected cards) is needed to validate retrieval quality and
  to drive the model-swap and hybrid-search decisions.
