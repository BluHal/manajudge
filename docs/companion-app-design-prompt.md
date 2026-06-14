# Design prompt — manajudge Companion app

Paste the block below into Claude (design) to develop the visual style. It encodes the
direction chosen in the planning session: dark, glanceable, table-first, with WUBRG mana
colors as accents and a slightly more "authoritative/document" feel for the Judge.

---

## Prompt

> You are designing the visual identity and UI for **manajudge**, a cross-platform
> (iOS + Android, built in Flutter) companion app for the trading card game *Magic: The
> Gathering*. Deliver a cohesive design system and key-screen mockups.
>
> **The product has three surfaces, one design language:**
> 1. **Companion** — the at-the-table game tracker. Used live during a game, often in
>    **low light**, frequently one-handed. Tracks life totals, commander damage, poison,
>    generic counters, and dice for **2–4 players**. This is the most-used surface and
>    must be **glanceable**: huge, instantly legible life numbers and large tap targets.
> 2. **Judge** — a chat that answers Magic rules/interaction questions with an
>    authoritative, cited answer (it quotes official rule numbers and card text). It is
>    reading-heavy and should feel **trustworthy and document-like** — like consulting a
>    rulebook, not a casual chatbot.
> 3. **Card Search** — a natural-language search returning a ranked list of real Magic
>    cards. Reading/scanning a list of results.
>
> **Art direction (must follow):**
> - **Dark theme by default**, high contrast, minimal chrome — built for a dim game table
>   and for night play. (A light theme can be a secondary deliverable.)
> - **Mana colors as an accent system, not the whole palette.** Magic's five colors are
>   White, Blue, Black, Red, Green (WUBRG). Use them as **per-player-seat accents** in the
>   Companion (each of the up to 4 players gets a distinct mana-color identity) and as
>   sparing semantic accents elsewhere. The base UI is neutral dark; mana colors punctuate.
> - **Glanceable Companion:** life totals as the dominant element — oversized numerals,
>   readable across a table; obvious +/- affordances; clear commander-damage and counter
>   readouts; comfortable thumb reach.
> - **Authoritative Judge:** a more editorial treatment — a serif or high-quality display
>   face for the answer body is welcome; cited sources (rule numbers, card text) visually
>   distinct and verifiable; calm, confident, not playful.
> - Modern, clean sans for everything else (Card Search, navigation, Companion labels).
>
> **Deliverables:**
> 1. **Color system** — neutral dark base ramp + the five mana accent colors (with
>    accessible on-dark contrast), plus semantic colors (danger/lethal, warning, success).
> 2. **Typography scale** — including the oversized Companion life-number style and the
>    Judge "document" body style.
> 3. **Core components** — buttons, the player-seat life card/tile, the commander-damage
>    matrix, counters, dice roller, chat bubble + cited-source block, a card-result row,
>    and a Quota indicator chip ("N free AI requests left").
> 4. **Key screen mockups (dark):**
>    - Companion — 4-player Commander game (life, commander damage, poison, counters).
>    - Companion — 1v1 game (20 life).
>    - Judge — a question with a streaming, cited answer.
>    - Card Search — query + ranked card results.
>    - Home/navigation tying the three surfaces together.
>
> **Constraints & tone:** glance-readable in low light; large touch targets; works
> one-handed; no clutter. The brand is *manajudge* — "mana" (the five colors) + "judge"
> (authority, rules). Evoke a trusted Magic judge, not a flashy game UI. Avoid using
> Wizards of the Coast's official Magic logos or trademarked card frames; build an
> original identity inspired by the game's color philosophy.

---

### Notes for whoever runs this

- If you want the app to lean Commander-first (our primary case), emphasize the 4-player
  layout and commander-damage matrix in the mockup priorities.
- The five mana colors are a strong, recognizable system — but they fight reading comfort
  if overused; keep them to seat identity + semantic accents, as the prompt says.
- Ask for the design tokens in a form you can drop into a Flutter theme (color/typography
  scales), to shorten the path from mockup to `ThemeData`.
