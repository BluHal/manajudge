# Companion app

The Flutter client (Android + iOS) of the manajudge product family. It hosts three
surfaces: two **AI surfaces** that call the Backend (**Judge**, **Card Search**, defined
in the [Backend glossary](../CONTEXT.md)) and the local **Companion** for tracking a game
at the table.

## Language

**Companion** (the table tool):
The offline, on-device part of the app used *during a game* — life, commander damage,
poison, counters, dice. It never calls the Backend and never costs anything. _Avoid_:
calling the whole app "the Companion" — the app also hosts the **Judge** and **Card
Search**; the **Companion** is specifically the at-the-table tool.

**Game**:
One session of play tracked by the **Companion**: 2–4 **Seats**, a starting life total,
and a running **Game log**. Single-device in v1 (one phone tracks everyone). Distinct
from a **Match** in any competitive sense — it is just the local state being tracked.

**Seat**:
One player's position within a **Game**. Carries that player's life, commander-damage
column, poison, and counters. Each Seat is shown with a distinct mana-color accent
(WUBRG). Two-to-four Seats per Game.

**Commander damage**:
A per-source-per-Seat damage tally (the matrix of who dealt how much commander damage to
whom). Relevant to the Commander format; 21 from a single commander is lethal. Tracked by
the **Companion**, never inferred by the **Judge**.

**Game log**:
The append-only history of life/counter changes within a **Game**, so players can settle
"what was my total a turn ago?". Local to the device; cleared on new **Game**.

**AI Request**:
The **billable unit**. One invocation of a Backend AI surface — *one Judge answer* **or**
*one Card Search*. Counted per request, against a single per-**User** counter. The
**Companion** is never an AI Request (it is local and always free). _Avoid_: "question" —
a Judge conversation is multi-turn and each turn is its own AI Request.

**User**:
The identity an **AI Request** is metered against. In v1 a **User** is an anonymous,
device-scoped identity generated on first launch (no login). The Backend stores a real
`users` record from day one so that real authentication (Sign in with Apple / Google) can
later be *linked* to the same User without a rewrite.

**Plan** (a.k.a. Entitlement):
What a **User** is allowed to do. In v1 there is a free **Plan** with a quota of N **AI
Requests**; beyond it, AI surfaces are gated and a paid **Plan** (subscription) is
required. The **Companion** is outside every **Plan** — always free. _Avoid_:
"permission" — say **Plan**/**Entitlement** for usage allowance, distinct from any future
role-based access.

**Quota**:
The count of **AI Requests** a **User**'s **Plan** grants, and how many remain. Enforced
server-side. Resetting/refilling cadence (e.g. monthly) is a Plan property.
