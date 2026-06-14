# manajudge Companion app — plan (ideas · infrastructure · roadmap)

A cross-platform (Android + iOS, Flutter) companion app for Magic: The Gathering. It
unifies three surfaces:

1. **Judge** — ask a rules/interaction question, get a cited prose answer (existing).
2. **Card Search** — natural-language query → ranked list of real cards (existing).
3. **Companion** — the at-the-table tool: life, commander damage, poison, counters, dice
   (new, local, offline).

The first two are **AI Requests** served by the hosted manajudge **Backend**; the third
is entirely on-device and free. Glossary: [`app/CONTEXT.md`](../app/CONTEXT.md) and
[`CONTEXT.md`](../CONTEXT.md). Foundational decision:
[ADR 0002](./adr/0002-flutter-companion-backend-as-service.md).

---

## 1. Decisions locked in this design session

| # | Decision |
|---|---|
| 1 | **Backend-as-a-service.** manajudge = hosted HTTP backend; Flutter = thin client. On-device LLMs rejected for v1 (quality on grounded rules, device coverage, app size, battery); kept as a possible later offline mode. |
| 2 | **Personal first, designed for public.** Free **AI Request** quota → paid subscription. Users + entitlements latent from day one. |
| 3 | **Metered unit = AI Request** (one Judge answer *or* one Card Search), single per-User counter, per request. **Companion is always free and unmetered.** |
| 4 | **Companion v1 is single-device, max 4 players.** Commander is the primary case (40 life, commander damage, poison); 1v1 (20 life) supported. **Multi-device sync = high-priority post-v1.** |
| 5 | **Monorepo** (`backend/` + `app/`), two bounded contexts ([`CONTEXT-MAP.md`](../CONTEXT-MAP.md)). |
| 6 | **AI scope = the two existing surfaces only.** No new AI features in v1. |
| 7 | **Identity:** real `users`/Plan/Quota schema from day one; anonymous device-scoped User in v1; real auth (Apple/Google) linked additively later. |
| 8 | **Hosting:** Oracle Cloud Always Free (ARM A1 VM, warm instance + persistent volume); fallback self-host + Cloudflare Tunnel. |
| 9 | **Design:** dark, glanceable, table-first; mana colors (WUBRG) as Seat accents; Judge slightly more "document/authoritative"; one cohesive design system. See [design prompt](./companion-app-design-prompt.md). |

---

## 2. Ideas / feature scope

### 2.1 Companion (table tool) — v1

- **Game** with 2–4 **Seats**; starting life configurable (40 Commander default, 20 for 1v1/constructed).
- **Life** per Seat: big tap targets, +/–1, long-press or swipe for ±5/±10.
- **Commander damage** matrix (per source → per Seat); 21-from-one-commander highlighted.
- **Poison / counters**: poison (10 = loss), plus generic counters (energy, experience, etc.).
- **Dice & randomizers**: d20, d6, coin flip, planar die; "who goes first" picker.
- **Game log**: append-only history of life/counter changes, to settle disputes.
- **Reset / new Game**; per-Seat mana-color accent.

### 2.2 AI surfaces — v1

- **Judge** chat: multi-turn, streaming answer, always shows **cited sources** (rule numbers + card oracle text). Each turn is one **AI Request**.
- **Card Search**: query → ranked real cards (Effect search, per ADR 0001). One **AI Request** per search.
- A visible **Quota** indicator (e.g. "7 free AI requests left"); the Companion is clearly marked free.

### 2.3 Post-v1 backlog (ideas, prioritized)

1. **Multi-device sync** ("room code": each player on their own phone, life syncs in realtime). Flagged *very interesting*. Needs realtime infra (WebSocket / managed realtime), presence, conflict resolution.
2. **Decks** — "my decks" as a bridge across surfaces: build a deck from Card Search results; ask the Judge about a card in a deck; later track which deck a Game used.
3. **Player profiles + cross-game statistics** (win rates, most-played, life-history trends).
4. **On-device offline mode** for AI: on-device retrieval + OS model (Apple Foundation Models / Gemini Nano) as a degraded offline path where the device supports it.
5. **Synergy search** (explicitly out of scope per ADR 0001 until a co-occurrence data source exists).

