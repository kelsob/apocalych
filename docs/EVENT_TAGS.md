# Event tags (TagManager + EventManager)

**How selection layers biomes + tags + weather + resources:** see **`docs/EVENT_SELECTION.md`**.

`TagManager.refresh_tags()` runs at the start of every `EventManager.pick_event_for_node()` (and via `update_tags_from_party()` when the party is chosen). `get_all_tags()` merges **derived** tags (party/biome/time/items) with **event outcome** tags from `add_tag` / `remove_tag` (e.g. `warg_ambush_fled` → follow-up events that list that tag in `prereqs.requires_tags`).

**Party gold is not represented as tags.** Use `prereqs.min_gold`, `prereqs.max_gold`, or `prereqs.party_resources` with `"id": "gold"` and comparators (`eq`, `gte`, `lte`, …). Those are evaluated from live `Main.party_gold` whenever an event is picked.

## Computed tag prefixes

| Prefix | Example | Source |
|--------|---------|--------|
| Hero (preset id) | `hero:starter_elf_wizard` | `HeroCharacter.hero_id` when non-empty |
| Race (any in party) | `<human>`, `<halfling>` | `HeroCharacter.race.race_name` (lower case) |
| Race (whole party) | `<all_halfling>` | Same race count == party size |
| Class | `<cleric>`, `<all_wizard>` | `HeroCharacter.class_resource.name` |
| Trait | `trait:natural_hunter` | `HeroCharacter.get_trait_ids()` |
| Item on character | `char_item:iron_luck_charm` | Member `inventory` count > 0 |
| Party bulk stash | `resource:health_potion`, `resource:camping_supplies`, … | `Main.party_resources` count > 0 |
| Union (compat) | `item:health_potion` | Present in **either** stash or any member inventory |
| Biome | `biome:forest` | Current map node biome passed into `pick_event_for_node` |
| Weather | `weather:clear`, `weather:rainy`, `weather:foggy`, `weather:thunderstorms`, … | `WeatherManager` id (events **`set_weather`** only — travel does not roll); see `docs/WEATHER.md` |
| Lunar | `lunar:full`, `lunar:any` | `TimeManager` phase (see `lunar_cycle_length`) |

Race/class use **one** canonical string each: `<name>` and `<all_name>`. Use those in `requires_tags` / `requires_any` (not bare `human` / `cleric`).

## Event outcome tags

Plain strings from `{ "type": "add_tag", "tag": "warg_ambush_fled" }` when a choice resolves. They stay in the pool until `remove_tag` or `clear_event_outcome_tags` / `clear_all_tags`. Follow-ups use the same mechanism: `followup_events.json` merges `trigger_tag` into `prereqs.requires_tags` so those events enter the tag-driven pool like any other tag match.

## Event JSON — `prereqs`

Same as choice `condition`:

- `requires_tags`: array — **all** must be present  
- `requires_any`: array — at least one  
- `forbids_tags`: array — none may be present  
- `min_gold` / `max_gold` — shorthand vs party gold  
- `party_resources`: array of `{ "id": "gold" | bulk id, "eq"|"ne"|"lt"|"lte"|"gt"|"gte": <int> }` — stash + gold (gold uses `party_gold`)  
- `character_items`: same shape, totals **only** from party members’ inventories  
- `variables`, …

Events with **only** structured gates (no `requires_tags` / `requires_any`) still enter the pick pool when `condition_passes` is true — no tag is required to “discover” them.

**Example** — forest node, halfling in party, gold between 50 and 1000:

```json
{
  "biomes": ["forest"],
  "prereqs": {
    "requires_tags": ["<halfling>"],
    "party_resources": [
      { "id": "gold", "gt": 50 },
      { "id": "gold", "lt": 1000 }
    ]
  }
}
```

**Example** — camping supplies only (stash), no tag:

```json
{
  "prereqs": {
    "party_resources": [ { "id": "camping_supplies", "gte": 10 } ]
  }
}
```

## Event JSON — `immediate_effects`

Optional array of effect objects (same **`type`** / fields as a choice’s **`effects`**). Run once in **`EventManager.present_event()`** when the event is prepared — **before** it is appended to the log — so the player sees consequences (e.g. **`set_weather`**, icon + tags) immediately. Choice **`effects`** still run only when that choice is selected.

## Weights

All events in one pool use `weight` (default `1`). Use a **large** value (e.g. `100`) to strongly favor an event when it is eligible. Follow-up entries merged from `followup_events.json` default to `8` if `weight` is omitted.

## Follow-up file

`events/followup_events.json` is **not** loaded by the directory scan. It is merged into the main `events` registry: `trigger_tag` is appended to `prereqs.requires_tags` (merged with existing `prereqs`).

## TimeManager — lunar

Adjust `TimeManager.lunar_cycle_length` (game time units per full cycle). Phases: `new`, `waxing_crescent`, `first_quarter`, `waxing_gibbous`, `full`, `waning_gibbous`, `third_quarter`, `waning_crescent`.

## Debug suite

See **`events/debug_tag_conditions_test.json`** and **`docs/DEBUG_TAG_CONDITIONS.md`** for one event per prereq/tag flavor.
