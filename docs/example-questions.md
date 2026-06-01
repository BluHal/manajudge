# Example questions for manajudge

A collection of real questions a Magic player might ask the AI judge, from the simplest ones to
tournament-grade cases. They serve as inspiration for users, as a manual test bench, and as a base
to expand the evaluation set (`data/eval/eval-set.json`).

The retrieval pipeline is **multilingual**, so you can ask in any language; the rules are always
matched in English. The questions below are in English, but the judge currently **replies in
Italian** (see the system prompt). Questions marked 🃏 name specific cards (they exercise the
Scryfall lookup); those marked 🔗 are meant as **follow-ups** to the previous question (they
exercise session memory and rewriting).

---

## 1. Basic rules (casual player)

- How do you win a game of Magic?
- In what order do the phases of a turn happen?
- What can I do during the main phase?
- What's the difference between an instant and a sorcery?
- Can I play more than one land per turn?
- What happens if I run out of cards in my library?
- How does the opening-hand mulligan work?
- What does it mean for a creature to have "summoning sickness"?
- Can I attack with a creature the same turn I played it?
- How many life points do I have at the start of the game?

## 2. Stack, priority and timing

- How does the stack work and in what order do spells resolve?
- What is priority and when do I get it?
- Can I respond to an opponent's spell with another spell?
- If neither of us does anything, what happens to the objects on the stack?
- 🔗 And what if I wanted to respond before it resolves?
- What happens when two triggered abilities go on the stack at the same time?
- Can I activate an ability while a spell is still on the stack?
- When does the mana pool empty?

## 3. Combat

- How do you declare attackers and blockers?
- Can I block a single attacker with multiple creatures?
- What happens if the blocking creature is removed before damage?
- How is combat damage assigned if I have multiple blockers?
- A creature with trample — how much damage tramples over to the player?
- 🔗 And what if that creature also had deathtouch?
- Do attacking creatures get tapped? Can I avoid it?
- What happens during the end-of-combat step?

## 4. Keyword abilities

- How does flying work and who can block a creature with flying?
- What exactly does deathtouch do?
- How does lifelink work: do I gain life even if the creature is destroyed?
- Does indestructible also protect from lethal damage and from state-based actions?
- 🔗 And does it also protect from effects like "sacrifice a creature"?
- What does prowess do and when does it trigger?
- How does first strike interact with trample?
- Protection from a color: what exactly does it prevent (the 4 things)?

## 5. Specific card interactions 🃏

- 🃏 If I cast Lightning Bolt at a creature with protection from red, what happens?
- 🃏 Can I use Swords to Plowshares on a creature with indestructible? Does it work?
- 🃏 Can Doom Blade target a black creature?
- 🃏 How does Tarmogoyf interact with the cards in both players' graveyards?
- 🃏 If I control Blood Artist and sacrifice multiple creatures at once, how many times does it trigger?
- 🃏 Can Counterspell counter a triggered ability or only spells?
- 🃏 Pacifism on a creature: can it still be tapped for its abilities?
- 🃏 If Snapcaster Mage gives flashback to an instant, what happens to the card after casting it?
- 🃏 Humility and a creature with a +1/+1 counter: how do they combine on the layers?

## 6. Advanced cases (layers, replacement, SBA)

- How is the layer system applied when multiple effects modify characteristics?
- In what order do I apply an effect that sets power/toughness and one that boosts them?
- What are state-based actions and when are they checked?
- What happens if I control two replacement effects applicable to the same event?
- Can a replacement effect apply twice to the same event?
- How does the legend rule work with two identical legendary permanents?
- What happens to an Aura when the permanent it's attached to leaves the battlefield?
- If a creature becomes 0/0 due to an effect, when exactly does it die?
- How do you handle a spell whose targets have all become illegal on resolution?

## 7. Zones, copies and targets

- What does it mean for an object to "change zones" and why does it matter?
- When I copy a spell, who chooses the new targets?
- Does a copy of a creature also copy the +1/+1 counters?
- If a permanent leaves the battlefield and returns, is it the same object or a new one?
- Can I target a creature with hexproof/shroud with an effect that doesn't target it?

## 8. Multiplayer and tournament situations

- How does priority work in a multiplayer game?
- In Commander, how does commander damage work?
- What happens to "until end of turn" effects if a player leaves the game?
- Difference between "conceding" and "losing" a game in a best-of-three match?
- Can I take back an action if I made a mistake? (in a tournament)

## 9. Ambiguous / out-of-coverage questions (to test honesty)

These verify that the judge **admits uncertainty** instead of making things up:

- Does my card work against my opponent's card? *(without specifying which)*
- Can I do this combo? *(without describing it)*
- Who wins in this situation? *(insufficient context)*
- Is this card legal in my format? *(a legality/banlist question, outside the CR)*

---

## Usage notes

- **Follow-ups** (🔗) only work within the same conversation: the judge rewrites the question
  using the context (e.g. *"and what if it also had deathtouch?"* → full question).
- For the 🃏 interactions the judge retrieves the **real oracle text** of the card; if you get the
  name wrong, try writing it out in full or in English.
- Every answer shows the **sources** (CR rule numbers + cards used) and a **confidence badge**: if
  it's "low", treat it with caution and verify the sources.
