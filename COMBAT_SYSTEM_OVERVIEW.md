# Combat System Overview

**Aligned with:** `COMBAT_DESIGN.md` (design authority, roadmap section 14 / next steps section 18).  
**Last synced:** 2026-04-07 — hero **slot-only** loadout, starter weapons/basics resources, weapon-granted basics in combat.

---

## What's Been Built

Here's what exists in the codebase (architecture + data hooks):

### Core Combat Scripts (COMPLETE)

1. **Resource Definitions** (`scripts/combat/resources/`)
   - `Ability.gd` - Defines combat abilities with costs, cast times, targeting, and effects
   - `AbilityEffect.gd` - Individual effects (damage, heal, status, interrupt, etc.)
   - `StatusEffect.gd` - Buffs, debuffs, DoTs, shields, stuns, etc.
   - `Enemy.gd` - Enemy definitions with stats and AI behavior
   - `CombatEncounter.gd` - Complete encounter definitions

2. **Combat Runtime** (`scripts/combat/`)
   - `CombatantStats.gd` - Runtime stats container (health, AP, speed, statuses)
   - `CombatantData.gd` - Wrapper connecting HeroCharacter/Enemy to combat
   - `TurnEvent.gd` - Represents a single turn in the queue
   - `ActiveCast.gd` - Tracks multi-turn ability casts
   - `CombatTimeline.gd` - **The brain** - manages turn order based on speed
   - `CombatScene.gd` - UI controller for combat display

3. **Global Controller** (`scripts/autoloads/`)
   - `CombatController.gd` - Orchestrates all combat, emits signals, processes turns

4. **Integration**
   - `EventManager.gd` — combat from events
   - `Class.gd` — abilities array (class specials)
   - **`HeroCharacter`** (`scripts/party/HeroCharacter.gd`) — **`weapon_slot_a` / `weapon_slot_b` only** (no legacy single `weapon` field); **`allowed_weapon_type_ids_slot_a/b`**, **`allows_weapon_slot_b`**; **`apply_loadout_constraints()`**, **`sanitize_weapon_slots_to_allow_lists()`**; **`duplicate_equipped_weapons_for_run()`** after duplicating a template so run instances don’t share mutable **`Weapon`** subresources with `.tres` files or each other
   - **`Weapon`** (`scripts/resources/Weapon.gd`) — **`weapon_type_id`**, **`occupies_both_slots`**, **`granted_basic_attacks`**, **`contributes_attack_bonus`** (e.g. shields omit tier ATK)
   - **Preset content:** `resources/weapons/starters/*.tres`, `resources/abilities/starters/*.tres`, hero templates `resources/heroes/starter_*.tres` + `unlockable_sellsword.tres` (see `COMBAT_DESIGN.md` section 8.4)
   - **`CombatantData`** — prepends **`Weapon.granted_basic_attacks`**, strips class **`basic_attack`** when weapons supply basics, filters abilities by **`required_weapon_type_ids`**; cooperates with **`CombatController`** for **one basic per turn**

---

## How The System Works

### Party stats vs combat stats
- **Exploration / character sheet:** `HeroCharacter` uses **seven primary attributes** — strength, agility, constitution, intellect, spirit, charisma, luck — from race and class resources.
- **Combat:** `CombatantStats.core_stats` uses **`atk`, `def`, `spd`, `mag`, `mag_def`**. Party members populate these via `HeroCharacter.get_combat_core_stats()` (e.g. `atk` from strength, `spd` from agility, `mag` from intellect, `mag_def` from spirit). **Ability `stat_scaling` in `.tres` files must use these combat keys**, not the seven primary names.
- **Enemies:** `Enemy` resources define `atk`, `def`, `spd`, `mag`, `mag_def` directly (no primary-attribute layer).

### Speed-Based Turn System
Your vision is fully implemented:
- Characters with higher speed get more turns
- Turn timing is calculated as `current_time + (1.0 / speed)`
- Speed 15 character gets ~1.5x more turns than Speed 10 character
- Ties are broken by higher speed going first
- For party members, combat **speed** comes from the derived **`spd`** core stat (mapped from **agility**); statuses can still modify effective speed

### Action Point (AP) Economy
- Max AP: 10 (configurable)
- Base AP per turn: **3** for party members (see `CombatantStats.initialize_from_hero_character`)
- Constitution affects **HP** and growth on the character sheet, not AP regen in the current combat code

