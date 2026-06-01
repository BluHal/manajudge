# Architettura & RAG — manajudge

Questo documento descrive lo **stack tecnologico** di manajudge e **come è stato implementato il
RAG** (Retrieval-Augmented Generation) che permette al chatbot di rispondere da giudice di Magic
citando le Comprehensive Rules ufficiali e il testo reale delle carte.

---

## 1. Stack tecnologico

| Livello | Tecnologia | Ruolo |
|---|---|---|
| **Framework web** | SvelteKit 2 + Svelte 5 | UI chat + endpoint server (`+server.ts`) |
| **Runtime / build** | Vite 8, TypeScript, `tsx` per gli script | dev server, bundling, esecuzione script di data-ingestion |
| **Database** | SQLite via `better-sqlite3` (sincrono) | unico store: carte, regole, indici |
| **Ricerca vettoriale** | `sqlite-vec` (estensione `vec0`) | KNN sugli embedding delle regole |
| **Ricerca full-text** | FTS5 (built-in SQLite, BM25) | match lessicale su regole e nomi carta |
| **Embedding** | `@huggingface/transformers` (transformers.js) | modello multilingue **locale**, a costo zero |
| **LLM** | Google Gemini (`@google/genai`, free tier) | pre-elaborazione + risposta del giudice |

**Principio di design:** tutto gira **in locale a costo zero**, tranne le chiamate al modello LLM
(free tier Gemini). Embedding, indici e ricerca non richiedono servizi esterni né API a pagamento.

### Modello dei dati (SQLite)

Lo schema è in [`src/lib/server/db.ts`](../src/lib/server/db.ts). Cinque "aree":

- **`cards`** — carte uniche (oracle) di Scryfall, ~37k record. Nessun embedding: si recuperano per
  nome via lookup esatto + FTS.
- **`cards_fts`** — indice FTS5 sui nomi (inglese + italiano stampato) per il match fuzzy.
- **`rules`** — Comprehensive Rules spezzate in **chunk atomici** (una sotto-regola per record) +
  voci di glossario. Ogni record ha `rule_id`, `parent_id`, `header_path` (contesto gerarchico) e
  `refs` (numeri di regola citati nel testo).
- **`rules_fts`** — indice FTS5 *external-content* su `rules` (lato BM25 della ricerca ibrida),
  tokenizer `porter unicode61` (stemming inglese).
- **`vec_rules`** — tabella virtuale `vec0` con gli embedding `FLOAT[384]` delle regole (lato
  vettoriale della ricerca ibrida).

L'astrazione del provider LLM è in [`src/lib/server/llm/provider.ts`](../src/lib/server/llm/provider.ts):
una semplice interfaccia con `completeJSON()` e `stream()`, così Gemini è sostituibile con
Groq/Ollama senza toccare la logica del giudice.

---

## 2. Il RAG, passo per passo

Il RAG di manajudge ha due fasi: **indicizzazione offline** (build del DB, una tantum) e
**retrieval + generation a runtime** (a ogni domanda).

### 2.1 Indicizzazione offline (`npm run data:rules`)

Script: [`scripts/fetch-rules.ts`](../scripts/fetch-rules.ts).

1. **Sorgente** — scarica il `.txt` delle Comprehensive Rules dal sito ufficiale Wizards (con
   auto-discovery del link, cache locale, o file passato a mano).
2. **Parsing → chunk atomici** — il testo viene spezzato in una **sotto-regola per record**
   (es. `601.2a`). Questa granularità fine è la scelta chiave del retrieval: i chunk sono piccoli e
   semanticamente coerenti. Durante il parsing si tiene traccia del **contesto gerarchico**
   (capitolo › sezione, es. `601. Casting Spells`) salvato in `header_path`.
3. **Glossario** — ogni voce del glossario diventa un chunk `kind = 'glossary'` (termine +
   definizione), utile per parole chiave come *Deathtouch*, *Trample*, ecc.
4. **Estrazione dei rimandi** — una regex trova i numeri di regola citati nel testo di ogni chunk e
   li salva in `refs`. Serviranno per l'**espansione dei rimandi** a runtime.
