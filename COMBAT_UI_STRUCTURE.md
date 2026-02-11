# Combat UI Structure - Polished Design

## ✅ New Scene-Based Architecture

You've created a proper modular UI system! Here's how everything fits together:

---

## 📦 Scene Components

### 1. **CombatCharacterSprite.tscn**
**Location:** Visual combat area (top section)
**Purpose:** Character/enemy visual representation
**Script:** `scripts/CombatCharacterSprite.gd`

**Structure:**
```
CombatCharacterSprite (Control)
  └─ Sprite2D
```

**Methods:**
- `set_sprite_texture(texture: Texture2D)` - Set character/enemy sprite
- `set_sprite_modulation(color: Color)` - Grey out on death, highlight on turn, etc.

**Future:** Custom drawn sprites, animations, visual effects

---

### 2. **CharacterCombatInformationPanel.tscn**
**Location:** Party info panel (bottom-left section)
**Purpose:** Display Name, HP, AP for party members
**Script:** `scripts/CharacterCombatInformationPanel.gd`

**Structure:**
```
CharacterCombatInformationPanel (PanelContainer)
  └─ VBoxContainer
      └─ HBoxContainer
          ├─ NameLabel
          ├─ APLabel
          └─ HealthLabel
```

**Methods:**
- `update_display(name, hp, max_hp, ap, max_ap)` - Refresh all stats at once

**Data Displayed:**
- **Name:** "Champion Baldric"
- **Health:** "HP: 45/50"
- **AP:** "AP: 3/10"

---

## 🎨 Visual Layout

```
┌─────────────────────────────────────────────────┐
│ Current Turn: Champion Baldric                  │
├─────────────────────────────────────────────────┤
│ Turn Order:                                      │
│  - Wizard Alice (0.15)                          │
│  - Bandit Rogue (0.18)                          │
│  - Champion Baldric (0.20)                      │
├─────────────────────────────────────────────────┤
│ Combat Area Panel                                │
│ ┌─────────────────┬─────────────────┐           │
│ │ Player Sprites  │ Enemy Sprites   │           │
│ │ [Champion] [Wiz]│ [Bandit][Cultist│           │
│ │ [Cleric]        │ [Cultist]       │           │
│ └─────────────────┴─────────────────┘           │
├─────────────────────────────────────────────────┤
│ ┌──────────┬──────────┬──────────┐              │
│ │Party Info│ Abilities│ Combat Log│             │
│ │Champion  │[Shield B]│Champion   │             │
│ │HP:45/50  │[Def Stan]│casts...   │             │
│ │AP:3/10   │[Heroic S]│Enemy      │             │
│ │          │          │takes...   │             │
│ │Wizard    │          │           │             │
│ │HP:20/25  │          │           │             │
│ │AP:3/10   │          │           │             │
│ └──────────┴──────────┴──────────┘              │
└─────────────────────────────────────────────────┘
```

---

## 🔄 Data Flow

### Combat Start:
```
1. CombatController.combat_started signal
2. CombatScene._on_combat_started()
3. For each player:
   - Instantiate CombatCharacterSprite → combat_area_player_panel
   - Instantiate CharacterCombatInformationPanel → party_info_panel
   - Create invisible Button overlay for click targeting
   - Store references in dictionaries
4. For each enemy:
   - Instantiate CombatCharacterSprite → combat_area_enemy_panel
   - Create invisible Button overlay for click targeting
   - Store reference (no info panel for enemies)
```

### Stat Updates:
```
1. Combatant takes damage/heals
2. CombatController emits combatant_damaged/combatant_healed
3. CombatScene._on_combatant_damaged()
4. CombatScene._update_combatant_info_panel(combatant)
5. info_panel.update_display() → Updates all labels
```

### Turn Start:
```
1. CombatController.turn_started signal
2. CombatScene._on_turn_started()
3. Update current_turn_label
4. _update_combatant_info_panel() → Refresh AP (regenerated)
5. If player turn: Show abilities
```

### Ability Cast:
```
1. Player clicks ability button
2. Auto-select targets OR wait for manual click
3. CombatController.player_cast_ability()
4. Ability resolves
5. CombatController.ability_resolved signal
6. Update caster's info panel (AP spent)
7. Update targets' info panels (damage/healing)
```

---

## 💾 Data Structures in CombatScene.gd

```gdscript
# Scene references (preloaded)
var combat_character_sprite_scene: PackedScene
var character_info_panel_scene: PackedScene

# Runtime dictionaries
var combatant_sprites: Dictionary           # CombatantData -> CombatCharacterSprite
var combatant_info_panels: Dictionary       # CombatantData -> CharacterCombatInformationPanel
var combatant_clickable_areas: Dictionary   # CombatantData -> Button (for targeting)
var ability_buttons: Array[Button]          # Current turn's ability buttons
```

