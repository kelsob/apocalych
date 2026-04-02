# Event Design Reference — Apocalych

> This document is the canonical reference for writing events. Refer to it before writing any new event. Every event should be held to the standard described here.

---

## Philosophy

Events are FTL-style: short, punchy, consequential. Most are one interaction deep. A handful chain. Almost all have at least one conditional ("blue") option that rewards smart party composition or preparation. The tone is **dark fantasy with sparse humor** — grounded and serious by default, occasionally wry, never silly. Events should feel authored, not procedural.

**The failure mode to avoid:** Events that describe something interesting but then offer only meaningless choices (advance time, -5 HP) or no real decisions. If writing an event and the choices don't feel meaningfully different, rewrite it.

> **Direction — recursive events (planning only):** The shipped JSON/runtime below still uses separate **`outcomes`**, **`tier_outcomes`**, and inert **`next_event`**. The **intended** model is a **single recursive “event step”** type (text → optional effects → optional choices → each choice leads to another step). See **Recursive event model — planning (draft)**. **No implementation commitment** until that section is approved and tasks are scheduled.

### Stat-driven challenges (**implemented**)

Choices may declare **`stat_challenge`** (primary stat + four tier outcomes). The runtime picks a default actor (highest stat), shows them on the choice label (with aggregate fail/success odds), and allows **cycling the actor** when `allow_actor_override` is true (wired in `EventChoice` / scene). Resolution uses **`EventStatCheck`** (tiered RNG). Effects on each tier use the **same `effects` pipeline** as ordinary choices; use **`target`: `"stat_actor"`** (or `"actor"`) on `change_stat` / `give_trait` / etc. when the consequence should hit whoever rolled.

See **Stat-driven challenges — JSON (implemented)** below. The roadmap section at the end of this file is **historical**; keep it only for process ideas, not “not implemented” claims.

---

## Event Anatomy (JSON)

```json
{
  "id": "unique_snake_case_id",
  "title": "Short Display Title",
  "biomes": ["forest"],
  "weight": 10,
  "one_shot": true,
  "prereqs": { ...condition block... },
  "text": "Flavor text describing what the party encounters.",
  "choices": [ ...choice objects... ],
  "combat_outcomes": { ...post-combat block... }
}
```

### Top-Level Fields

