# Combat System Setup Guide

This guide walks you through setting up the combat system resources and scenes.

## 1. AUTOLOAD SETUP

First, add the CombatController as an autoload:

1. Project → Project Settings → Autoload
2. Add: `res://scripts/autoloads/CombatController.gd` as `CombatController`

## 2. CREATE ABILITY RESOURCES

Create the following ability resources in `resources/abilities/`:

### CHAMPION ABILITIES

#### Shield Bash (`resources/abilities/champion/shield_bash.tres`)
- **Script:** Ability
- **ability_name:** "Shield Bash"
- **ability_id:** "champion_shield_bash"
- **description:** "Bash an enemy with your shield, dealing damage and stunning them."
- **ap_cost:** 2
- **base_cast_time:** 0
- **ability_type:** INSTANT
- **targeting_type:** SINGLE_ENEMY
- **requires_target:** true
- **can_be_interrupted:** true
- **effects:** Create 2 AbilityEffect resources:
  1. **Damage Effect:**
	 - effect_type: DAMAGE
	 - potency: 8.0
	 - stat_scaling: {"strength": 1.0}
  2. **Stun Effect:**
	 - effect_type: APPLY_STATUS
	 - status_to_apply: *(create a StatusEffect "Stunned" - see below)*

#### Defensive Stance (`resources/abilities/champion/defensive_stance.tres`)
- **Script:** Ability
- **ability_name:** "Defensive Stance"
- **ability_id:** "champion_defensive_stance"
- **description:** "Enter a defensive stance, reducing damage taken."
- **ap_cost:** 3
- **base_cast_time:** 0
- **ability_type:** INSTANT
- **targeting_type:** SELF
- **requires_target:** false
- **effects:** Create 1 AbilityEffect:
  - effect_type: APPLY_STATUS
  - status_to_apply: *(create StatusEffect "Defensive Stance" - see below)*

#### Heroic Strike (`resources/abilities/champion/heroic_strike.tres`)
- **Script:** Ability
- **ability_name:** "Heroic Strike"
- **ability_id:** "champion_heroic_strike"
- **description:** "A powerful strike that takes time to wind up."
- **ap_cost:** 3
- **base_cast_time:** 2
- **ability_type:** DELAYED_CAST
- **targeting_type:** SINGLE_ENEMY
- **requires_target:** true
- **can_be_interrupted:** true
- **effects:** Create 1 AbilityEffect:
  - effect_type: DAMAGE
  - potency: 20.0
  - stat_scaling: {"strength": 1.5}

---

### WIZARD ABILITIES

#### Arcane Blast (`resources/abilities/wizard/arcane_blast.tres`)
- **Script:** Ability
- **ability_name:** "Arcane Blast"
- **ability_id:** "wizard_arcane_blast"
- **description:** "Fire a quick blast of arcane energy."
- **ap_cost:** 2
- **base_cast_time:** 0
- **ability_type:** INSTANT
- **targeting_type:** SINGLE_ENEMY
- **requires_target:** true
- **effects:** Create 1 AbilityEffect:
  - effect_type: DAMAGE
  - potency: 10.0
  - stat_scaling: {"intelligence": 1.2}

#### Fireball (`resources/abilities/wizard/fireball.tres`)
- **Script:** Ability
- **ability_name:** "Fireball"
- **ability_id:** "wizard_fireball"
- **description:** "Hurl a massive fireball that damages all enemies."
- **ap_cost:** 3
- **base_cast_time:** 3
- **ability_type:** DELAYED_CAST
- **targeting_type:** ALL_ENEMIES
- **requires_target:** false
- **can_be_interrupted:** true
- **effects:** Create 1 AbilityEffect:
  - effect_type: DAMAGE
  - potency: 15.0
  - stat_scaling: {"intelligence": 1.5}
  - target_count: 999

#### Mana Shield (`resources/abilities/wizard/mana_shield.tres`)
- **Script:** Ability
- **ability_name:** "Mana Shield"
- **ability_id:** "wizard_mana_shield"
- **description:** "Create a magical shield that absorbs damage."
- **ap_cost:** 2
- **base_cast_time:** 0
- **ability_type:** INSTANT
- **targeting_type:** SELF
- **requires_target:** false
- **effects:** Create 1 AbilityEffect:
  - effect_type: APPLY_STATUS
  - status_to_apply: *(create StatusEffect "Mana Shield" - see below)*

---

### CLERIC ABILITIES

#### Heal (`resources/abilities/cleric/heal.tres`)
- **Script:** Ability
- **ability_name:** "Heal"
- **ability_id:** "cleric_heal"
- **description:** "Restore health to an ally."
- **ap_cost:** 2
- **base_cast_time:** 0
- **ability_type:** INSTANT
- **targeting_type:** SINGLE_ALLY
- **requires_target:** true
- **effects:** Create 1 AbilityEffect:
  - effect_type: HEAL
  - potency: 12.0
  - stat_scaling: {"wisdom": 1.0}

