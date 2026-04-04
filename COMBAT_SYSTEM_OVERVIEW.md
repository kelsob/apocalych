# Combat System Overview

## What's Been Built

I've created a complete, extensible turn-based combat system for your game. Here's what exists:

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
   - Updated `EventManager.gd` to start combat from events
   - Updated `Class.gd` to include abilities array
   - Updated `HeroCharacter` integration

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
Fully modular system:
- **DAMAGE** - Scales with `stat_scaling` on **core_stats** (e.g. `{"mag": 1.2}` for spell damage)
- **HEAL** - Scales with stats
- **APPLY_STATUS** - Applies buffs/debuffs
- **INTERRUPT_CAST** - Stops enemy casts
- **RESTORE_AP** - Energy manipulation
- **DRAIN_AP** - Energy denial
- **SHIELD** - Damage absorption
- **DISPEL** - Remove buffs/debuffs

Effects scale with caster stats automatically.

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

## What You Need To Do

### Immediate (to test combat):

1. **Add CombatController as Autoload**
   - Project → Project Settings → Autoload
   - Add `res://scripts/autoloads/CombatController.gd` as `CombatController`

2. **Create Ability Resources**
   - See `COMBAT_SETUP_GUIDE.md` for detailed instructions
   - I've designed 9 abilities for Champion/Wizard/Cleric
   - Create them as .tres files in Godot editor

3. **Create Status Effect Resources**
   - Stunned, Defensive Stance, Mana Shield
   - See guide for properties

4. **Assign Abilities to Classes**
   - Edit your existing champion.tres, wizard.tres, cleric.tres
   - Add abilities to the `abilities` array

5. **Create Test Enemy**
   - Simple bandit enemy with basic stats
   - Give it 1-2 simple abilities

6. **Create Test Encounter**
   - Add 2 bandits to an encounter
   - Save as `resources/encounters/test_encounter.tres`

7. **Create Combat Scene**
   - Build the UI structure (see guide for hierarchy)
   - Attach `CombatScene.gd` script
   - Mark key nodes with unique names (%NodeName)

8. **Test!**
   - Either add a test button in Main
   - Or trigger via an event with `"type": "start_combat"`

---

## Future Enhancements (already designed for)

### Enemy AI
The system is ready:
- `CombatController._execute_ai_turn()` is stubbed
- Enemy has `ai_behavior` field
- You can implement:
  - Simple behavior patterns ("Aggressive" = always attack lowest health)
  - Weighted scoring system
  - Behavior trees
  - Goal-oriented action planning (GOAP)

### Equipment Modifiers
Abilities have `runtime_modifiers` dict:
```gdscript
# Example: Staff of Haste
ability.apply_modifier({"cast_time": -1, "ap_cost": -1})
```

Easy to add equipment system that modifies abilities on equip/unequip.

### Combo System
Abilities can check combat history:
```gdscript
# Example: "If last ability was Fireball, deal +50% damage"
if CombatController.last_ability_cast == "wizard_fireball":
    potency *= 1.5
```

Just need to add `last_ability_cast` tracking to CombatController.

### Positioning/Formation
CombatantData can have `position: Vector2`:
- Front row / back row
- Range-based abilities
- Movement abilities
- Flanking bonuses

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

## Testing Checklist

Once you've set everything up:

- [ ] CombatController autoload registered
- [ ] 9 abilities created (3 per class)
- [ ] 3 status effects created
- [ ] Abilities assigned to classes
- [ ] Test enemy created
- [ ] Test encounter created
- [ ] Combat scene built with unique names
- [ ] Combat starts from event or test button
- [ ] Turn order displays correctly
- [ ] Abilities can be cast
- [ ] Damage/healing applies
- [ ] Status effects work
- [ ] Fast characters get more turns
- [ ] Cast times count down correctly
- [ ] Combat ends on victory/defeat

---

## Questions?

The system is ready to use. All the hard architectural work is done. The remaining work is:
1. **Creating resources** (mechanical, see guide)
2. **Building combat UI** (visual design, your expertise)
3. **Balancing numbers** (iterative, after testing)

The system is designed to make #3 easy - all balance numbers are in .tres files, no code changes needed.

Let me know when you're ready to test or if you hit any issues!