| Field | Description |
|---|---|
| `id` | Unique string. Never reuse. Snake case. |
| `title` | Short title shown in the event UI. |
| `biomes` | Array of biome names this event can appear in. **Checked before `prereqs`.** If non-empty and the party’s current node is not one of these biomes, the event **never** fires — even if tags/gold/etc. would pass. |
| `weight` | Integer. Higher = more likely. 10 is average. Rare events: 3–5. Common: 12–15. |
| `one_shot` | `true` = fires once per run, then never again. Use for unique/lore events and **all follow-up events gated by outcome tags** (so they don't repeat). |
| `prereqs` | Optional **object** (not `required_tags` at top level). **All** fields you put inside it must pass together (**AND**). See **Event eligibility** below. |
| `text` | The main flavor text. See Writing Guidelines below. |
| `choices` | Array of choice objects. See Choice Anatomy below. |
| `combat_outcomes` | Optional. Post-combat follow-up text per outcome. See Combat section. |

### Event eligibility — **multiple requirements (implemented)**

Gating order in code (`EventManager`):

1. **`biomes`** (if the array is non-empty) — must match the current map node’s biome, plus town vs wilderness (`town_entry`) and `one_shot` / `weight` filters.
2. **`prereqs`** — **every** constraint in the same `prereqs` object must pass at once (**AND**).

Inside **`prereqs`**, you can combine:

- **`requires_tags`**: array — **every** tag must be present (party/race/class as `<halfling>`, `<champion>`, traits, items, **`lunar:full`**, **`weather:rainy`**, story tags, etc.).
- **`requires_any`**: at least one of the listed tags (optional; AND with the rest of `prereqs`).
- **`forbids_tags`**: none of these tags may be present.
- **`min_gold`** / **`max_gold`**, **`party_resources`** (e.g. gold thresholds), **`character_items`**, **`variables`**.

So: “halfling **and** full moon **and** ≥ 500 gold **and** only in forest” is expressed as **`biomes`** + **`prereqs`** with multiple **`requires_tags`** and **`min_gold`**. If the party is in the wrong biome, the event does not run.

```json
"biomes": ["forest"],
"prereqs": {
  "requires_tags": ["<halfling>", "lunar:full"],
  "min_gold": 500
}
```

Lunar phases use tags like **`lunar:full`**, **`lunar:new`**, … (see `TimeManager` / `docs/EVENT_TAGS.md`). Races/classes use angle-bracket tags, e.g. **`<halfling>`**, **`<champion>`**.

---

## Choice Anatomy

```json
{
  "id": "choice_id",
  "text": "Choice text shown to player.",
  "condition": { ...hidden if not met... },
  "requires_item": { "item_id": "health_potion", "count": 1 },
  "effects": [ ...effect objects... ],
  "outcomes": [ ...weighted outcome objects — see below... ],
  "next_event": "event_id_to_chain"
}
```

| Field | Description |
|---|---|
| `id` | Unique within the event. Snake case. |
| `text` | What the button says. Write it as an action or short phrase. |
| `condition` | If present and NOT met: **choice is hidden entirely**. For blue options. |
| `requires_item` | If present and NOT met: **choice is visible but grayed out/disabled**. For trader offers, item-based options the party can see but can't act on. |
| `effects` | Array of effects applied when chosen — **only if `outcomes` is absent or empty** (see probabilistic outcomes). |
| `outcomes` | Optional. If present and non-empty, **weighted random** resolution: one entry is picked; its `effects` and `text` apply. Top-level `effects` on the choice are **not** used in that case. |
| `next_event` | Optional. ID of a follow-up event to fire after this choice resolves. |

**Stat-driven choices:** Choices may declare **`stat_challenge`** (primary stat + four tier outcomes). See **Stat-driven challenges — JSON (implemented)** below. Do not combine with weighted **`outcomes`** on the same choice unless you have confirmed behavior in code.

### Probabilistic outcomes (weighted) — **implemented**

Use `outcomes` when a single button should branch into **one of several** results (50/50, three-way, etc.). Each entry is a dictionary:

| Field | Description |
|---|---|
| `weight` | Relative weight (float/int). Defaults to **1** if omitted. Sum does not need to be 100 — weights are relative (e.g. `50` / `50`, or `1` / `1`, behave the same). |
| `text` | Outcome narrative appended after the choice (shown in the log as follow-up body text). |
| `effects` | Same effect objects as a normal choice `effects` array. |

**Code:** `EventManager.pick_weighted_outcome()` rolls `rng.randf_range(0, total_weight)` and walks entries in order. Wired in `EventChoiceContainer` when the player selects a choice that has a non-empty `outcomes` array.

**Example:** `events/forest_traveler_events.json` — `forest_lost_merchant` → choice `help_right_cart` (weights 50 / 35 / 15).

---

## Choice Types (The Three Colors)

### White Options
Always visible, always selectable. The fallback options every event has. Fight, flee, comply, go around. These are the floor of every event.

### Blue Options — Hidden Conditional
These are the core of good event design. Hidden entirely unless the party meets the condition. Use `"condition": {...}` on the choice.

**When to hide vs. show:** The rule is *knowledge*. If the party would realistically not even think of the option without having the relevant thing, hide it. A ranger sensing an ambush → hidden unless you have a ranger. A trader's specific offer → visible but grayed out (they told you about it). A secret passage through the wall → hidden unless you have a thief.

Most events should have **1–2 blue options**. A handful can have more if it genuinely makes sense.

### Gray Options — Visible but Disabled
Always visible, not selectable if the condition isn't met. Use `requires_item` for these. Use sparingly — primarily for:
- Trader/vendor deals where the party can see all available offers
- Situations where the party *knows* the option exists but literally lacks the resource

---

## Conditions

Conditions are used on `prereqs` (event-level gating), `condition` (per-choice gating), and `requires_item` (visible-but-disabled). Same structure across all three.

### Currently Implemented

These keys go **inside** the event’s **`prereqs`** object (or a choice’s **`condition`** object). **All** keys you use in one block are **AND**ed.

```json
"requires_tags": ["tag_a", "tag_b"]       // ALL tags must be present
"forbids_tags": ["tag_a"]                  // NONE of these tags can be present
"requires_any": ["tag_a", "tag_b"]         // AT LEAST ONE must be present
"min_gold": 50                             // Party must have ≥ 50 gold
"variables": { "var_name": { "min": 1, "max": 10 } }  // Custom variable range
```

For `requires_item` only:
```json
"requires_item": { "item_id": "health_potion", "count": 2 }
```

### Needed — Not Yet Implemented

These conditions need to be added to `EventManager.condition_passes()` before using them in events:

| Condition Key | Description |
|---|---|
| `requires_class: ["ranger"]` | Party has at least one member with this class |
| `requires_race: ["dwarf"]` | Party has at least one member of this race |
| `forbids_race: ["elf"]` | Party has NO members of this race |
| `requires_all_class: ["champion"]` | Every party member has this class |
| `requires_all_race: ["dwarf"]` | Every party member is this race |
| `moon_phase: ["Full Moon", "Blue Moon"]` | Current moon phase matches one of the listed values |
| `has_resource: { "camping_supplies": 1 }` | Party has ≥ N of the named resource |

Moon phase strings map exactly to `WorldClock.LUNAR_DISPLAY_LABELS`:
`"Full Moon"`, `"Waning Gibbous"`, `"Last Quarter"`, `"Waning Crescent"`, `"New Moon"`, `"Waxing Crescent"`, `"First Quarter"`, `"Waxing Gibbous"`

**Special case — Blue Moon:** Certain creatures (werewolves) should only appear on a Blue Moon. This requires a Blue Moon phase to be added to the lunar cycle and a corresponding condition. Do not write werewolf events until this is in place.

---

## Effects

Applied when a choice is resolved (or when the player confirms a **post-combat aftermath** choice — see **Post-Combat Outcomes**). Multiple effects are a single **`effects` array**; order is execution order. One JSON object = one effect; stack objects to combine (e.g. pay gold *and* give an item).

### Naming conventions (readability)

- **Gains** usually start with **`give_`** (`give_gold`, `give_item`, `give_trait`, `give_xp`).
- **Losses** use dedicated verbs: **`pay_gold`** (not `give_gold` with a negative amount), **`consume_item`** (items/resources). **`remove_tag`** mirrors **`add_tag`**.
- **Targeting** shared shapes: many effects use **`target`**: `"all"` \| `"random"` \| party slot `0` / `1` / … \| **`"stat_actor"`** / **`"actor"`** when resolving a **`stat_challenge`** (same slot as the roller). **`member_name`** is supported on **`give_trait`** for narrative-specific grants.

### Optional aliases (backward compatible)

`EventManager.normalize_effect_for_apply()` runs on every effect before **`apply_effects`** and on **preview** paths in **`EventLog`** so labels and trait rows match application. Prefer canonical keys in new JSON.

| Canonical | Also accepted |
|---|---|
| `give_item` / `consume_item` → `item_id` | `item` |
| `give_item` / `consume_item` → `count` (when not using `min_count`/`max_count`) | `amount` |
| Nested `give_item_choice` → `items[]` entries | same `item` / `amount` as above |
| `script_hook` → `hook_name` | `hook_id` |

Do **not** introduce alternate spellings for the same idea in new content unless you need compatibility with older files — these aliases exist to reduce friction, not to multiply styles.

### Implemented effect types (`EventManager.apply_effects`)

All types are dispatched in `scripts/events/EventManager.gd`. Unknown `type` strings log a warning and are skipped.

| Type | Fields (summary) | Behavior |
|---|---|---|
| **`add_tag`** | `tag` (string) **or** `tags` (array) **or** `tag` (array) | Adds world/party tags in `TagManager.event_outcome_tags`. If both `tags` and `tag` exist, **`tags` wins**. |
| **`remove_tag`** | Same as `add_tag` | Removes tags from the outcome layer. |
| **`give_gold`** | `amount` **or** `min_amount` + `max_amount` | Increases `Main.party_gold`. |
| **`pay_gold`** | `amount` | Decreases gold (floored at 0). |
| **`give_item`** | `item_id`, `count` **or** `min_count` + `max_count` | Bulk resources → party stash; equippables/consumables → **queued** for `ItemReward` UI. |
| **`consume_item`** | `item_id`, `count` | Removes from stash and/or inventories until count is met. |
| **`give_item_from_pool`** | `pool` (array of `item_id`), same count fields as `give_item` | Picks **one** random `item_id` from `pool`, then behaves like `give_item`. |
| **`give_item_choice`** | `grant`: `"all"` \| `"one"`; plus `pool`+`pool_draw` **or** `items`: `[{ item_id, count?… }]` | `"all"` grants each resolved entry; `"one"` queues a **pick-one** UI set. |
| **`give_trait`** | `trait_id`, and **`target`** (`"all"` / `"random"` / slot / **`member_name`**) | Grants via `TraitDatabase` + `PartyMember.add_trait`. No **`remove_trait`** effect yet (see **Gaps**). |
| **`give_xp`** | `amount` (unless `force_level_up`), `target` | Party XP / level-up animation hooks. |
| **`heal_party`** | `target`, and `amount` **or** `amount`: `"full"` **or** `percent` | Heals alive members; does not replace combat healing. |
| **`change_stat`** | `stat`, `amount`, optional `target` | **`hp`**: damage/heal on `target` members (including **`stat_actor`**). **`gold`**: adjusts party gold (signed). **Primary attributes** (strength, etc.) are **not** handled here — see **Gaps**. |
| **`set_weather`** | `weather_id` | `WeatherManager.set_weather`; refreshes tags. |
| **`advance_time`** | `amount` | `TimeManager.advance_time_from_event`. |
| **`set_rest_state`** | `allow_rest` | Sets `current_node.can_rest_here` (needs `current_node` in node state). |
| **`reveal_secrets`** | — | Reveals secret paths at current map location (`MapGenerator`). |
| **`start_combat`** | `encounter_id` | Loads `res://resources/encounters/<encounter_id>.tres` and starts combat. |
| **`open_town`** | optional `show_all_services` | Closes event UI, opens town for current node. |
| **`open_vendor`** | optional `item_ids` | Opens vendor screen. |
| **`unlock_event`** | `event_id` | Removes `event_id` from **`seen_one_shot`** so a one-shot can appear again (dev/edge use). |
| **`set_variable`** | `variable`, `value` | **Stub:** prints only; **no persistent storage** yet. |
| **`script_hook`** | **`hook_name`** (not `hook_id`) | Built-in: `open_merchant_ui`, `restart_game`, `go_to_main_menu`, `quit_game`. |
| **`change_reputation`** | *any* | **No reputation system** — **ignored silently** (keeps old JSON loadable). |

### What authoring uses today (from `events/*.json`)

High-frequency: **`add_tag`**, **`change_stat`** (`hp`), **`give_gold`** / **`pay_gold`**, **`give_item`**, **`advance_time`**, **`reveal_secrets`**, **`start_combat`**, **`set_rest_state`**, **`change_reputation`** (flavor-only). Less common in world JSON, exercised in **`debug_rewards_test.json`**: **`give_item_from_pool`**, **`give_item_choice`**, **`give_xp`**, **`heal_party`**, **`give_trait`**, **`set_weather`**. **`stat_challenge`** tiers in **`forest_environmental_events.json`** combine **`change_stat`** + **`add_tag`** + **`give_gold`**.

### Gaps and unification ideas

| Area | Current state | Ideas |
|---|---|---|
| **Trait loss** | Only **`give_trait`** exists. | Add **`remove_trait`** (same `target` / `member_name` shapes as `give_trait`) if stories need cures/curses lifted. |
| **Primary stats** | Not event-tunable via `change_stat`. | Either extend **`change_stat`** for `strength`…`luck` **or** a dedicated **`modify_primary_stat`** with caps and UI feedback. |
| **Variables** | **`set_variable`** is a stub. | Back with a real run/state store and document keys (or keep using **tags** for booleans). |
| **Reputation** | Ignored. | Implement a faction map **or** delete from JSON and use **tags** only (`militia_friendly`) for consistency. |
| **Gold symmetry** | `give_gold` vs `pay_gold` is clear. | Prefer **`change_stat` `"stat":"gold"`** only for odd cases; keep pay/give for readability in data. |
| **Item symmetry** | `give_item` vs `consume_item`. | Already parallel; **`give_item_choice`** covers “pick one reward.” |
| **Hooks** | **`hook_name`** in code; older docs said `hook_id`. | Standardize on **`hook_name`** everywhere. |
| **`unlock_event`** | Clears one-shot memory. | Document when to use vs **`one_shot: false`** on the event definition. |

### Rewarding resources (authoring cheat sheet)

- **Gold:** `give_gold` / `pay_gold` (or `change_stat` `gold` for signed deltas if you prefer one effect).
- **HP:** `change_stat` `hp` with negative/positive `amount`; **`target`** for who gets hit/healed.
- **Items:** `give_item` / `consume_item` / pool / choice variants as above.
- **Tags:** `add_tag` / `remove_tag` — use **Unique Outcome Tags** for story keys (`event_title_specific_ending`).
- **Traits:** `give_trait` only until **`remove_trait`** exists.

---

## Combat in Events

### Starting Combat

Any choice can start a combat with `{ "type": "start_combat", "encounter_id": "path/to/encounter" }`. The path matches the encounter resource path under `resources/encounters/`.

### Flee-Locked Encounters

Set `"flee_locked": true` on the encounter resource itself, not in the event JSON. Note this in the event's design comment so writers know which combats can't be fled.

### Forced Combat Events

Events where combat is unavoidable — no non-combat choice exists. These should be **very rare**. Almost every event should have at least one non-combat path, even if it's blue-gated.

---

## Post-Combat Outcomes

When a choice triggers `start_combat`, the `combat_outcomes` block on the parent event defines what follow-up text (and effects) fires depending on how combat ended.

### Structure

```json
"combat_outcomes": {
  "victory": {
    "text": "Post-combat flavor text shown after winning.",
    "effects": [
      { "type": "give_item", "item_id": "camping_supplies", "count": 1 }
    ]
  },
  "enemies_fled": {
    "text": "Text shown if enemies fled. Only include if it matters.",
    "effects": []
  },
  "party_fled": null,
  "defeat": null
}
```

### Outcome Keys

| Key | When it fires | Default |
|---|---|---|
| `victory` | All enemies dead | No text (silent reward from encounter itself) |
| `enemies_fled` | Enemies ran away | **Not wired in `Main` yet** — `_on_combat_ended` only maps **`victory`** / **`party_fled`** / **`defeat`**. Do not rely on this block until combat end-state reports a distinct “enemies fled” and Main selects `outcome_key = "enemies_fled"`. |
| `party_fled` | Party fled combat | **No text by default.** Only define in specific cases where it matters. |
| `defeat` | Total party wipe | Handled globally (new game / main menu / quit screen). Do not write defeat text in events. |

### Unique Outcome Tags

**Every unique event ending should give the party exactly one outcome tag.** Use these to drive conditional content later (e.g. "the wargs fled — they might come back" only if the party has that outcome).

**Format:** `event_title_specific_ending` in snake_case, derived from the event's narrative identity and the resolution. Examples for a warg ambush event:

| Outcome | Tag |
|---------|-----|
| Party wins, finds collar | `warg_ambush_collar_found` |
| Party fled | `warg_ambush_fled` |
| Enemies fled | `warg_ambush_wargs_fled` |

Apply this to **both** choice-only events (one tag per choice that ends the event) and **combat_outcomes** (one tag per outcome key you define). Do not reuse the same tag for different resolutions (e.g. the collar tag only on victory, not on party_fled).

### Follow-up events gated by outcome tags (non-repeatable)

When an outcome tag is used in **prereqs** to gate a *follow-up* event (e.g. `warg_ambush_fled` triggers "the wargs return" later), that follow-up must **only happen once**. Otherwise the same consequence would fire every time the party hits a node that matches — e.g. "wargs come back" would recur every forest node.

**Rule:** Events that exist solely as the consequence of an outcome tag (e.g. "wargs return after you fled") are **not repeatable** by default. They fire once, then must not trigger again.

**Mechanism:** Set `"one_shot": true` on the follow-up event. Once it has fired, it is removed from the pool for the rest of the run, so the outcome tag does not keep granting the same follow-up.

**Example:** Party flees warg ambush → gets `warg_ambush_fled`. A later event "Wargs again" has `prereqs: { "requires_any": ["warg_ambush_fled"] }`. That later event must have `one_shot: true` so "Wargs again" happens at most once, even though the party keeps the tag.

A future **`repeatable`** property (e.g. on the event or on the tag-grant) could make this explicit in data; until then, **one_shot on the follow-up event** is the way to enforce "this outcome-tag consequence happens only once."

### Follow-up events: separate file and format

**Definition:** A follow-up event is a full event that only becomes eligible when the party has a **specific outcome tag** from a prior event (e.g. `warg_ambush_fled`). It is the narrative consequence of that outcome.

**Storage:** Follow-up events live in **`events/followup_events.json`**. That file is **not** scanned by the bulk events directory loader (to avoid double-loading). EventManager merges each entry into the **same** `events` registry used for the world pool: **`trigger_tag` is converted into `prereqs.requires_tags`** (merged with any existing `prereqs`). Selection is **one weighted pool** with all other events; use a high `weight` (e.g. `100`) to make a follow-up fire almost always when eligible.

**Field:** **`trigger_tag`** (string) is required for the old convention; it becomes a required tag alongside any `prereqs` you already defined. If `weight` is omitted, merged follow-ups default to **8** (slightly above generic events).

**Example:** An event with `"trigger_tag": "warg_ambush_fled"` and `"one_shot": true` competes on weight with other eligible events; tune `weight` so it surfaces as often as you want.

**Contextual tags (race, traits, items, biome, lunar, gold):** See **`docs/EVENT_TAGS.md`**.

### Rules

- **Omit any key you don't need.** If `enemies_fled` has no follow-up, leave it out entirely.
- **Most events will have 0–2 outcome entries.** 0 is fine for fights where the aftermath is covered by the standard reward screen.
- **Victory text should justify the reward it gives.** If you're giving camping supplies, write flavor that makes sense of it — skinning hides, looting a camp, etc.
- **Enemy-fled text exists when fleeing changes the situation** — a scout reports your position, a target escapes, something downstream changes. Capture this with an `add_tag` effect (and use the unique outcome tag format above).

### Implementation note (**implemented**)

When a choice runs **`start_combat`**, the parent event’s **`combat_outcomes`** is copied to **`EventManager.pending_combat_outcomes`** (`EventLog` / `EventWindow`). After combat, **`Main._on_combat_ended`** picks **`victory`** / **`party_fled`** / **`defeat`** and stores the matching block. **`Main._show_combat_outcome`** builds a synthetic **`_combat_outcome`** event whose single **Continue** choice carries that block’s **`effects`**. Those effects run when the player confirms — same pipeline as normal choices (including **`give_item`** → `ItemReward` when applicable). If both **`text`** and combat **`rewards`** are empty, the aftermath panel is skipped.

---

## Event Chaining (`next_event`) — **current runtime**

The **`next_event`** field on a choice is **present in JSON** but **not honored** by `EventLog` / `EventWindow` (no follow-up load by id). Multi-step stories today use **tags**, **follow-up pools**, **weighted `outcomes`**, or **nested content in a future schema**.

**Intended replacement:** **Recursive event model — planning (draft)** — nested steps in one tree, no separate “outcome type.”

### Depth guidelines (narrative — still applies to nested steps)

| Depth | Frequency |
|---|---|
| 1 (single beat, no branch) | The vast majority |
| 2–3 (meaningful branches) | Occasional |
| Deep trees | Rare — only when the narrative earns it |

Do not branch just to branch. Every additional step must earn its existence.

---

## Writing Guidelines

### Tone
Dark fantasy. Grounded. The world is post-apocalyptic and grim, with an underlying weirdness to it. Humor exists but it's dry and incidental — never the main point. Write as if you're narrating a tabletop session, not a comedy sketch.

### Length
- **Minimum:** 1 long sentence or 2 short ones. Most simple events live here.
- **Standard:** 2–4 sentences. The default.
- **Expanded:** A short paragraph. Used for encounters that have a genuine little story to tell.
- **No hard maximums**, but if you're writing past a paragraph, ask whether it's earning it.

### Choice Text
- Write choices as **actions**, not descriptions. "Pay the toll" not "You could pay the toll."
- Gold costs go in parentheses: "Pay the toll (15 gold)"
- Blue options that are class/race-gated don't need to explain the gate in the text. The color communicates it. Example: "Scout ahead silently" not "Scout ahead silently [Ranger]."

### What Makes a Good Event
1. **A real decision exists.** Not just "good choice vs. obviously bad choice." Risk/reward tradeoffs should be genuine.
2. **At least one blue option** that rewards a specific party composition or preparation.
3. **Consequences feel connected** to the fiction — effects make sense given the choice.
4. **The text does work.** It establishes atmosphere, character, or situation quickly.

### What to Avoid
- Events where every choice leads to the same outcome with minor numerical differences.
- Choices that are just "do nothing and lose 5 HP."
- Overcrowded choice lists. 3–4 is plenty for most events. 5+ requires real justification.
- Explaining the lore in event text. Show the situation, let players infer.

---

## Quick Reference: Common Patterns

### The Ambush (forced encounter with a ranger out)
```json
{
  "choices": [
    {
      "id": "fight_ambush",
      "text": "Fight through it",
      "effects": [{ "type": "start_combat", "encounter_id": "..." }]
    },
    {
      "id": "ranger_sense",
      "text": "Slip off the path before they spring it",
      "condition": { "requires_class": ["ranger"] },
      "effects": [{ "type": "advance_time", "amount": 1 }]
    }
  ]
}
```

### The Trader Offer (visible-but-disabled)
```json
{
  "id": "buy_map",
  "text": "Buy the forest map (30 gold)",
  "requires_item": { "item_id": "gold", "count": 30 },
  "effects": [
    { "type": "pay_gold", "amount": 30 },
    { "type": "give_item", "item_id": "forest_map", "count": 1 }
  ]
}
```

### Post-Combat Loot Text
```json
"combat_outcomes": {
  "victory": {
    "text": "You strip the warg carcasses of their pelts. Not glamorous work, but the hides will burn through a cold night.",
    "effects": [{ "type": "give_item", "item_id": "camping_supplies", "count": 1 }]
  }
}
```

### Moon Phase Gate
```json
{
  "prereqs": { "moon_phase": ["Full Moon"] }
}
```

---

## Recursive event model — planning (draft)

> **Status:** Design and migration plan only. **Do not treat this as implemented** in code or JSON until an explicit implementation pass lands. Existing events continue to use **Event Anatomy** and **Choice Anatomy** above.

### Goal

- **One conceptual type** for “what happens next” after the player acts: call it an **event step** (name TBD). It is **the same shape** whether it is the root of a map event or the result of picking a choice.
- Each step has:
  - **`text`** (optional) — body copy for this beat.
  - **`effects`** (optional) — same effect objects as today.
  - **`choices`** (optional) — list of **choices**; each choice leads to **another nested event step** (not a separate “outcome” schema).
- **Order of operations (decided):** Per-effect **timing** (see **Decisions**): (1) before that step’s text / on step enter, (2) after text, before choices, (3) **only when the player finishes the event** — e.g. **Continue** and the **event window has closed** (third bucket). **Continue** always means **end this event segment and return to the map** — never “go back” to a previous choice.
- If **`choices`** is absent or empty, the UI shows a **default Continue** (same as today’s fallback) and the flow resolves upward (end this branch / end event).
- **Infinite depth in one file** is allowed by recursion; file size is an authoring concern, not a schema blocker.

### Why separate files are optional, not required

- Splitting across files (`next_event` by id) was a workaround for **non-recursive** data and for **unimplemented** chaining. Under the recursive model, **one authored tree** can live in one JSON object; splitting remains optional for very large stories or shared sub-steps.

### Proposed shape (sketch — not final)

Top-level **map event** keeps registry fields (`id`, `title`, `biomes`, `weight`, `one_shot`, `prereqs`, `combat_outcomes`, …). The narrative body becomes a **step** (exact field name TBD, e.g. **`step`**, **`root`**, or flatten `text`/`choices` at top level with same meaning as nested).

**Choice object (conceptual):**

- Identity / UI: `id`, `text`, `condition`, `requires_item`, **`stat_challenge`** (if we keep it as a choice modifier).
- **Resolution:** instead of parallel **`effects`** + **`outcomes`** arrays, each choice points to **one nested step** always. **Canonical key for implementers:** use a **single** name (`then` is the default pick — simplest, one pattern). Value shape: `{ "text": "...", "effects": [...], "choices": [...] }`. No effects-only shortcuts on the choice row. A “simple” leaf is still a nested block: **only text** (no effects, no choices), or **no choices** so the UI shows Continue — simplicity comes from empty fields, not from a different object type.

Weighted random (today’s **`outcomes`**) uses **one weighted list in data** (decided): e.g. several `{ "weight": <n>, "step": { ... } }` entries. **If there is only one branch,** there is nothing to roll — use that step. **If there are two or more,** pick one at random using the weights, then show that step like any other beat.

**Stat challenge (today’s `tier_outcomes`):** each tier should be **the same step type** as anywhere else (`text`, `effects`, `choices`). Resolution picks **one** tier, then the UI treats that value like any other nested step (no special-case “outcome” object).

### What goes away or changes

| Current | Under recursive model |
|---|---|
| Choice `effects` only when no `outcomes` | Effects live on **steps** only; each choice points to a **nested step**. Order per step: **text → effects → choices** (with per-effect timing — see **Decisions**). |
| `outcomes` array with `weight` / `text` / `effects` | Replaced by **one weighted list of nested steps** (roll, then show the chosen step). |
| `next_event` string | **Removed** as the primary pattern; optional **`ref`** / **`include`** later if the same subtree is reused without copy-paste. |
| `tier_outcomes.{tier}` as a different shape from a “normal” beat | Same **step** shape per tier. |

### Code areas (for a future implementation pass — not now)

- **`EventChoiceContainer` / `EventChoice`:** Resolve a choice to a **nested step** dict; no separate `outcomes` / stat tier dict shapes in the long run (stat roll picks which step to navigate to).
- **`EventLog`:** Already appends title/body/choice rows into one scroll; nested beats should **continue that pattern** — new nodes below the old, ongoing story — **not** a separate screen system. Expect **targeted** wiring for recursive steps, not a full rewrite of the log UI.
- **`EventManager`:** `present_event` / filtering may need to operate on the root only; nested steps might not re-run world **`prereqs`**. **`apply_effects`** stays one pipeline; may run once per entered step.
- **Combat / `combat_outcomes`:** Likely remain a **special top-level** block (combat is not a normal step), but each key’s payload could adopt the **same step shape** for text/effects/choices.

### Migration strategy (high level)

1. Optional **`event_schema`** (or similar) on files **only if** the loader needs it during work.
2. Implement **recursive navigation** + **one** authoring format in code; add tests with tiny fixtures.
3. **Migrate all** event JSON to the new shape (tool and/or manual): `outcomes` → weighted step lists; `tier_outcomes` → full step objects per tier; strip `next_event`; then remove legacy loaders/paths.

### Decisions (locked in)

1. **What happens first on each step?** **Show the text → then run the effects → then show the buttons.** (So the player reads the beat, then consequences fire, then they choose.)

2. **Nested block always.**  
   Every choice leads to **one nested step** (`text` / `effects` / `choices` — same shape everywhere). There is no separate “effects-only on the button” shortcut. Simplicity is: **no further choices** (empty or omitted `choices` → default Continue), and/or **no effects** (nested block is just **text**, which is minimal).

3. **Weighted random branches (option A).**  
   One weighted list of nested steps in the data. **If only one branch exists,** no random roll — use that step. **If two or more,** roll once by weights, then show the chosen step.

4. **Stat checks.**  
   The roll determines **which nested step** to run; each tier is **`tier_outcomes` → full step shape** (same as everywhere else).

5. **Continue.**  
   **Continue** ends the **current event segment** and returns the player to the map (or closes the event flow). It does **not** mean “go back” or “undo” a choice.

6. **Event log presentation.**  
   **Keep current behavior:** one scroll, **append** new nodes; **no** full EventLog rewrite. **Titles:** always **optional** at any level. If a **nested** step has a **`title`**, show it; **most** nested beats will not — root events usually carry the title.

7. **When do individual effects run? — three buckets (per effect, field TBD).**  
   - **Before text** (including **the moment the map event starts** for the root, and **when any nested step is entered** before its body — same idea for **every** step).  
   - **After text** (default for “normal” consequences before choices).  
   - **Only on Continue / when the event window has closed** — effects that must run **after** the player has dismissed the event UI (third bucket; **required** for some flows).  

8. **Combat** — **Minimal change** unless something must align with the recursive model; otherwise **defer** big rewrites.

9. **Item / trait reward queues** — **Reuse** the existing pipeline (apply effects → drain queues → show reward UI) per step as needed.

10. **Migration** — **Migrate all** event JSON to the new format; **no** long-term dual-format support.

11. **Optional `event_schema` version field** — Add **only if** implementers need it for the loader.

12. **IDs** — Root event **`id`** as today; **optional `id` on nested steps** for debugging and identification (recommended).

### Open questions (minor)

- **Huge single files** — No policy required until authoring pain; optional **`include` / ref`** later.

### Plain-language note: “the engine always rolls?”

**No.** Randomness only happens when the data **lists more than one** weighted branch. One branch → no die roll, just that step.

---

## Recursive events — implementation checklist

Use this as the live task list until the migration is finished.

| # | Task | Status |
|---|------|--------|
| 1 | **`EventManager`:** `timing` on effects (`before_text`, `after_text`, `on_event_close`); split/apply order; queue + **`drain_effects_on_event_close()`** | ✅ |
| 2 | **`EventChoiceContainer`:** resolve **`then`**, **`weighted_branches`** (single branch = no roll); extend **`choice_resolved`** with **`next_step`** | ✅ |
| 3 | **`EventLog`:** nested **`_run_nested_event_chain`** / **`_present_single_nested_step`**, **`_nested_choice_resume`** routing; append title/body/choices per step | ✅ |
| 4 | **`EventLog`:** call **`drain_effects_on_event_close()`** whenever the event session ends (**`event_closed`**) | ✅ |
| 5 | **Migrate all `events/*.json`** to nested steps + remove legacy `outcomes` / flat-only paths once loader is strict | ⬜ |
| 6 | **Stat / combat:** map **`tier_outcomes`** → full steps; **`combat_outcomes`** payloads → step shape (if needed) | ⬜ |
| 7 | **Docs:** example JSON for **`then`** + **`weighted_branches`** + **`timing`** | ⬜ |

**Progress:** rows 1–4 implemented; JSON migration (5–6) and docs (7) follow when the runtime is exercised. **Playtest event:** `events/debug_recursive_model_test.json` (`id`: **`debug_recursive_model_test`**) — set **Main** `event_debug_force` and `event_debug_id` to that id to force it on the next eligible event pick.

---

## Implementation Status

| Feature | Status |
|---|---|
| `condition` (hide choice) | ✅ Implemented |
| `requires_item` (visible-disabled) | ✅ Implemented |
| Tags, gold, variable conditions | ✅ Implemented (`variables` prereq — storage for `set_variable` effect still stub) |
| `next_event` chaining | ❌ **Not implemented** in `EventLog` / runtime (field ignored). Replaced long-term by **Recursive event model — planning** unless explicitly implemented earlier. |
| `one_shot` events | ✅ Implemented |
| `prereqs` (event-level gating) | ✅ Implemented |
| Post-combat outcomes (`combat_outcomes`) | ✅ Implemented (`Main._show_combat_outcome` + effects on Continue) |
| Follow-up events (`followup_events.json` → merged pool, `trigger_tag`) | ✅ Implemented |
| TagManager computed tags (trait/item/biome/lunar/gold) | ✅ Implemented |
| `requires_class` condition | ❌ Not implemented (use `<class>` tags in `requires_tags`) |
| `requires_race` / `forbids_race` condition | ❌ Not implemented (use `<race>` tags / `forbids_tags`) |
| `moon_phase` string condition | ⚠️ Prefer **`lunar:*`** tags in `requires_tags` (see `docs/EVENT_TAGS.md`) |
| `has_resource` condition | ❌ Not implemented |
| Blue Moon lunar phase | ❌ Not yet in WorldClock |
| Flee-locked combat flag | ❌ Not on encounter/event JSON (note: may live on encounter resource — verify when adding) |
| Party wipe / game-over screen | ✅ Implemented (`script_hook` choices) |
| Stat-driven choices (`stat_challenge`, tiered RNG, actor display) | ✅ Implemented (`EventStatCheck`, `EventChoice`) |
| Primary stats in tier resolution | ✅ `EventStatCheck` + `get_final_stats()` |
| `remove_trait` / primary-stat `change_stat` / real `set_variable` | ❌ See **Gaps and unification ideas** |
| `change_reputation` | ⚠️ Parsed, **no gameplay** |

---

## Stat-driven challenges — JSON (**implemented**)

Declare **`stat_challenge`** on a choice with **`primary_stat`**, optional **`allow_actor_override`**, and **`tier_outcomes`** for **`crit_fail`**, **`fail`**, **`success`**, **`crit_success`**. Each tier has **`text`** and **`effects`** (same effect types as any choice). For consequences on whoever rolled, set **`"target": "stat_actor"`** (alias **`"actor"`**) on `change_stat`, `give_trait`, etc.

```json
{
  "id": "force_the_door",
  "text": "Force the rusted door",
  "stat_challenge": {
    "primary_stat": "strength",
    "allow_actor_override": true,
    "tier_outcomes": {
      "crit_fail": { "text": "...", "effects": [{ "type": "change_stat", "stat": "hp", "amount": -8, "target": "stat_actor" }] },
      "fail": { "text": "...", "effects": [] },
      "success": { "text": "...", "effects": [{ "type": "add_tag", "tag": "some_tag" }] },
      "crit_success": { "text": "...", "effects": [] }
    }
  }
}
```

**Coexistence:** A choice should not mix **`stat_challenge`** with weighted **`outcomes`** on the same button unless you have verified UI resolution order — pick one resolution style per choice unless code explicitly supports both.

---

## Implementation plan: stat-driven events (historical)

> **Largely superseded** by `EventStatCheck` + `stat_challenge`. Kept as a checklist for polish (telemetry, extra modifiers, docs).

### Phase 1 — Resolution core

1. **Define a pure function** (e.g. on `EventManager` or a small helper) that takes: `primary_stat` key, **acting member’s** final stat value (`get_final_stats()[stat]`), optional **modifiers** (traits, party tags, difficulty), and an RNG stream. Returns one of **`crit_fail` | `fail` | `success` | `crit_success`** using a documented curve (e.g. shift probabilities toward success as stat increases).
2. **Map tier → effects** using the same effect pipeline as existing choices, but with **context** about `acting_member_id` / index for targeting.
3. **Unit-test** the curve: at low vs high stat, distribution of tiers matches expectations (Monte Carlo or table-driven tests).

### Phase 2 — Actor selection

1. **Default actor:** For a given `primary_stat`, pick the party member with the **highest** value in that stat (tie-break: deterministic order, e.g. slot 0, 1, 2).
2. **Expose in event context** for text interpolation: e.g. `{{event.actor_name}}`, `{{event.actor_stat_strength}}`, so presented event body can mention who is acting.
3. **Optional modifiers:** If design calls for it, apply **party-wide** bonuses (e.g. “if any dwarf, +1 effective tier”) as inputs to the probability shift, not only raw stat.

### Phase 3 — UI / UX

1. **Choice label:** Show the **action** plus **inline actor** — e.g. “Force the door — **Eldra** (Str)” or a second line with the chosen character’s name and relevant stat.
2. **Override control:** If `allow_actor_override` is true, a compact control (dropdown, cycle, or “tap to change”) lets the player pick another **eligible** member. Recompute displayed stat and **implicit** risk before confirm.
3. **Result text:** After resolution, show the tier’s `text` and clearly attribute **who** took the consequence if the effect is actor-scoped.

### Phase 4 — Data and effects

1. **Extend effect application** so `change_stat` / damage / `give_trait`-style hooks can target **`actor`** vs **`party`** (schema TBD).
2. **Pilot events:** Convert 1–2 existing events from plain `outcomes` or fixed `effects` to `stat_challenge` to validate the pipeline.
3. **Document** the final JSON schema in this file and add a row to **Implementation Status**.

### Phase 5 — Polish

1. **Telemetry / debug:** Log tier + stat + actor for balance tuning.
2. **Authoring guidelines:** “When to use stat challenge vs weighted `outcomes` vs deterministic `effects`.”
3. **Replayability:** Ensure **crit_fail** and **fail** still grant tags or narrative hooks that matter later, per the design philosophy above.

