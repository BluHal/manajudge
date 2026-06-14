# Context map — manajudge

This repository is a **monorepo** with two bounded contexts that share a product
family but speak different languages and have different toolchains.

| Context | Lives in | Toolchain | Glossary |
|---|---|---|---|
| **Backend** | `backend/` (currently the repo root) | SvelteKit 2 / TypeScript / Node | [`CONTEXT.md`](./CONTEXT.md) |
| **Companion app** | `app/` (Flutter, to be scaffolded) | Flutter / Dart | [`app/CONTEXT.md`](./app/CONTEXT.md) |

The seam between the two is the **HTTP API contract**: the Companion app is a thin
client that calls the Backend for the AI surfaces (**Judge**, **Card Search**) and
keeps the table-side **Companion** features entirely local.

System-wide architectural decisions live in [`docs/adr/`](./docs/adr/). The product
plan (ideas, infrastructure, roadmap) lives in
[`docs/companion-app-plan.md`](./docs/companion-app-plan.md).

> Note on file layout: the Backend code physically lives at the repo root today.
> The `backend/` move happens in Phase 0 of the roadmap; this map already describes
> the target so the contexts read clearly.