---

## 3. Infrastructure

### 3.1 Topology

```
 Flutter app (Android/iOS)
   ├─ Companion ........ 100% local, offline, free (no Backend call)
   └─ AI surfaces ...... HTTPS ──► manajudge Backend (Oracle Always Free ARM VM)
                                     ├─ SvelteKit /api (Judge, Card Search)
                                     ├─ better-sqlite3 + sqlite-vec (persistent volume)
                                     ├─ local embedding model (in-process RAM)
                                     ├─ users / Plan / Quota (metering)
                                     └─ Gemini (preprocess + generation)
```

### 3.2 Backend (changes to the current SvelteKit app)

- **Identity middleware**: every request carries a User identity (anonymous device token in v1, header/bearer). Create the `users` row on first sight.
- **Metering + Quota**: wrap the Judge and Card Search endpoints so each successful call increments the per-User **AI Request** count and is rejected (402/quota error) when the free Plan is exhausted. The Companion has no endpoint.
- **Entitlement model**: `plan` (free | paid), quota limit + reset cadence, current count. Server-side enforcement.
- **Stays warm + stateful**: always-on instance, persistent volume for the SQLite file; **no serverless scale-to-zero** (cold start reloads model + DB). ARM64 build of `better-sqlite3` + transformers.js.
- **Web UI kept** as a dev/demo client of the same API.

### 3.3 Hosting

- **v1:** Oracle Cloud Always Free — Ampere A1 ARM VM (generous RAM for model + SQLite), persistent block volume, always-on, $0. Caveats: Oracle signup friction, ARM64 builds, occasional A1 capacity scarcity by region.
- **Fallback:** self-host (PC/mini-PC) + Cloudflare Tunnel — $0, but availability tied to the machine being on.
- **Public-readiness (later):** paid LLM tier (Gemini free per-project rate limit won't survive multi-user), per-user rate limiting, read replica(s) for read-only Card Search, separate the embedding service from the write DB.

### 3.4 App-side data

- Companion state (Games, Seats, Game log) persisted locally (e.g. SQLite/Isar/Drift on device). Survives app restart; cleared on new Game by choice.
- Anonymous User token stored in secure local storage; later linked to a real account.

---

## 4. Roadmap

Phases are vertical slices; each one leaves something usable.

**Phase 0 — Monorepo + Backend hardening**
- Restructure repo into `backend/` + `app/`; add `CONTEXT-MAP.md` (done) and scaffolds.
- Deploy current Backend to Oracle Always Free (ARM build, persistent volume, warm).
- Add identity middleware + `users`/`Plan`/`Quota` schema (latent; no enforcement UI yet).

**Phase 1 — Companion (offline) ships first**
- Flutter app skeleton + design system (from the design prompt).
- Full Companion: Game/Seats, life, commander damage, poison, counters, dice, planar die, Game log, reset. Max 4 players. **No Backend needed** — immediate standalone value.

**Phase 2 — Wire the AI surfaces**
- Judge chat (streaming + cited sources) and Card Search against the Backend.
- Anonymous device-scoped User; **AI Request** metering live (count + visible Quota), but no paywall yet.

**Phase 3 — Entitlements & paywall plumbing**
- Enforce free Quota server-side; subscription gate as a stub/sandbox (still personal).
- Validate the whole free-then-gate flow end to end.

**Phase 4 — Public readiness (only if/when you decide to release)**
- Real auth (Sign in with Apple / Google) linked to the existing User.
- Real subscriptions (StoreKit / Play Billing) → real Plan.
- Backend hardening: paid LLM tier, per-user rate limits, read replicas; store submission, privacy policy.

**Post-v1 backlog** (see §2.3): multi-device sync, decks, profiles/stats, on-device offline mode, synergy search.

---

## 5. Open questions for later

- Quota refill cadence and free limit value (N AI Requests / period) — a Plan property, decide before Phase 3.
- Multi-device sync transport (managed realtime vs self-hosted WebSocket) — decide when that item is picked up.
- Whether Decks become the connective tissue between all three surfaces (could pull them earlier if they prove the product thesis).
