# Town System – Implementation Plan

This document is the plan for the town system: town-specific arrival events, entry (guard checks / pay / free), and the town screen with configurable services (Inn, Blacksmith, Merchant, Casino, Warmaster). It identifies which existing scripts we touch, what new scripts and events we add, and how they integrate.

---

## 1. High-level flow

1. **Arrival at a node**  
   Travel completes → `Main._on_travel_completed(node)` → `_launch_node_event(node)`.

2. **Town vs non-town**  
   In `Main._launch_node_event()` we branch on `node.is_town`.  
   - **Town:** Pass a town-specific biome/key (e.g. `"town"`) so `EventManager.pick_event_for_node()` only considers town events.  
   - **Non-town:** Keep current behaviour (biome from node, generic/placeholder events).

3. **Town event**  
   One (or more) town events describe entry: e.g. guard asks for gold, free entry, or “have X in party”. Choices can have effects: `pay_gold`, `open_town`, etc. When a choice that means “get in” is taken, we apply those effects then open the town screen.

4. **Town screen**  
   You design the scene (node structure, layout). A script we write will:  
   - Receive the current town (e.g. `MapNode2D` or a small town data object) and which **services** this town offers.  
   - Show/enable only those services (Inn, Blacksmith, Merchant, Casino, Warmaster).  
   - Each service is a stub or minimal implementation at first; we can expand later (e.g. Blacksmith when equipment exists).

5. **Leaving town**  
   Town screen has an “Leave” (or equivalent) action that closes the town screen and returns to the map; no extra event required unless you want one later.

---

## 2. Existing systems we rely on

| System | Where | Use for towns |
|--------|--------|----------------|
| Map / travel | `MapGenerator2D`, `Main` | Towns are nodes with `is_town == true`; travel completion triggers events. |
| Node event launch | `Main._launch_node_event(node)` | We change this to pass a town-specific key when `node.is_town`. |
| Event selection | `EventManager.pick_event_for_node(biome, party, node_state)` | When at a town we pass something like `biome = "town"` so only town events are eligible. |
| Event display / choices | `EventWindow`, `EventChoiceButton` | Town entry is a normal event with choices; no change. |
| Effect application | `EventManager.apply_effects()` | We add new effect types: `pay_gold`, `open_town`. |
| Party / gold | `Main.current_party_members`, `Main.party_gold` | Entry cost and town services (Inn, Warmaster, etc.) use these. |
| Rest | `RestController`, `Main.start_rest()` / `_on_rest_complete()` | Inn can trigger the same rest flow (pay gold then call existing rest). |

No inventory or equipment system exists yet; Blacksmith/Merchant/Warmaster will be stubbed or minimal until those exist.

---

## 3. Scripts to touch (existing)

### 3.1 `scripts/2d/Main.gd`

- **`_launch_node_event(node)`**  
  - If `node.is_town`: call `EventManager.pick_event_for_node("town", party_dict, node_state)` (or a dedicated `pick_town_event_for_node(node, party_dict, node_state)` if you prefer a separate API).  
  - Else: keep current logic (biome from node, existing `pick_event_for_node(biome_name, ...)`).  
  - Ensures town nodes always get a town event (or a fallback town event if we add one).

- **Town screen lifecycle**  
  - Add something like `open_town_screen(town_node_or_data)` and `_on_town_screen_closed()`.  
  - `open_town_screen`: hide map + map UI, show town screen (e.g. `ui_controller.town_screen`), pass town data.  
  - `_on_town_screen_closed`: hide town screen, show map + map UI (same pattern as rest/combat).

- **Optional:** If we add a `pay_gold` effect that deducts from `Main`, Main doesn’t need to “listen” to the event; EventManager will resolve Main and deduct. So no new signal connection for gold. If we ever need to react to “player paid guard” (e.g. achievements), we can add a small callback or signal later.

### 3.2 `scripts/events/EventManager.gd`

