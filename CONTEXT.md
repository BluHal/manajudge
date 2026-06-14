# manajudge

AI tournament judge for Magic: The Gathering. Answers rules and card-interaction
questions by citing the official Comprehensive Rules and the real oracle text of cards,
via a local RAG pipeline.

## Language

**Comprehensive Rules** (CR):
The official, exhaustive Magic rulebook published by Wizards of the Coast. In manajudge it
is split into atomic **Rule** chunks and reached through hybrid retrieval (vector + BM25).
_Avoid_: "the rules" when you mean a **Ruling** — they are different sources.

**Rule**:
A single atomic sub-rule of the **Comprehensive Rules** (e.g. `601.2a`) or a glossary entry,
stored as one record with a `header_path` and cross-reference `refs`.

**Ruling**:
An official clarification of a specific **Card**, shown on Scryfall under the
"Notes and Rules Information" section. Authored by WotC (rules updates) or by Scryfall
editors, dated, and keyed to a card by `oracle_id`. A **Card** has zero or more Rulings.
Rulings are *attached to the card*, not part of the **Comprehensive Rules**.
_Avoid_: "rule" / "note" — say **Ruling** to keep it distinct from a CR **Rule**.

**Card**:
A unique game card identified by `oracle_id` (Scryfall `oracle_cards` bulk). Carries the
official **oracle text**; resolved by name (no embeddings) and injected into the prompt.

**Oracle text**:
The current authoritative wording of a **Card**'s abilities. Distinct from a **Ruling**,
which explains how that text behaves in edge cases.

**Judge**:
The original manajudge surface: answers a rules/interaction *question* by retrieving **Rule**
chunks (hybrid retrieval) plus the **oracle text** of cited **Card**s, then *generating* a prose
answer constrained to those sources. Input is a question; output is a cited answer.
_Avoid_: calling it "the search" — the Judge generates prose, **Card Search** returns a list.

**Card Search**:
A distinct surface that retrieves a *ranked list of **Card**s* matching a natural-language query,
returning real cards from the database (no generated prose, no hallucinated cards). Separate
corpus (cards, not **Rule**s), separate output shape from the **Judge**. Exposed as a standalone
service so a future companion app or intent router can call it independently.

**Effect search**:
The kind of **Card Search** query answered by *semantic similarity of **oracle text*** — "what the
card does" (e.g. "cards that copy opponents' spells", "ramp without lands"). The v1 scope.

**Synergy search**:
A **Card Search** query about how a card *plays with others* (e.g. "cards that interact well with
Murktide Regent"). **Out of scope for v1**: oracle-text similarity does not capture synergy, which
lives in deck co-occurrence / play patterns, not in the card's wording. Needs a different data
source (e.g. deck co-occurrence) — not just another vector index.
