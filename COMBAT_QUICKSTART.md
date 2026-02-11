# Combat System Quick Start

## 5-Minute Setup (Minimal Test)

Follow these steps to get combat running ASAP. Full details in `COMBAT_SETUP_GUIDE.md`.

### 1. Add Autoload (30 seconds)
- Project → Project Settings → Autoload
- Path: `res://scripts/autoloads/CombatController.gd`
- Node Name: `CombatController`
- Click "Add"

### 2. Create ONE Test Ability (1 minute)
Right-click `resources/` folder → New Resource → Ability
- Save as: `resources/abilities/test_punch.tres`
- Set properties:
  - ability_name: "Punch"
  - ability_id: "test_punch"
  - ap_cost: 2
  - base_cast_time: 0
  - ability_type: INSTANT
  - targeting_type: SINGLE_ENEMY
- Click "effects" → Add Element
  - Create new AbilityEffect inline
  - effect_type: DAMAGE
  - potency: 10.0
- Save

### 3. Assign to Champion Class (30 seconds)
- Open `resources/classes/champion.tres`
- Find "abilities" array
- Add element → Drag `test_punch.tres` into slot
- Save

### 4. Create Test Enemy (1 minute)
Right-click `resources/` → New Folder → "enemies"
Right-click `enemies/` → New Resource → Enemy
- Save as: `resources/enemies/test_dummy.tres`
- Set properties:
  - enemy_name: "Training Dummy"
  - enemy_id: "test_dummy"
  - max_health: 20
  - base_stats: (expand dictionary)
    ```
    "strength": 10
    "dexterity": 10
    "constitution": 10
    "intelligence": 10
    "wisdom": 10
    "charisma": 10
    ```
  - abilities: Add element → Drag `test_punch.tres` into slot
  - xp_reward: 10
- Save

### 5. Create Test Encounter (30 seconds)
Right-click `resources/` → New Folder → "encounters"
Right-click `encounters/` → New Resource → CombatEncounter
- Save as: `resources/encounters/test_fight.tres`
- Set properties:
  - encounter_id: "test_fight"
  - encounter_name: "Test Combat"
  - enemies: Add 1 element → Drag `test_dummy.tres` into slot
- Save

### 6. Create Minimal Combat Scene (1.5 minutes)
Create new scene → User Interface → Control
- Rename root to "CombatScene"
- Attach script: `res://scripts/combat/CombatScene.gd`

Add child nodes (use Add Node button):
```
CombatScene (Control)
  ├─ CombatLog (RichTextLabel)
  │   └─ Enable: BBCode Enabled, Scroll Following
  │   └─ Layout: Anchor preset = Full Rect
  │   └─ Right-click → Access as Unique Name (%CombatLog)
  ├─ TurnOrderDisplay (VBoxContainer)
  │   └─ Position: Top-left corner (offset 10, 10)
  │   └─ Right-click → Access as Unique Name (%TurnOrderDisplay)
  ├─ CurrentTurnLabel (Label)
  │   └─ Position: Top-center (offset Y: 10)
  │   └─ Right-click → Access as Unique Name (%CurrentTurnLabel)
  ├─ PlayerPanel (HBoxContainer)
  │   └─ Position: Left side (offset 10, 200)
  │   └─ Right-click → Access as Unique Name (%PlayerPanel)
  ├─ EnemyPanel (HBoxContainer)
  │   └─ Position: Right side (offset X: screen_width - 200, Y: 200)
  │   └─ Right-click → Access as Unique Name (%EnemyPanel)
  ├─ AbilityPanel (HBoxContainer)
  │   └─ Position: Bottom-center (offset Y: screen_height - 100)
  │   └─ Right-click → Access as Unique Name (%AbilityPanel)
  └─ EndTurnButton (Button)
      └─ Text: "End Turn"
      └─ Position: Bottom-right (offset X: screen_width - 120, Y: screen_height - 60)
      └─ Right-click → Access as Unique Name (%EndTurnButton)
```

**Quick layout tip:** Just drag all nodes anywhere on screen for now. Make them visible. Enable unique names. Done. Polish later.

- Save as: `scenes/combat/CombatScene.tscn`

### 7. Add Test Button to Main (1 minute)
Open `scenes/2d/Main.tscn`
- Add child Button to UIController
- Text: "TEST COMBAT"
- Position: Top-left corner
- Connect "pressed" signal to Main script
- Add this function to `scripts/2d/Main.gd`:

```gdscript
func _on_test_combat_button_pressed():
	var encounter = load("res://resources/encounters/test_fight.tres")
	CombatController.start_combat_from_encounter(encounter, current_party_members)
```

### 8. Test!
- Run game (F5)
- Create party with at least one Champion
- Start game
- Click "TEST COMBAT" button
- Watch console output
- Combat UI should appear
- Click ability to attack
- Click "End Turn" to skip
- Victory when dummy dies!

---

## What You Should See

**Console Output:**
```
CombatController initialized
=== COMBAT START ===
Registered player: YourChampion (Speed: 7.00, AP: 3)
Registered enemy: Training Dummy (Speed: 5.00, AP: 3)
Player turn: YourChampion (AP: 3/10)
YourChampion casts Punch (AP: 2, Cast Time: 0)
  -> Resolved instantly
  -> Training Dummy takes 10.0 damage
...
=== COMBAT ENDED ===
Victory: True
```

**UI:**
- Turn order list (shows upcoming turns)
- Current turn label
- Character/enemy portraits
- Ability buttons (enabled/disabled based on AP)
- End Turn button
- Combat log (scrolling text)

---

## If It Doesn't Work

### "Class 'CombatController' not found"
→ Add it as Autoload (step 1)

### "Combat scene not found"
→ Save scene to exact path: `scenes/combat/CombatScene.tscn`

### "Encounter not found"
→ Check encounter_id matches filename (e.g., `test_fight.tres` needs `encounter_id: "test_fight"`)

### "No abilities showing"
→ Make sure Champion class has abilities array filled
→ Check your party has a Champion

### "Can't click anything"
→ Enable "Access as Unique Name" on all nodes
→ Check node names match script (%CombatLog, %EndTurnButton, etc.)

---

## Next Steps After This Works

1. **Create full ability set** (see `COMBAT_SETUP_GUIDE.md`)
2. **Polish UI** (better layouts, colors, portraits)
3. **Add status effects** (stuns, buffs, shields)
4. **Create more enemies** (varied stats, abilities)
5. **Balance numbers** (damage, costs, speeds)
6. **Enemy AI** (implement `_execute_ai_turn()`)
7. **Victory screen** (show XP, rewards)
8. **Combat transitions** (fade in/out)

---

## Pro Tips

- **All balance numbers are in .tres files** - no code changes needed!
- **Console output is your friend** - shows everything happening
- **Test with 1 enemy first** - easier to see turn order
- **Speed differences matter** - try enemy with speed 15 vs speed 5
- **AP costs matter** - 2 AP vs 3 AP abilities feel very different
- **Cast times are powerful** - instant vs 3-turn cast completely changes balance

---

## Full Documentation

- `COMBAT_SYSTEM_OVERVIEW.md` - Architecture, design decisions
- `COMBAT_SETUP_GUIDE.md` - Complete setup for all 3 classes
- This file - Minimal quick start

Good luck! 🎮
