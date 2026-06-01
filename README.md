# ⚖️ manajudge

Giudice di torneo AI per **Magic: The Gathering**. Chatbot testuale in italiano che risponde
su regole e interazioni tra carte citando le **Comprehensive Rules** ufficiali e il testo oracle
reale delle carte.

Tutto gira in locale a costo zero, tranne le chiamate al modello LLM (free tier di Google Gemini).

## Come funziona

- **Regole** → ricerca **ibrida** (vettoriale `sqlite-vec` + full-text BM25 `FTS5`) sulle
  Comprehensive Rules spezzate in chunk atomici con contesto gerarchico + espansione dei rimandi.
- **Embedding** → modello **multilingue** locale (`transformers.js`): chiedi in **italiano**,
  le regole restano in **inglese**.
- **Carte** → l'LLM estrae i nomi citati (anche in italiano) e li normalizza al nome inglese,
  poi il DB recupera il testo oracle esatto (bulk Scryfall, ~37k carte).
- **Risposta** → Gemini risponde in italiano, vincolato a usare solo le fonti recuperate, a
  citare i numeri di regola e a dichiarare l'incertezza. Le **fonti** sono sempre mostrate.

Stack: SvelteKit + SQLite (`better-sqlite3` + `sqlite-vec`). Il provider LLM è dietro
un'interfaccia (`src/lib/server/llm/`), quindi si può sostituire Gemini con Groq/Ollama.

## Setup

1. Dipendenze:
   ```bash
   npm install
   ```
2. Chiave API gratuita di Google AI Studio → https://aistudio.google.com/apikey
   ```bash
   cp .env.example .env
   # poi inserisci GEMINI_API_KEY=... in .env
   ```
   > **Limiti free tier:** oltre al tetto giornaliero c'è un limite di **pochi richieste al
   > minuto** (~5–10 RPM su `gemini-2.5-flash`). L'app fa 2 chiamate per domanda, quindi l'uso
   > interattivo va bene; i 429 sono comunque gestiti con **retry/backoff** automatico. L'`eval`
   > è bursty: ha un throttle configurabile via `EVAL_DELAY_MS` (default 12s tra le domande).
3. Costruisci il database (una volta sola; rilancia all'uscita di un nuovo set):
   ```bash
   npm run data:cards    # scarica le carte da Scryfall (~37k) -> data/judge.db
   npm run data:rules    # scarica e indicizza le Comprehensive Rules (embedding locale)
   ```
   > Se `data:rules` non trova il file automaticamente, scarica il `.txt` da
   > https://magic.wizards.com/en/rules e lancia:
   > `npm run data:rules -- /percorso/al/file.txt`

4. Avvia:
   ```bash
   npm run dev
   ```

## Esempi di domande

In [`docs/esempi-domande.md`](docs/esempi-domande.md) trovi una raccolta di domande reali
per categoria (regole base, stack, combattimento, interazioni tra carte, casistiche avanzate,
follow-up conversazionali e domande ambigue per testare l'onestà del giudice).

## Valutazione

Set di ~24 domande da giudice con regole attese in `data/eval/eval-set.json`.

```bash
npm run eval
```

- **Retrieval hit-rate** (sempre): la regola attesa è tra quelle recuperate?
- **AI-judge** (se `GEMINI_API_KEY` è presente): un LLM valuta la correttezza della risposta.

Usa il punteggio come baseline prima di modificare prompt, chunking o retrieval.

## Struttura

```
scripts/        fetch-cards.ts · fetch-rules.ts · eval.ts
src/lib/server/ db.ts · embeddings.ts · rules.ts · cards.ts · preprocess.ts · judge.ts · llm/
src/routes/     +page.svelte (UI chat) · api/chat/+server.ts (endpoint streaming)
data/           (gitignored) sorgenti scaricate + judge.db · data/eval/ versionato
```

## Fuori scope (v1)

Storico conversazioni persistente tra sessioni, riconoscimento carte da foto, altri TCG,
autenticazione. L'astrazione del provider e lo schema DB lasciano spazio per aggiungerli.