5. **Embedding** — per ogni chunk si calcola l'embedding del testo **arricchito con l'header**
   (`embedText`: `header_path + rule_id + testo`), così il vettore "sa" in che contesto vive la
   regola. Embedding calcolati **a batch (64)** con il modello locale, inseriti in `vec_rules`.
6. **Rebuild FTS** — l'indice `rules_fts` viene ricostruito dalla tabella `rules`.

Il modello di embedding (`src/lib/server/embeddings.ts`) è
**`Xenova/paraphrase-multilingual-MiniLM-L12-v2`** (384 dimensioni). È **multilingue**: mappa
italiano e inglese nello **stesso spazio vettoriale**. Questo è ciò che permette di **chiedere in
italiano** e recuperare **regole in inglese**. Gli embedding sono normalizzati, quindi la similarità
coseno equivale al dot product.

### 2.2 Pipeline a runtime (a ogni domanda)

Orchestrata da [`src/lib/server/judge.ts`](../src/lib/server/judge.ts) → `runJudge()`.

```
domanda utente
   │
   ▼
[1] PRE-ELABORAZIONE (LLM)  ── riscrive il follow-up · estrae nomi carta · estrae termini EN
   │
   ├─────────────► [2] LOOKUP CARTE (SQLite, no embedding)
   │
   ▼
[3] RETRIEVAL IBRIDO sulle regole
      ├─ ricerca vettoriale (sqlite-vec, KNN)
      ├─ ricerca full-text (FTS5/BM25)
      ├─ fusione RRF
      └─ espansione dei rimandi (refs)
   │
   ▼
[4] COSTRUZIONE PROMPT  ── regole recuperate + testi oracle carte + nota di confidenza
   │
   ▼
[5] GENERATION (Gemini, streaming) ── risposta in italiano, vincolata alle fonti
   │
   ▼
risposta + fonti citate
```

**[1] Pre-elaborazione** ([`preprocess.ts`](../src/lib/server/preprocess.ts)) — un'unica chiamata
LLM "lite" (temperature 0, output JSON) che fa tre cose:
- **riscrive** l'ultimo messaggio come domanda autonoma, risolvendo pronomi e riferimenti allo
  storico (*"e se invece fosse un Doom Blade?"* → domanda completa);
- estrae i **nomi delle carte** citate e li normalizza al **nome ufficiale inglese**
  (*"Fulmine"* → *"Lightning Bolt"*);
- estrae i **termini di regola in inglese** (*"tocco letale"* → `["deathtouch", "lethal damage"]`).

Se la chiamata fallisce, si prosegue con il messaggio grezzo: il retrieval funziona comunque.

**[2] Lookup carte** ([`cards.ts`](../src/lib/server/cards.ts)) — i nomi estratti vengono risolti
nel record carta canonico: prima match esatto, poi FTS5 (`AND` di tutti i token, ripiego su `OR`),
con i token/emblemi deprioritizzati. Restituisce il **testo oracle ufficiale** esatto — niente
allucinazioni sul testo delle carte.

**[3] Retrieval ibrido** ([`rules.ts`](../src/lib/server/rules.ts) → `retrieveRules()`) è il cuore
del RAG. La query è la domanda riscritta **unita ai termini inglesi** (così il lato BM25, inglese,
aggancia bene). Poi:

1. **Ricerca vettoriale** — embedding della query → KNN su `vec_rules` (`MATCH ... ORDER BY
   distance LIMIT k`). Cattura la similarità **semantica** anche cross-lingua.
2. **Ricerca full-text** — i termini significativi diventano una query `FTS5 MATCH` (BM25). Cattura
   il match **lessicale** esatto (numeri di regola, keyword precise).
3. **Fusione RRF (Reciprocal Rank Fusion)** — le due liste di risultati vengono combinate per
   **rango**, non per punteggio grezzo: `score(doc) += 1 / (k + rank)` con `k = 60`. Robusto perché
   non richiede di normalizzare scale diverse (distanza coseno vs BM25).