### Cast Time System
All three ability types you wanted are implemented:
1. **INSTANT** (cast_time: 0) - Resolves immediately
2. **DELAYED_CAST** (cast_time: X) - Does nothing until X turns later
3. **CHANNELED** (cast_time: X) - Applies effects each turn, can be interrupted

Cast time counts down **per caster turn**, so faster characters resolve casts faster.

### Ability Effects
Modular **`AbilityEffect`** enum; **`CombatController._apply_ability_effects`** resolves the core set (damage, heal, statuses, grounding, formation move, push/pull, interrupt, etc.). **Some** enum values (**`RESTORE_AP`**, **`DRAIN_AP`**, **`SHIELD`**, **`DISPEL`**, **`SPAWN`**, **`LIFESTEAL`**, …) may still be **unimplemented** in the controller — abilities using only those can **no-op** until wired (see `COMBAT_DESIGN.md` section 8.3, section 14 phase **B**).

Effects that **are** resolved scale with caster **`CombatantStats`** / **`stat_scaling`** on **core_stats** keys where applicable.

### Status Effects
Rich status system:
- Duration tracking (decrements per turn)
- Stack behaviors (REFRESH, STACK, REPLACE)
- Stat modifiers on **core_stats** keys (e.g. +5 `spd`, -3 `atk`)
- Periodic effects (DoT/HoT ticks)
- Shields (absorb damage before health)
- Action prevention (stun, silence, root)
- Special flags (uninterruptible, immunity)
- Dispel system

---

## Architecture Strengths

### 1. **Data-Driven**
Almost everything is a Resource (.tres file):
- New abilities = new .tres file (no code changes)
- New enemies = new .tres file
- New statuses = new .tres file
- Balance changes happen in the editor

### 2. **Signal-Based**
CombatController emits 12+ signals:
- `combat_started`
- `turn_started`
- `ability_resolved`
- `combatant_damaged`
- `combatant_died`
- etc.

This means:
- UI can react independently
- Animation systems can hook in
- Multiple systems can listen without coupling
- Easy to add combat logging, achievements, etc.

### 3. **Extensible**
Easy to add:
- New effect types (just add to enum and match statement)
- New status types (already has base types, easy to add more)
- Equipment modifiers (abilities have `runtime_modifiers` dict)
- Passive abilities (persistent StatusEffects)
- Combat events (environmental hazards, reinforcements)
- AI behaviors (Enemy has ai_behavior field)

### 4. **Stat Caching**
CombatantStats caches effective stats:
- Only recalculates when statuses change
- O(1) stat lookups during combat
- Handles complex stat modifier stacking

### 5. **Testable**
CombatController can run without UI:
- Unit tests can simulate combat
- AI development doesn't need visual debugging
- Balance testing can run headless

---

## What to do next (summary)

Authoritative **phased roadmap** and **ordered recommendations** live in **`COMBAT_DESIGN.md`** (sections 14 and 18). At a high level:

1. **New playable heroes** — add **`HeroCharacter` `.tres`** under **`resources/heroes/`** (weapon slots + allow-lists + **`HeroDatabase`** registration if needed). Party select uses templates only; **`scripts/menus/CharacterSelect.gd`** is a **deprecated stub** (remove **`CharacterSelect.tscn`** when you like).
2. **UI** — second weapon row on character details; optional **Blacksmith** upgrade for **`weapon_slot_b`**.
3. **Content** — canonical **`weapon_type_id`** list and PC ability baselines: **`COMBAT_DESIGN.md` section 16.0**; use section16.1 checklist for new abilities.
4. **Systems** — Phase **J** (specials meta), Phase **A/B** (damage + effect resolution gaps), optional Phase **D** (party-phase vs timeline — product decision).

If you are **greenfielding** combat from zero, `COMBAT_SETUP_GUIDE.md` may still help for autoload, scenes, and first encounter — much of the resource work above may already exist in your project.

---

## Future Enhancements (already designed for)

### Enemy AI
- **Today:** `CombatController._execute_ai_turn()` picks a **random** affordable ability (with **Move** bias when **`Enemy.preferred_zone`** doesn’t match row — see `COMBAT_DESIGN.md` section 10.2)
- **`Enemy.ai_behavior`** exists but is **not** driving targeting/scoring yet
- **Future:** archetypes, scoring, `ai_behavior` hooks (`COMBAT_DESIGN.md` phase **E**)

