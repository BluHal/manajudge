# manajudge becomes a backend-as-a-service for a Flutter companion app

## Status

accepted

## Context

manajudge today is a SvelteKit web app that does everything in-process: a local SQLite
database (~37k cards + Comprehensive Rules chunks), a **local** multilingual embedding
model (transformers.js), `sqlite-vec` KNN, and Gemini calls for preprocessing and the
**Judge**'s answer. The two AI surfaces (**Judge**, **Card Search**) are already exposed
as HTTP endpoints, and ADR 0001 deliberately built Card Search as a standalone service
"so a future companion app … can call it independently".

We now want a cross-platform mobile **Companion app** (Android + iOS, built in Flutter)
that hosts those two AI surfaces *plus* a classic at-the-table companion (life, commander
damage, dice, etc.). The foundational question is where the intelligence runs.

## Decision

**The app is a thin client; manajudge is a hosted HTTP backend.** All retrieval +
generation stays server-side and is reused as-is. The Flutter app calls the Backend for
the **Judge** and **Card Search**; the table-side **Companion** runs entirely on-device
and offline.

We considered running the LLMs on-device and rejected it for v1. The two model jobs have
opposite feasibility: embeddings + vector retrieval are tiny and would run fine on a
phone, but the **Judge**'s grounded, citation-bearing generation is exactly where small
on-device models (3–4B, or OS-provided Apple Foundation Models / Gemini Nano) hallucinate
— the opposite of manajudge's "better an 'I don't know' than an invented rule" value.
On top of quality: device coverage (only flagships run a 4B acceptably) would force a
backend fallback anyway, app size balloons (model + 37k-card DB), and sustained inference
drains battery and heats the phone at the table. On-device is therefore kept as a possible
*later* offline optimization (on-device retrieval + OS model), not the foundation.

Consequences of the thin-client choice that shape the rest of the system:

- **Warm, stateful hosting required.** `better-sqlite3` is synchronous/single-process and
  the embedding model loads into process RAM, so the Backend cannot be serverless with
  scale-to-zero (cold start would reload model + DB). It needs an always-on instance with
  a persistent volume. v1 hosts on **Oracle Cloud Always Free** (ARM A1 VM: generous RAM,
  persistent block storage, free), with self-host + Cloudflare Tunnel as the fallback.
- **Users and entitlements exist from day one.** The product is personal first but
  designed for a public release (free **AI Request** quota → paid subscription). The
  Backend carries a real `users`/`Plan`/**Quota** schema immediately; v1 uses an anonymous
  device-scoped **User** (no login). Real auth (Sign in with Apple / Google) is later
  *linked* to the same User — additive, not a rewrite.
- **Metering boundary.** Only Gemini-touching surfaces are metered as **AI Requests**; the
  **Companion** is always free and never reaches the Backend.

## Why not the alternatives

- **On-device everything.** See above: quality on grounded rules reasoning, device
  coverage, app size, and battery make it the wrong foundation; it also drops Gemini.
- **Serverless backend (scale-to-zero).** Cheaper at idle but cold-loads the embedding
  model + SQLite on every wake; incompatible with the in-process, file-based design.
- **No user model in v1, add it later.** Exactly the rewrite we want to avoid given the
  stated intent to potentially go public with subscriptions.

## Consequences

- The repo becomes a **monorepo** (`backend/` + `app/`) with two bounded contexts; see
  [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md).
- The **API contract** becomes a first-class seam (every request carries a User identity;
  AI endpoints check **Quota**). The existing web UI is kept as a dev/demo client.
- Going public later adds real auth, a paid LLM tier (the Gemini free tier's per-project
  rate limit will not survive multi-user load), per-user rate limiting, and read replicas
  for the read-only Card Search — but none of it requires re-architecting v1.