4. **Espansione dei rimandi** — per i migliori risultati si guardano i `refs` (regole citate nel
   testo) e si aggiungono quelle regole correlate non già presenti. Recupera contesto che né il
   vettoriale né il BM25 avrebbero pescato da soli (es. una regola che dice *"vedi 509.1"*).
5. **Score di confidenza** — dalla migliore distanza vettoriale si deriva una similarità coseno e si
   classifica `alta / media / bassa`. Serve a far **dichiarare l'incertezza** al giudice.

**[4] Costruzione prompt** — `runJudge()` assembla il turno utente con: la domanda riscritta, il
blocco **Comprehensive Rules** (regole recuperate, troncate a 900 char per contenere i token del
free tier), il blocco **carte citate** (testo oracle ufficiale) e, se la confidenza è bassa, una
**nota esplicita** che invita il giudice a dichiararlo. Si tengono solo gli ultimi 6 turni di
storico.

**[5] Generation** ([`gemini.ts`](../src/lib/server/llm/gemini.ts)) — Gemini risponde in
**streaming** (temperature 0.2), guidato da un **system prompt vincolante**: usare **solo** le fonti
fornite, **citare i numeri di regola**, **distinguere** regola da inferenza, e **ammettere
l'incertezza** quando le fonti non bastano ("conviene consultare un giudice umano"). Questo è ciò che
rende il sistema un vero RAG e non un LLM che improvvisa.

### 2.3 Trasporto al client

L'endpoint [`api/chat/+server.ts`](../src/routes/api/chat/+server.ts) risponde con uno stream di
testo: la **prima riga** è un JSON di metadati (domanda riscritta, confidenza, carte, **fonti**),
tutto ciò che segue è la risposta del giudice token-per-token. La UI mostra sempre le **fonti**, così
l'utente può verificare le citazioni.

---

## 3. Scelte di design notevoli

- **Ricerca ibrida invece di solo-vettoriale.** Le regole MTG contengono identificatori precisi
  (`509.1a`, keyword) dove BM25 batte gli embedding; ma le domande in linguaggio naturale richiedono
  similarità semantica. RRF prende il meglio di entrambi.
- **Embedding multilingue locale.** Domanda in italiano, corpus in inglese, **nessun costo** e
  nessuna API per gli embedding. Tutta la spesa è confinata alle 2 chiamate LLM per domanda.
- **Chunk atomici + header gerarchico.** Granularità fine per la precisione del retrieval, ma
  l'header nel testo dell'embedding evita che il chunk perda il contesto.
- **Espansione dei rimandi.** Sfrutta la struttura intrinseca delle CR (il fitto reticolo di
  rimandi tra regole) come segnale di retrieval gratuito.
- **Provider LLM dietro interfaccia.** Gemini è un dettaglio sostituibile; con due modelli distinti
  (giudice "forte" vs pre-elaborazione "lite") si sfruttano bucket di rate-limit separati, con
  retry/backoff sui 429 del free tier.
- **Confidenza esplicita + onestà forzata.** Il punteggio di retrieval guida il prompt a non
  inventare: meglio un "non lo so" che una regola allucinata.

---

## 4. Riferimenti rapidi ai file

| File | Responsabilità |
|---|---|
| `scripts/fetch-rules.ts` | parsing CR → chunk atomici → embedding → indici |
| `scripts/fetch-cards.ts` | import bulk carte Scryfall |
| `src/lib/server/db.ts` | schema SQLite + helper sqlite-vec |
| `src/lib/server/embeddings.ts` | modello di embedding multilingue locale |
| `src/lib/server/rules.ts` | **retrieval ibrido** (vettoriale + BM25 + RRF + rimandi) |
| `src/lib/server/cards.ts` | risoluzione nomi carta → testo oracle |
| `src/lib/server/preprocess.ts` | riscrittura domanda + estrazione carte/termini |
| `src/lib/server/judge.ts` | orchestrazione pipeline + prompt del giudice |
| `src/lib/server/llm/` | astrazione provider + implementazione Gemini |
| `src/routes/api/chat/+server.ts` | endpoint streaming (metadati + risposta) |
| `scripts/eval.ts` | valutazione (retrieval hit-rate + AI-judge) |
</content>
</invoke>
