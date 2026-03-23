# Debug tag / prereq test events

**File:** `events/debug_tag_conditions_test.json` (loaded automatically with other `events/*.json`).

Each event title starts with **DEBUG:** and uses **high `weight` (20–40)** so they surface often when you are eligible.

## Quick reference

| Event id | What it tests | How to be eligible |
|----------|---------------|-------------------|
| `debug_cond_min_gold` | `min_gold` | Gold ≥ 100 |
| `debug_cond_max_gold` | `max_gold` | Gold ≤ 5000 |
| `debug_cond_party_resources_gold_gte` | `party_resources` gold | Gold ≥ 100 |
| `debug_cond_party_resources_gold_eq` | `party_resources` gold `eq` | Gold exactly 420 |
| `debug_cond_party_resources_gold_lte` | `party_resources` gold `lte` | Gold ≤ 50 |
| `debug_cond_race_human` | `<human>` | Any Human |
| `debug_cond_class_cleric` | `<cleric>` | Any Cleric |
| `debug_cond_trait_natural_hunter` | `trait:natural_hunter` | Grant trait (e.g. debug rewards) |
| `debug_cond_item_health_potion` | `party_resources` health_potion | Stash count ≥ 1 |
| `debug_cond_lunar_full` | `lunar:full` | Set `TimeManager.game_time` to **3360** (default `lunar_cycle_length` 6720) |
| `debug_cond_weather_cloudy` | `weather:cloudy` | Use `WeatherManager.debug_set_weather("cloudy")` or an event **`set_weather`** — travel does not roll weather |
| `debug_cond_biome_forest` | `biome:forest` | Trigger on a **forest** map node |
| `debug_cond_requires_any` | `requires_any` | Wizard, Rogue, or Hunter in party |
| `debug_cond_forbids_tags` | `forbids_tags` | Almost always (dummy tag never added) |
| `debug_cond_variables` | `variables` | Always (unset var defaults to 0) |
| `debug_cond_all_same_race` | `<all_human>` | **Full** party Human |
| `debug_cond_multi_requires_tags` | Tag + `party_resources` | Any Human **and** gold ≥ 50 |

## Lunar full moon (default settings)

With `lunar_cycle_length = 6720`, phase **4** is `full`. Use:

```text
TimeManager.game_time = 3360
```

(Any value in `[3360, 4199.99…)` works.)

Turn on **Main → debug_event_selection** to read **`event selection:`** one-line logs (chosen id, tag_driven pool size, roll).