- **`pick_event_for_node`**  
  - When `node_state["is_town"]` is true: only consider events with `town_entry: true` **and** biome matching the node’s biome. When not at a town: skip events that have `town_entry: true`. So each biome has its own subset of town entry events (e.g. `town_entry_forest` with `biomes: ["forest"]`, `town_entry: true`).

- **`apply_effects()`**  
  - Add two effect types:  
    - **`pay_gold`**  
      - Params: e.g. `amount` (int).  
      - Resolve Main (same as `start_combat` / `reveal_secrets`), then `main.party_gold = max(0, main.party_gold - amount)`.  
      - Optional: check `main.party_gold >= amount` in a **choice condition** (see Event structure below) so “Pay 10 gold” is only shown when affordable.  
    - **`open_town`**  
      - No params (town = current node from `node_state`).  
      - Resolve Main, close event window if open, then call `main.open_town_screen(main.map_generator.current_party_node)` (or pass `node_state["current_node"]`).  
  - Order of effects in a choice: e.g. `[ { "type": "pay_gold", "amount": 10 }, { "type": "open_town" } ]` so gold is deducted before opening town.

- **Condition for “can afford entry”**  
  - Today `condition_passes` uses `party` and `_build_party_state`; `party` from Main doesn’t include `party_gold`. So we have two options:  
    - **A)** Add `party_gold` into the dict Main passes (e.g. in `_build_party_dict()` or a separate state dict used for conditions) and add a condition type like `min_gold` / `max_gold` in EventManager so “Pay 10 gold” is only available when `party_gold >= 10`.  
    - **B)** Don’t filter by gold in the event; show “Pay 10 gold” always and in `pay_gold` effect clamp to 0 (so they can “pay” even if they have 0).  
  - **Recommendation:** A is better UX: add `party_gold` to the party/state dict and a small condition (e.g. `variables.gold >= 10` or a dedicated `min_gold`) so the choice is hidden when they can’t afford it.

So EventManager will:  
- Optionally add `party_gold` to `_build_party_state` (if we pass it from Main) or Main adds it to `party_dict` and EventManager’s condition code checks it.  
- Implement `pay_gold` and `open_town` in `apply_effects`.

### 3.3 `scripts/2d/MapNode2D.gd` (optional but recommended)

- Add a way to know **which services this town offers**, so the town screen can show only those.  
  - **Option A:** Add `town_services: Array[String]` (e.g. `["inn", "blacksmith"]`) and set it when the node is marked as a town (e.g. in `MapGenerator2D.generate_towns()` or when assigning `is_town`).  
  - **Option B:** A separate resource or data table (e.g. `town_id` on the node and a `TownData` resource with services).  
  - **Recommendation:** Start with Option A on `MapNode2D`: `var town_services: Array = []` (e.g. `["inn", "blacksmith", "merchant"]`). MapGenerator can assign a random subset per town so different towns have different offerings.

### 3.4 `scripts/2d/MapGenerator2D.gd`

- Where you set `candidate_node.is_town = true`, also set `candidate_node.town_services = _pick_town_services()` (or a fixed list for testing).  
- `_pick_town_services()` returns a subset of `["inn", "blacksmith", "merchant", "casino", "warmaster"]` (e.g. random 2–4, or based on region). No scene changes required; this is logic only.

### 3.5 UIController / Main scene

- Add a **town screen** node (you design the scene; we only need a stable node path or reference).  
  - In code we’ll assume something like `ui_controller.town_screen` (or a node you name).  
  - Main shows/hides it and connects a “closed” signal to `_on_town_screen_closed`.  
  - You create the node structure; we write the script that drives it (see “New scripts” below).

---

## 4. New scripts

### 4.1 Town screen controller (e.g. `scripts/town/TownScreen.gd` or `scripts/2d/TownScreen.gd`)

