# ⚖️ manajudge

A cross-platform companion for **Magic: The Gathering** that unifies three surfaces:

1. **Judge** — ask a rules/interaction question, get a cited prose answer.
2. **Card Search** — a natural-language query → a ranked list of real cards.
3. **Companion** — the at-the-table tracker (life, commander damage, poison, counters, dice).

The first two are **AI Requests** served by the hosted manajudge **Backend**; the third runs
entirely on-device and is always free.

## Monorepo layout

This repository is a **monorepo** with two bounded contexts (see
[`CONTEXT-MAP.md`](./CONTEXT-MAP.md)):

| Context | Path | Toolchain | Glossary |
|---|---|---|---|
| **Backend** | [`backend/`](./backend) | SvelteKit 2 / TypeScript / Node | [`CONTEXT.md`](./CONTEXT.md) |
| **Companion app** | [`app/`](./app) | Flutter / Dart | [`app/CONTEXT.md`](./app/CONTEXT.md) |

- **Backend** — the existing AI engine (RAG Judge + semantic Card Search) exposed over HTTP.
  Run it from `backend/`; see [`backend/README.md`](./backend/README.md).
- **Companion app** — the Flutter client (Android + iOS). Run it from `app/`.

System-wide architectural decisions live in [`docs/adr/`](./docs/adr); the product plan and
roadmap in [`docs/companion-app-plan.md`](./docs/companion-app-plan.md).

## Quick start

```bash
# Backend (AI surfaces)
cd backend && npm install && npm run dev

# Companion app (Flutter)
cd app && flutter run
```