#### Holy Smite (`resources/abilities/cleric/holy_smite.tres`)
- **Script:** Ability
- **ability_name:** "Holy Smite"
- **ability_id:** "cleric_holy_smite"
- **description:** "Strike an enemy with holy power."
- **ap_cost:** 3
- **base_cast_time:** 0
- **ability_type:** INSTANT
- **targeting_type:** SINGLE_ENEMY
- **requires_target:** true
- **effects:** Create 1 AbilityEffect:
  - effect_type: DAMAGE
  - potency: 12.0
  - stat_scaling: {"wisdom": 1.2}

#### Prayer (`resources/abilities/cleric/prayer.tres`)
- **Script:** Ability
- **ability_name:** "Prayer"
- **ability_id:** "cleric_prayer"
- **description:** "Channel divine energy to heal all allies each turn. Can be interrupted."
- **ap_cost:** 3
- **base_cast_time:** 3
- **ability_type:** CHANNELED
- **targeting_type:** ALL_ALLIES
- **requires_target:** false
- **can_be_interrupted:** true
- **effects:** Create 1 AbilityEffect:
  - effect_type: HEAL
  - potency: 6.0
  - stat_scaling: {"wisdom": 0.8}
  - target_count: 999

---

## 3. CREATE STATUS EFFECT RESOURCES

Create in `resources/statuses/`:

### Stunned (`resources/statuses/stunned.tres`)
- **Script:** StatusEffect
- **status_name:** "Stunned"
- **status_id:** "stunned"
- **description:** "Cannot act."
- **status_type:** STUN
- **base_duration:** 1
- **stack_behavior:** REFRESH
- **prevents_actions:** true
- **prevents_movement:** true
- **prevents_casting:** true
- **is_dispellable:** true

### Defensive Stance (`resources/statuses/defensive_stance.tres`)
- **Script:** StatusEffect
- **status_name:** "Defensive Stance"
- **status_id:** "defensive_stance"
- **description:** "Taking reduced damage."
- **status_type:** BUFF
- **base_duration:** 2
- **stack_behavior:** REFRESH
- **stat_modifiers:** {"constitution": 5}
- **is_dispellable:** true

### Mana Shield (`resources/statuses/mana_shield.tres`)
- **Script:** StatusEffect
- **status_name:** "Mana Shield"
- **status_id:** "mana_shield"
- **description:** "Magical barrier absorbing damage."
- **status_type:** SHIELD
- **base_duration:** 3
- **stack_behavior:** REFRESH
- **shield_amount:** 15.0
- **is_dispellable:** true

---

## 4. ASSIGN ABILITIES TO CLASSES

Update your existing class resources (`resources/classes/*.tres`):

### Champion (`resources/classes/champion.tres`)
Add to **abilities** array:
1. `resources/abilities/champion/shield_bash.tres`
2. `resources/abilities/champion/defensive_stance.tres`
3. `resources/abilities/champion/heroic_strike.tres`

### Wizard (`resources/classes/wizard.tres`)
Add to **abilities** array:
1. `resources/abilities/wizard/arcane_blast.tres`
2. `resources/abilities/wizard/fireball.tres`
3. `resources/abilities/wizard/mana_shield.tres`

### Cleric (`resources/classes/cleric.tres`)
Add to **abilities** array:
1. `resources/abilities/cleric/heal.tres`
2. `resources/abilities/cleric/holy_smite.tres`
3. `resources/abilities/cleric/prayer.tres`

---

## 5. CREATE TEST ENEMY

Create `resources/enemies/test_bandit.tres`:
- **Script:** Enemy
- **enemy_name:** "Bandit"
- **enemy_id:** "test_bandit"
- **description:** "A common bandit."
- **max_health:** 20
- **base_stats:**
  ```
  {
	"strength": 12,
	"dexterity": 11,
	"constitution": 10,
	"intelligence": 8,
	"wisdom": 8,
	"charisma": 9
  }
  ```
- **abilities:** Add a simple attack ability (you can create `resources/abilities/shared/basic_attack.tres` or reuse an existing damage ability)
- **ai_behavior:** "Aggressive"
- **xp_reward:** 15
- **gold_reward:** 5

---

## 6. CREATE TEST ENCOUNTER

Create `resources/encounters/test_encounter.tres`:
- **Script:** CombatEncounter
- **encounter_id:** "test_encounter"
- **encounter_name:** "Bandit Ambush"
- **description:** "You've been ambushed by bandits!"
- **enemies:** Add 2 instances of `resources/enemies/test_bandit.tres`
- **can_escape:** true
- **bonus_xp:** 10