- **Responsibility:**  
  - Receives “current town” data (at minimum: which services are offered).  
  - Shows the town UI (you build the scene); the script references buttons/panels by path (no exported node paths per your rules).  
  - For each service in the list, enable/show the corresponding button or section; hide or disable the rest.  
  - **Inn:** Button “Rest at Inn” → pay gold (e.g. fixed cost or from a small config); deduct gold, then call the same rest flow as the rest button (e.g. Main’s `start_rest()` and mark rested when done). So Inn = pay then rest.  
  - **Blacksmith:** Button “Blacksmith” → for now open a placeholder panel or print “Blacksmith – coming soon” (no equipment system yet).  
  - **Merchant:** Same idea – placeholder until inventory exists.  
  - **Casino:** Placeholder (“Gamble – coming soon”) or a very simple gold-in/gold-out (e.g. pay 5, 50% get 10 back).  
  - **Warmaster:** “Train” → pay gold to grant XP to a chosen party member (or split); call `member.gain_experience(xp)` and deduct gold. Formula can be e.g. 10 gold per 10 XP for now.  
  - **Leave:** Button that emits `town_closed` or `leave_pressed`; Main hides town screen and shows map.

- **No scene building in code:** You create the scene tree; the script only gets nodes (e.g. `$SomePath/InnButton`), sets visibility/enabled, and connects signals.

### 4.2 (Optional) Town data resource

- If you prefer not to store `town_services` on `MapNode2D`, we can add a `TownData.gd` resource with `town_name`, `services: Array`, and optional `inn_cost`, `warmaster_gold_per_xp`, etc. Then the node holds a `TownData` reference. For the first version, node-only `town_services` is enough.

---

## 5. Event: town entry (structure and examples)

- Events live under `events/` as JSON, loaded by EventManager.  
- We need at least **one town entry event** so that when `pick_event_for_node("town", ...)` runs, something is returned.

### 5.1 Event selection for towns

- In `Main._launch_node_event(node)` when `node.is_town`: pass `node_state["is_town"] = true` and keep using the node's **biome** (e.g. `"forest"`, `"plains"`). EventManager then only considers events that have **both** `town_entry: true` **and** a matching biome. So town events are a **subset within each biome** (forest towns get forest town events, plains get plains town events), not a separate "town" biome.

### 5.2 Starter town event: “Guard at the gate”

- **id:** e.g. `town_entry_guard`.  
- **biomes:** `["town"]`.  
- **title:** e.g. “Town gate”.  
- **text:** e.g. “A guard blocks the gate. ‘Entry is 10 gold per party,’ they say.” (or use `{{party.leader_name}}` for interpolation).  
- **choices:**  
  1. **“Pay the fee”** – condition: e.g. `variables.gold >= 10` (once we add gold to party/state). Effects: `pay_gold` 10, `open_town`.  
  2. **“We don’t have the gold”** – condition: e.g. `variables.gold < 10` (or no condition and we show “Leave” only). Effects: none (or just close event).  
  3. **“Let us in – we’re on official business”** – condition: e.g. `requires_tags: ["noble"]` or `requires_any: ["guard", "soldier"]`. Effects: `open_town` only.  
  4. **“Refuse and leave”** – no open_town; just close.

- We need to add `party_gold` (or a variable) to the data passed to EventManager for conditions. E.g. in Main, in `_build_party_dict()`, add `party_dict.variables["gold"] = party_gold` (or EventManager reads a dedicated key). Then in event JSON we can use a condition like `variables: { "gold": { "min": 10 } }` if we add that to `condition_passes`.

### 5.3 Simpler starter (no gold condition)

- One event, two choices:  
  - “Enter (pay 10 gold)” – effects: `pay_gold` 10, `open_town`.  
  - “Leave” – effects: none.  
- No condition on gold; if they have 0, pay_gold still runs (clamp to 0). Later we add the condition so “Pay” is hidden when they can’t afford it.

### 5.4 Event structure summary

- Reuse existing event schema: `id`, `title`, `text`, `biomes`, `choices`.  
- Each choice: `id`, `text`, optional `condition`, `effects`.  
- New effects:  
  - `{ "type": "pay_gold", "amount": 10 }`  
  - `{ "type": "open_town" }` (uses `node_state["current_node"]` in EventManager).  
- Optional: add gold to party/state and a condition (e.g. `variables.gold >= 10`) so “Pay” is only shown when affordable.

---

