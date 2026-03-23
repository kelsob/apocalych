# Weather system

## Autoload

**`WeatherManager`** (`scripts/autoloads/WeatherManager.gd`) — registered in **Project → Autoload** as `WeatherManager`.

**Debug:** turn off **`debug_log_weather`** on the autoload (or set it `false` in `_ready`) to stop **`WEATHER …`** lines from `WeatherManager`, **`weather_ui.gd`**, and **`Main._on_party_moved_to_node`**.

## When weather changes

- **Travel / entering a map node:** **does not** change weather. **`Main._on_party_moved_to_node`** only calls **`WeatherManager.sync_biome_from_node(node)`** so **`biome_key`** in snapshots stays correct; **`weather:<id>`** is unchanged.
- **Initial session:** after tables load, weather is set once to **`clear`** (`game_start`).
- **Events / scripts:** effect **`set_weather`** or **`WeatherManager.set_weather` / `debug_set_weather`** — the **only** way to change weather during play (for now).

## Data

| File | Purpose |
|------|---------|
| `data/weather/weather_types.json` | Eleven types: clear, rainy, cloudy, foggy, windy, thunderstorms, hail, snow, ashen rain, sea mist, heat wave. |
| `data/weather/biome_weather.json` | Per-biome weighted tables — **not used** while travel does not roll weather; kept for a future system. |

## TagManager + travel

**`Main._on_party_moved_to_node`** calls **`sync_biome_from_node`**, then **`_refresh_tag_manager_tags()`** so **`biome:*`** and **`weather:*`** in `TagManager` match the current node and **current** weather id.

## UI panel

Connect to **`WeatherManager.weather_changed(snapshot)`** and/or poll **`get_weather_snapshot()`**:

- `id`, `display_name`, `icon`, `biome_key`, `combat_effect_ids`, `effects_summary`

## Events

Use **`prereqs.requires_tags`** / **`requires_any`** with **`weather:cloudy`**, **`weather:foggy`**, etc.

**Change weather from an event** — same effect type as choices, but usually on **`immediate_effects`** so the UI updates as soon as the event is shown (not when **Continue** is pressed):

```json
"immediate_effects": [
  { "type": "set_weather", "weather_id": "rainy" }
]
```

You can still put **`set_weather`** on a choice’s **`effects`** if you want it only after the player picks that option.

`weather_id` must exist in **`weather_types.json`**. This calls **`WeatherManager.set_weather`**, emits **`weather_changed`**, and **`EventManager`** refreshes **`TagManager`**. Weather **stays** until another **`set_weather`** (or debug), **not** when moving nodes.

Placeholder: **`placeholder_force_rainy_weather`** in **`events/placeholder_force_rainy_weather.json`** (requires **`weather:clear`**, applies **rainy** on present via **`immediate_effects`**).

Example debug event: **`debug_cond_weather_cloudy`** in `events/debug_tag_conditions_test.json` — use **`debug_set_weather("cloudy")`** or an event with **`set_weather`**, since travel no longer rolls cloudy.

## Combat (stub)

- **`WeatherManager.get_active_combat_weather_modifiers()`** → `[]` until you implement modifiers.
- **`CombatController.start_combat_from_encounter`** calls **`_pull_weather_combat_modifiers()`** — when non-empty, apply there.

## Debug

**`WeatherManager.set_weather("foggy")`** or **`debug_set_weather("foggy")`** sets weather directly.
