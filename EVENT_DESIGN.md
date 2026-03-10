# Event Design Reference — Apocalych

> This document is the canonical reference for writing events. Refer to it before writing any new event. Every event should be held to the standard described here.

---

## Philosophy

Events are FTL-style: short, punchy, consequential. Most are one interaction deep. A handful chain. Almost all have at least one conditional ("blue") option that rewards smart party composition or preparation. The tone is **dark fantasy with sparse humor** — grounded and serious by default, occasionally wry, never silly. Events should feel authored, not procedural.

**The failure mode to avoid:** Events that describe something interesting but then offer only meaningless choices (advance time, -5 HP) or no real decisions. If writing an event and the choices don't feel meaningfully different, rewrite it.

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
| `biomes` | Array of biome names this event can appear in. |
| `weight` | Integer. Higher = more likely. 10 is average. Rare events: 3–5. Common: 12–15. |
| `one_shot` | `true` = fires once per run, then never again. Use for unique/lore events. |
| `prereqs` | Optional condition block. If the party doesn't meet it, the event never fires. |
| `text` | The main flavor text. See Writing Guidelines below. |
| `choices` | Array of choice objects. See Choice Anatomy below. |
| `combat_outcomes` | Optional. Post-combat follow-up text per outcome. See Combat section. |

---

## Choice Anatomy

```json
{
  "id": "choice_id",
  "text": "Choice text shown to player.",
  "condition": { ...hidden if not met... },
  "requires_item": { "item_id": "health_potion", "count": 1 },
  "effects": [ ...effect objects... ],
  "next_event": "event_id_to_chain"
}
```

| Field | Description |
|---|---|
| `id` | Unique within the event. Snake case. |
| `text` | What the button says. Write it as an action or short phrase. |
| `condition` | If present and NOT met: **choice is hidden entirely**. For blue options. |
| `requires_item` | If present and NOT met: **choice is visible but grayed out/disabled**. For trader offers, item-based options the party can see but can't act on. |
| `effects` | Array of effects applied when chosen. |
| `next_event` | Optional. ID of a follow-up event to fire after this choice resolves. |

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

```json
"requires_tags": ["tag_a", "tag_b"]       // ALL tags must be present
"forbids_tags": ["tag_a"]                  // NONE of these tags can be present
"requires_any": ["tag_a", "tag_b"]         // AT LEAST ONE must be present
"min_gold": 50                             // Party must have ≥ 50 gold
"min_reputation": { "militia": 20 }        // Faction reputation minimum
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

Applied when a choice is selected. Multiple effects can be stacked in the `effects` array.

### Currently Implemented

| Type | Required Fields | Description |
|---|---|---|
| `add_tag` | `tag` | Adds a world/party tag |
| `remove_tag` | `tag` | Removes a tag |
| `give_item` | `item`, `amount` | Adds an item to party inventory |
| `consume_item` | `item_id`, `count` | Removes an item from party inventory |
| `give_gold` | `amount` | Adds gold to party |
| `pay_gold` | `amount` | Removes gold from party |
| `change_stat` | `stat`, `amount` | Modifies party stat (e.g., `"hp"`, negative = damage) |
| `change_reputation` | `faction`, `amount` | Modifies faction rep |
| `set_variable` | `variable`, `value` | Sets a named variable |
| `unlock_event` | `event_id` | Makes a one-shot event fireable |
| `start_combat` | `encounter_id` | Triggers a combat encounter |
| `advance_time` | `amount` | Advances world time |
| `set_rest_state` | `allow_rest` | Sets whether rest is allowed at current node |
| `reveal_secrets` | — | Reveals hidden info at current node |
| `open_town` | — | Opens town services |
| `open_vendor` | — | Opens vendor UI |
| `script_hook` | `hook_id` | Fires a named script hook (rare, for coded logic) |

### Rewarding Resources

The primary reward/penalty economy in events:

- **Gold:** `give_gold` / `pay_gold`
- **Party HP:** `change_stat` with `"stat": "hp"`
- **Health Potions:** `give_item` / `consume_item` with `"item_id": "health_potion"`
- **Camping Supplies:** `give_item` / `consume_item` with `"item_id": "camping_supplies"`
- **Sharpening Stones:** `give_item` / `consume_item` with `"item_id": "sharpening_stone"`
- **Arcane Powder:** `give_item` / `consume_item` with `"item_id": "arcane_powder"`
- **Tags:** `add_tag` for persistent consequences

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
      { "type": "give_item", "item_id": "camping_supplies", "amount": 1 }
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
| `enemies_fled` | Enemies ran away | **No text by default.** Only define if the outcome is narratively significant (e.g., an orc scout escaping is bad; a warg fleeing is irrelevant). |
| `party_fled` | Party fled combat | **No text by default.** Only define in specific cases where it matters. |
| `defeat` | Total party wipe | Handled globally (new game / main menu / quit screen). Do not write defeat text in events. |

### Rules

- **Omit any key you don't need.** If `enemies_fled` has no follow-up, leave it out entirely.
- **Most events will have 0–2 outcome entries.** 0 is fine for fights where the aftermath is covered by the standard reward screen.
- **Victory text should justify the reward it gives.** If you're giving camping supplies, write flavor that makes sense of it — skinning hides, looting a camp, etc.
- **Enemy-fled text exists when fleeing changes the situation** — a scout reports your position, a target escapes, something downstream changes. Capture this with an `add_tag` effect.

### Implementation Note
Post-combat outcome firing is **not yet implemented** in `Main.gd`. The `_on_combat_ended` handler needs to check `combat_outcomes` on the originating event and fire the matching outcome as a follow-up event display. This needs to be built before `combat_outcomes` will work in any JSON.

---

## Event Chaining (next_event)

Any choice can set `"next_event": "event_id"` to fire a follow-up event after effects resolve. This is how multi-depth events work.

### Depth Guidelines

| Depth | Frequency |
|---|---|
| 1 (single event, no chain) | The vast majority |
| 2 (one follow-up) | Occasional — for meaningful branching consequences |
| 3–4 | Hyper rare — only when the narrative genuinely needs it |

Do not chain just to chain. Every additional depth must earn its existence.

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
    { "type": "give_item", "item_id": "forest_map", "amount": 1 }
  ]
}
```

### Post-Combat Loot Text
```json
"combat_outcomes": {
  "victory": {
    "text": "You strip the warg carcasses of their pelts. Not glamorous work, but the hides will burn through a cold night.",
    "effects": [{ "type": "give_item", "item_id": "camping_supplies", "amount": 1 }]
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

## Implementation Status

| Feature | Status |
|---|---|
| `condition` (hide choice) | ✅ Implemented |
| `requires_item` (visible-disabled) | ✅ Implemented |
| Tags, gold, variable, reputation conditions | ✅ Implemented |
| `next_event` chaining | ✅ Implemented |
| `one_shot` events | ✅ Implemented |
| `prereqs` (event-level gating) | ✅ Implemented |
| Post-combat outcomes (`combat_outcomes`) | ❌ Not yet implemented |
| `requires_class` condition | ❌ Not yet implemented |
| `requires_race` / `forbids_race` condition | ❌ Not yet implemented |
| `moon_phase` condition | ❌ Not yet implemented |
| `has_resource` condition | ❌ Not yet implemented |
| Blue Moon lunar phase | ❌ Not yet in WorldClock |
| Flee-locked combat flag | ❌ Not yet implemented |
| Party wipe global screen | ❌ Not yet implemented |