## 6. Data flow summary

| Step | Actor | Action |
|------|--------|--------|
| 1 | Main | Travel completed → `_launch_node_event(node)`. |
| 2 | Main | If `node.is_town`: call EventManager with `"town"` (or town-specific) so only town events are picked. |
| 3 | EventManager | Returns a town entry event (e.g. guard). |
| 4 | Main | Presents event via existing EventWindow. |
| 5 | Player | Picks “get in” choice (pay / free / tag-based). |
| 6 | EventWindow | Applies effects (pay_gold, open_town) via EventManager. |
| 7 | EventManager | Deducts gold (if any), then calls Main to open town screen with `node_state["current_node"]`. |
| 8 | Main | Hides map + map UI, shows town screen, passes node (or node.town_services). |
| 9 | TownScreen script | Shows only services in `town_services`; Inn/Warmaster use Main’s party and gold; others stubbed. |
| 10 | Player | Clicks “Leave”. Town screen emits closed; Main shows map again. |

---

## 7. Implementation order (suggested)

1. **Event selection for towns**  
   In Main, branch in `_launch_node_event` on `node.is_town` and pass `"town"` (or equivalent) to EventManager.  
   Add one minimal town event JSON with `biomes: ["town"]` and one choice with effect `open_town` (no pay_gold yet) so you can test “arrive → event → get in”.

2. **Effects**  
   In EventManager: implement `open_town` (resolve Main, get current node from node_state, call `main.open_town_screen(node)`).  
   Then implement `pay_gold` and optionally add gold to party/state for conditions.

3. **Main + town screen lifecycle**  
   Main: add `open_town_screen(node)` and `_on_town_screen_closed()`; show/hide map and town screen.  
   You add the town screen node under UIController and hook up its “closed” signal to Main.

4. **Town data on node**  
   MapNode2D: add `town_services: Array`.  
   MapGenerator2D: when setting `is_town`, set `town_services` (e.g. random subset of the five services).

5. **TownScreen script**  
   You create the scene; we write the script that reads `town_services`, shows/hides service buttons, implements Inn (pay + rest), Warmaster (pay gold for XP), and placeholders for Blacksmith/Merchant/Casino.

6. **Starter town event (full)**  
   Add guard event with pay / free / tag-based choices and conditions once gold is in party/state.

7. **Polish**  
   Rest button visibility after leaving town; any extra event variants (friendly town, hostile town, etc.).

---

## 8. Files to create or touch (checklist)

| Item | Action |
|------|--------|
| `scripts/2d/Main.gd` | Touch: town branch in `_launch_node_event`; `open_town_screen`, `_on_town_screen_closed`. |
| `scripts/events/EventManager.gd` | Touch: town event selection (or `"town"` biome); `pay_gold`, `open_town` in `apply_effects`; optional gold in party/state for conditions. |
| `scripts/2d/MapNode2D.gd` | Touch: add `town_services`. |
| `scripts/2d/MapGenerator2D.gd` | Touch: set `town_services` when assigning `is_town`. |
| `scripts/town/TownScreen.gd` (or under `2d`) | **New:** town screen logic, service buttons, Inn/Warmaster/placeholders. |
| `events/town_entry_guard.json` (or similar) | **New:** at least one town entry event with `biomes: ["town"]` and choices with `pay_gold` / `open_town`. |
| Town scene (you design) | **New:** scene with nodes for Leave + one panel/button per service; attach TownScreen script. |
| UIController / Main scene | Touch: add town screen instance and reference (you do scene edit). |

---

## 9. What you design vs what we code

- **You:** Where towns are (already done), node structure and layout of the town screen, which nodes are buttons/panels for Inn/Blacksmith/Merchant/Casino/Warmaster/Leave.  
- **We:** All logic: event selection for towns, `pay_gold`/`open_town` effects, Main’s open/close town flow, TownScreen script that wires your nodes to services and to Main/party/gold/rest.

This keeps the plan consistent with your rules: we don’t create the town UI hierarchy in code; we only write the script that enhances the scene you create and reference nodes by path.