**Why Dictionaries?**
- Fast lookup by CombatantData
- Easy to update specific combatant's display
- Clean separation of visual components

---

## 🎯 Targeting System

### How Clicking Works:
1. Each CombatCharacterSprite has an invisible **flat Button** overlay
2. Button sized to match sprite
3. Button connected to `_on_combatant_clicked(combatant)`
4. When clicked:
   - If ability selected: Use as target
   - If no ability: Ignore (or show info tooltip in future)

### Auto-Targeting:
- **SELF** abilities: Auto-target caster
- **SINGLE_ALLY**: Auto-target first valid ally
- **SINGLE_ENEMY**: Auto-target first valid enemy
- **ALL_X** abilities: Auto-target all in category
- **Manual targeting**: Click sprite after selecting ability

---

## 🔮 Future Enhancements

### Visual Polish:
- [ ] Character portrait sprites (replace placeholder Sprite2D)
- [ ] Enemy sprites per type
- [ ] Health bars under sprites
- [ ] AP bars under health bars
- [ ] Casting progress bars
- [ ] Status effect icons floating above sprites
- [ ] Damage numbers pop-ups
- [ ] Healing numbers pop-ups
- [ ] Screen shake on damage
- [ ] Particle effects for abilities

### Info Panel Enhancements:
- [ ] Color-code health (green > yellow > red)
- [ ] Flash AP when spent
- [ ] Show active status effects
- [ ] Buff/debuff icons
- [ ] Portrait thumbnails
- [ ] Class icons

### Combat Area Enhancements:
- [ ] Sprites scale based on character size
- [ ] Position sprites based on formation (front/back row)
- [ ] Animate sprites (idle, attack, hit, death)
- [ ] Highlight on hover
- [ ] Glow on current turn
- [ ] Shadow under sprites

---

## 🏗️ Why This Structure is Good

### ✅ **Separation of Concerns:**
- Visual (CombatCharacterSprite) separate from data (CharacterCombatInformationPanel)
- Can swap sprites without touching info panels
- Can redesign info panels without touching sprites

### ✅ **Reusability:**
- Same CombatCharacterSprite for players AND enemies
- Info panels can be used for any combatant
- Easy to add more combatants (summons, pets, etc.)

### ✅ **Extensibility:**
- Add animations to CombatCharacterSprite without changing CombatScene
- Add status icons to info panels without changing combat logic
- Add new UI elements by instantiating new scenes

### ✅ **Testing:**
- Can test CombatCharacterSprite in isolation
- Can test CharacterCombatInformationPanel in isolation
- Can preview scenes in editor without running full combat

---

## 🎮 Testing the New Structure

### What to Verify:
1. ✅ Each party member has a sprite in combat area
2. ✅ Each party member has an info panel below
3. ✅ Info panels show correct Name/HP/AP
4. ✅ Sprites are clickable for targeting
5. ✅ HP updates when damaged
6. ✅ AP updates when abilities cast
7. ✅ AP refreshes on turn start
8. ✅ Dead combatants grey out
9. ✅ Enemies have sprites but no info panels

### Known Placeholder Issues:
- Sprites have no texture (blank) - **Expected!**
  - Add textures with: `sprite.set_sprite_texture(load("res://path/to/texture.png"))`
- Sprites might be tiny - **Size in scene editor**
- Info panels might overlap - **Adjust sizing in scene**

---

## 📝 Next Steps

### Immediate (Visual):
1. **Set sprite sizes** in CombatCharacterSprite.tscn
   - custom_minimum_size = Vector2(64, 64) or bigger
2. **Add placeholder textures**
   - icon.svg for testing
   - Color rectangles for different classes
3. **Style info panels**
   - Add panel backgrounds
   - Font sizes
   - Colors

### Short-term (Polish):
1. Add health bars to info panels
2. Add tooltips on hover
3. Highlight current turn combatant
4. Add cast progress indicators
5. Add status effect display

### Long-term (Features):
1. Character portraits/sprites
2. Animations
3. Particle effects
4. Sound effects
5. Camera shake/zoom
6. Formation system

---

## 🚀 Summary

**You've built a clean, modular combat UI!**

**Structure:**
- Visual sprites in combat area
- Stat panels below for party
- Dictionaries track everything
- Easy to update, easy to extend

**It works now, polishes later!** 🎨

Test it, see how it feels, then iterate on visuals!
