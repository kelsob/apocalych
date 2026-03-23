# Event selection — mental model & authoring

This doc ties together **where** an event can fire (map node) and **when** its requirements are satisfied (party, weather, resources, story tags). The code lives mainly in `EventManager.pick_event_for_node()` and `EventManager.condition_passes()`.

---

## 1. Two stages (think: “venue” then “guest list”)

### Stage A — Node / catalog filters (always first)

For each event, these run **before** tag math:

| Field | Effect |
|--------|--------|
| **`biomes`** | If present and non-empty, the current node’s biome **must** be in this list (e.g. `"forest"`). Omit or `[]` = any biome (still subject to other rules). |
| **`town_entry`** | `true` = only on **town** nodes; `false`/omitted = only **wilderness** nodes. |
| **`one_shot`** | If `true`, fires at most once per run (ID tracked after pick). |
| **`weight`** | Must be **> 0** or the event is skipped. |

**Your example:** `"biomes": ["forest"]` means “this event is even *considered* only on forest nodes.” That is independent of tags.

### Stage B — `prereqs` (AND-layers)

If Stage A passes, **`prereqs`** is evaluated with **`condition_passes()`**. Everything you list here is **layered with AND** (all applicable sections must pass):

| Key | Meaning |
|-----|--------|
| **`requires_tags`** | **Every** listed tag must be present in the live tag set (see §3). |
| **`requires_any`** | **At least one** listed tag must be present. |
| **`forbids_tags`** | **None** of these tags may be present (your “tag restrictions” / blocklist). |
| **`min_gold` / `max_gold`** | Gold thresholds (gold is **not** a tag). |
| **`party_resources`** | Stash + gold quantities (`id` + comparators). |
| **`character_items`** | Totals across **equipped/inventory on characters** only. |
| **`variables`** | Story/numeric vars min/max. |

So: **forest node + halfling in party** is exactly:

- `"biomes": ["forest"]` **and**
- `"prereqs": { "requires_tags": ["<halfling>"] }`  
  (Race tags use angle brackets; in data the race is **halfling**, not “hobbit” — use `<halfling>` unless you add a separate tag.)

You can add more layers in the same `prereqs` object, e.g. weather + race + no forbidden outcome tag:

```json
"prereqs": {
  "requires_tags": ["<halfling>", "weather:rainy"],
  "forbids_tags": ["warg_ambush_fled"]
}
```

All of those must pass **together** when the event is eligible.

---

## 2. How events get into the random pool (mechanical detail)

Selection is **not** “pick any event whose biomes match.” After Stage A, an event must also enter the **tag-driven or structured pool**:

1. **`TagManager.refresh_tags()`** runs (party, items, **current biome tag** `biome:*`, **weather** `weather:*`, lunar, outcome tags, etc.).
2. **`_build_party_state()`** copies `TagManager.get_all_tags()` into `party_state.tags` for `condition_passes`.
3. The pool is built from:
   - **Tag-driven events:** `prereqs` contains at least one **positive** tag requirement in `requires_tags` or `requires_any` that is **not** only `biome:*` (see pitfall below). The indexer walks **every current tag** (except tags starting with `biome:` — those are **not** used as the “hook” to pull an event in). If **any** listed tag in your prereqs matches that iterator tag, the event is **candidate**; then **`condition_passes`** must still succeed (full AND of all prereqs).
   - **Structured-only events:** no tag-driven `requires_tags` / `requires_any`, but **`min_gold` / `max_gold` / `party_resources` / `character_items` / `forbids_tags` / `variables`** etc. — they can enter when those pass, without needing a “party tag hook.”

**Why skip `biome:` in the iterator?** Biome is enforced by **`biomes`** / the node. Use those fields for place — don’t duplicate biome in **`requires_tags`**.

### Pitfall — biome-only `prereqs`

If **`requires_tags` / `requires_any` contain only `biome:...` tags** (no race/class/trait/weather/outcome/etc.), the event is **not** treated as tag-driven. If it also has **no** structured gates (gold/resources/forbids/variables), it **will not enter the pool** and will never fire.

**Fix:** Prefer **`biomes": ["forest"]`** for biome scope, and add at least one **non-biome** tag or a structured field to `prereqs` if you need extra conditions.

---

## 3. Where tags come from (one list, many sources)

For **`requires_tags` / `requires_any` / `forbids_tags`**, strings must match **exactly** what `TagManager` emits. Common sources:

| Kind | Example tags |
|------|----------------|
| Party race/class | `<halfling>`, `<all_wizard>` |
| Traits | `trait:natural_hunter` |
| Items / stash | `char_item:…`, `resource:…`, `item:…` (union) |
| Current node | `biome:forest` (refreshed each pick) |
| Current weather | `weather:rainy`, … | From **`WeatherManager`** — changes only via **`set_weather`** (events/debug), **not** when moving nodes |
| Time | `lunar:full`, … |
| Story | Outcome tags from `add_tag` effects |

**`weather:*` in `requires_tags`** layers weather on top of **`biomes`** / other prereqs.

---

## 4. Quick authoring checklist

1. **Place:** Set **`biomes`** / **`town_entry`** if the event shouldn’t happen everywhere.
2. **Layer requirements** in **`prereqs`**: `requires_tags` (ALL), optional `requires_any`, optional `forbids_tags`, optional gold/resources/items/vars.
3. **Ensure the event can enter the pool:** Either a **non-biome** tag in `requires_tags`/`requires_any`, **or** structured-only `prereqs` as described in §2.
4. **Tune frequency** with **`weight`** against other eligible events on that node type.

---

## 5. Related docs

- **`docs/EVENT_TAGS.md`** — full tag prefix table and `prereqs` field list.
- **`docs/WEATHER.md`** — weather IDs for `weather:*` tags.
- **`docs/DEBUG_TAG_CONDITIONS.md`** — debug events for testing prereqs.
