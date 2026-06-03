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