---

## 7. CREATE COMBAT SCENE

Create `scenes/combat/CombatScene.tscn`:

### Scene Structure:
```
CombatScene (Control) [Script: res://scripts/combat/CombatScene.gd]
├─ MarginContainer
│  └─ VBoxContainer
│     ├─ CurrentTurnLabel (Label) - Unique Name: %CurrentTurnLabel
│     ├─ TurnOrderPanel (PanelContainer)
│     │  └─ VBoxContainer
│     │     ├─ Label (text: "Turn Order")
│     │     └─ TurnOrderDisplay (VBoxContainer) - Unique Name: %TurnOrderDisplay
│     ├─ CombatAreaPanel (PanelContainer)
│     │  └─ HBoxContainer
│     │     ├─ PlayerPanel (VBoxContainer) - Unique Name: %PlayerPanel
│     │     │  └─ Label (text: "Party")
│     │     └─ EnemyPanel (VBoxContainer) - Unique Name: %EnemyPanel
│     │        └─ Label (text: "Enemies")
│     ├─ AbilityPanel (HBoxContainer) - Unique Name: %AbilityPanel
│     ├─ EndTurnButton (Button) - Unique Name: %EndTurnButton
│     │  └─ text: "End Turn"
│     └─ CombatLogPanel (PanelContainer)
│        └─ ScrollContainer
│           └─ CombatLog (RichTextLabel) - Unique Name: %CombatLog
│              └─ scroll_following: true
```

### Key Settings:
- All main UI elements should have **Access as Unique Name** enabled
- CombatLog should have:
  - **BBCode Enabled:** true
  - **Scroll Following:** true
  - **Fit Content:** true
- Layout:
  - Make it fill the screen
  - Use margins for padding
  - Make combat log scrollable

---

## 8. TEST COMBAT

To test combat, you have two options:

### Option A: Create a test button in your Main scene
Add a button to Main.tscn that calls:
```gdscript
func _on_test_combat_button_pressed():
	var encounter = load("res://resources/encounters/test_encounter.tres")
	var combat_scene = load("res://scenes/combat/CombatScene.tscn").instantiate()
	add_child(combat_scene)
	CombatController.start_combat_from_encounter(encounter, current_party_members)
```

### Option B: Integrate with EventManager
Update an existing event JSON to use:
```json
{
  "type": "start_combat",
  "encounter_id": "test_encounter"
}
```

Then update EventManager's `_apply_start_combat` function (see next section).

---

## 9. INTEGRATE WITH EVENTMANAGER

Update `scripts/events/EventManager.gd`:

Replace the `_apply_start_combat` function with:
```gdscript
func _apply_start_combat(effect: Dictionary, party: Dictionary, node_state: Dictionary):
	if not effect.has("encounter_id"):
		push_warning("EventManager: start_combat effect missing 'encounter_id' field")
		return
	
	# Load encounter resource
	var encounter_path = "res://resources/encounters/%s.tres" % effect.encounter_id
	var encounter = load(encounter_path) as CombatEncounter
	
	if not encounter:
		push_error("EventManager: Could not load encounter: " + encounter_path)
		return
	
	# Get party members from Main
	var main = get_tree().root.get_node_or_null("Main")
	if not main:
		push_error("EventManager: Could not find Main node")
		return
	
	# Load and show combat scene
	var combat_scene = load("res://scenes/combat/CombatScene.tscn").instantiate()
	get_tree().root.add_child(combat_scene)
	
	# Start combat
	CombatController.start_combat_from_encounter(encounter, main.current_party_members)
```

---

## 10. NEXT STEPS

Once basic combat works, you can expand:

1. **Enemy AI:** Implement decision-making in `CombatController._execute_ai_turn()`
2. **More Abilities:** Create more varied effects (buffs, debuffs, summons, etc.)
3. **Victory Screen:** Show rewards, XP gained, level ups
4. **Combat Animations:** Add tweens, particles, screen shake
5. **Sound Effects:** Add audio for abilities and hits
6. **Advanced Mechanics:** 
   - Equipment modifiers
   - Combo systems
   - Positioning/formation
   - Environmental hazards
   - Multi-stage encounters

---

## TROUBLESHOOTING

### "Cannot find CombatController"
- Make sure it's added as an Autoload in Project Settings

### "Ability has no effects"
- Check that AbilityEffect resources are properly assigned to the ability
- Verify effect_type is set correctly

### "No damage/healing happening"
- Check stat_scaling dictionary format: `{"stat_name": multiplier}`
- Verify potency is set (not 0)

### "Combat doesn't start"
- Check that encounter has enemies assigned
- Verify enemy resources have abilities
- Check console for error messages

### "Abilities don't show"
- Verify Class resources have abilities array filled
- Check that abilities are properly loaded in CombatantData