### Equipment → combat
- **Weapons:** tier / enchants / **`get_damage_bonus()`** feed **`HeroCharacter.get_total_weapon_damage_bonus()`** → **`CombatantStats`** ATK (see `CombatantStats.initialize_from_hero_character`)
- **Weapon-granted basics:** listed on **`Weapon.granted_basic_attacks`**; combat prepends and applies **gear + one-basic-per-turn** rules
- **`runtime_modifiers`** on abilities remains available for future “Staff of Haste” style tuning

### Combo System
Abilities can check combat history:
```gdscript
# Example: "If last ability was Fireball, deal +50% damage"
if CombatController.last_ability_cast == "wizard_fireball":
    potency *= 1.5
```

Just need to add `last_ability_cast` tracking to CombatController.

### Positioning / formation (implemented in rules)
- **Front / back rows** per side, **`Ability.attack_range`** (**`MELEE`** vs **`RANGED`**), **`CombatTargetRules`** (melee blocked by front line unless **stealth** vs back row; **flying** / **grounded** — see `COMBAT_DESIGN.md` section 6.4)
- **Voluntary row change:** shared **`move`** ability; **forced:** push/pull effects
- **Scene visuals** for formation are still **authoring**; logic does not depend on `Vector2` positions in `CombatantData`

### Multi-Stage Encounters
CombatEncounter can trigger events mid-combat:
- Reinforcements arrive at turn X
- Boss phase transitions
- Environmental hazard activation

---

## Key Design Decisions

### Why combat speed from agility (as `spd`)?
- **Agility** on the character sheet maps into combat **`spd`** (turn frequency)
- Faster characters act more often; trade-offs are tuned via primaries and equipment
- Statuses and effects can still modify `spd` or effective speed

### Why fixed AP per turn (currently)?
- **AP regeneration** per turn is a fixed baseline in code (`base_ap_per_turn = 3` for party members)
- **Constitution** drives HP and leveling, not AP in the current implementation
- You can later tie AP to `def` or CON-derived values if you want stamina-based economy

### Why Separate CombatantData from HeroCharacter?
- HeroCharacter has exploration concerns (level, XP, inventory)
- CombatantData is pure combat state
- Clean separation of concerns
- After combat, sync back minimal state (health)
- No combat logic pollutes exploration code

### Why Timeline Instead of Rounds?
- More interesting than "everyone goes once"
- Speed stat actually matters
- Supports your vision of fast characters getting extra turns
- Easy to visualize (turn preview UI)
- Can slow/haste characters dynamically

### Why Signals Everywhere?
- Decouples systems
- UI doesn't know about combat logic
- Combat logic doesn't know about UI
- Easy to add features without refactoring
- Great for debugging (signal debugger)

---

## Code Quality Notes

### Follows Your Rules
✅ No `has_method()` calls
✅ All variables declared
✅ No duplicate declarations
✅ Uses unique names (%NodeName) where appropriate
✅ Uses @onready for node children
✅ No scene tree manipulation (CombatScene structure is your job)

### Best Practices
✅ Class names on all custom types
✅ Descriptive comments
✅ Signal-driven architecture
✅ Resource-based data
✅ Stat caching for performance
✅ Error handling with push_error/push_warning
✅ Print statements for debugging

---

## Testing checklist (smoke)

- [ ] **Loadout:** Start a run with preset starters — each hero shows expected **weapon types**; **hunter-type** loadout exposes **two** basics; **shield** does not grant a basic
- [ ] **Combat:** basics respect **one per turn**; gear-gated specials hidden or blocked when types missing
- [ ] **Blacksmith / upgrades:** tier changes on slot A affect **that hero instance only** (not template `.tres` or a duplicate hero)
- [ ] **Formation:** melee/ranged and row rules behave per `COMBAT_DESIGN.md` section 6.4 (optional deep pass)

---

## Questions?

For **design intent**, **gaps**, and **what to build next**, prefer **`COMBAT_DESIGN.md`**. This overview stays **architecture- and integration-focused** and should be updated when major combat-facing APIs or data paths change.
