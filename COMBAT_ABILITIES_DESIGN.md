# Combat Abilities - Design Document

I've created a complete, balanced ability set for all 3 starting classes, showcasing every combat mechanic. Here's what I built and why.

---

## 📊 STAT DISTRIBUTION SUMMARY

Characters use **seven primaries** (race + class): strength, agility, constitution, intellect, spirit, charisma, luck. **Combat ability scaling** uses **`atk`, `mag`, `mag_def`** (and sometimes `spd` / `def`) on `CombatantStats` — see `COMBAT_SETUP_GUIDE.md`.

### Champion (physical tank)
- **Class modifiers:** Strength +3, Constitution +2, Charisma +1
- **Philosophy:** High HP from constitution, moderate combat speed (`spd` from agility)
- **Role:** Frontline protector, disruptor

### Wizard (arcane caster)
- **Class modifiers:** Intellect +4, Spirit +1, Luck +1, Strength −1
- **Philosophy:** High `mag` from intellect; HP and speed depend on race + gear
- **Role:** High burst damage, crowd control

### Cleric (divine support)
- **Class modifiers:** Spirit +3, Charisma +2, Constitution +1
- **Philosophy:** Healing and holy damage scale with **`mag_def`** in combat (derived from **spirit**)
- **Role:** Healing, buffs, utility

---

## 🛡️ CHAMPION ABILITIES

### 1. Shield Bash (2 AP, Instant)
**Type:** Damage + Stun
**Scaling:** 8 base + 100% ATK (combat stat; driven by strength)
**Effect:** Stuns target for 1 turn

**Design:** The "bread and butter" ability. Reliable instant damage with crowd control. Low AP cost means you can use it frequently. The stun is powerful but short - tactical disruption, not lockdown.

**Counters:** Enemy channels and long casts
**Vulnerable to:** None (instant cast)

---

### 2. Defensive Stance (2 AP, Instant)
**Type:** Self Buff
**Effect:** +5 `def` (physical defense) for 2 turns

**Design:** Survivability button. Extra **def** reduces incoming physical damage. Creates "turtle mode" windows where the Champion can weather heavy damage. (AP per turn is not tied to constitution in current combat code.)

**Synergy:** Use before Heroic Strike to tank damage during cast
**Trade-off:** Costs AP that could be used for damage

---

### 3. Heroic Strike (3 AP, 2-Turn Delayed Cast)
**Type:** Heavy Damage
**Scaling:** 25 base + 180% ATK
**Cast Time:** 2 turns

**Design:** The "big hit" ability. Costs most AP and takes 2 turns to resolve, but deals ~3x more damage than Shield Bash. High risk/high reward - can be interrupted. Demonstrates delayed cast mechanic.

**Counters:** Low-health enemies, breaking shields
**Vulnerable to:** Interrupts, enemy killing you during cast
**Synergy:** Defensive Stance first for protection

---

### 4. Shield Wall (4 AP, 3-Turn Channel)
**Type:** Party Shield + Uninterruptible
**Effect:** All allies gain 15 shield + uninterruptible for 2 turns
**Cast Time:** 3 turns channeled

**Design:** THE ultimate team protection ability. Expensive (4 AP!) and takes 3 turns to channel, but grants the entire party shields AND makes them uninterruptible. This is a game-changer - protects your Wizard's Fireball, your Cleric's Prayer, everything.

**Strategic Use:** Pop this before your team channels big abilities
**Trade-off:** Champion does nothing else for 3 turns
**Vulnerability:** Can be interrupted (ironically, the protector needs protection)

---

### 5. Interrupt Strike (2 AP, Instant)
**Type:** Damage + Interrupt
**Scaling:** 5 base + 50% ATK
**Effect:** Interrupts enemy casts

**Design:** Pure utility. Low damage but instant interrupt. Creates tactical decisions - do you spend 2 AP to stop that enemy Fireball? Usually yes! Demonstrates interrupt mechanic.

**Best Against:** Enemy channeled abilities, long casts
**Useless Against:** Instant cast spam

---

## 🔮 WIZARD ABILITIES

### 1. Arcane Blast (2 AP, Instant)
**Type:** Quick Damage
**Scaling:** 10 base + 120% MAG
**Cast Time:** 0

**Design:** The spam ability. Moderate damage, low cost, instant. This is what Wizards do when they can't afford big spells. Efficient but not flashy.

**Use Case:** Finishing low-health enemies, AP management
**Philosophy:** "I'm out of AP for Fireball, so I'll plink you with this"

---

### 2. Fireball (4 AP, 3-Turn Delayed Cast)
**Type:** AoE Nuke
**Scaling:** 16 base + 150% MAG per target
**Targets:** ALL ENEMIES
**Cast Time:** 3 turns

**Design:** THE classic fantasy spell. Expensive, slow, but hits EVERYONE. If it resolves, it can win the fight. But 3 turns is an eternity - pray your Champion protects you or you'll get interrupted.

**Power Fantasy:** "I will destroy you all... in 3 turns"
**Counterplay:** Enemy can interrupt, focus fire wizard, kill party before it resolves
**Synergy:** Shield Wall makes this uninterruptible

---

### 3. Mana Shield (2 AP, Instant)
**Type:** Self Shield
**Effect:** 20 shield for 3 turns

**Design:** The panic button. Wizard is squishy, this keeps them alive. Instant cast means you can react to threats. 20 shield is significant early game. Demonstrates shield mechanic.

**Use Case:** Enemy targets you, you need to survive
**Trade-off:** 2 AP that could be Arcane Blast damage

---

### 4. Slow Time (3 AP, Instant)
**Type:** Debuff
**Effect:** -3 Speed for 3 turns

**Design:** Crowd control through tempo manipulation. -3 speed is HUGE - it's roughly -30% turn frequency. Turns fast enemies into slow enemies. Demonstrates speed manipulation mechanic.

**Strategic Use:** Slow fast enemies to match your speed, slow enemy before they act
**Synergy:** Your fast allies get even more turns relative to slowed enemy
**High-level play:** Slow the enemy who's about to act, delaying their turn

---

### 5. Arcane Missiles (3 AP, 3-Turn Channel)
**Type:** Channeled Damage
**Scaling:** 7 base + 100% MAG per tick
**Cast Time:** 3 turns channeled
**Total Damage:** ~21 base + 300% MAG (if not interrupted)

**Design:** Sustained DPS. Deals damage EACH TURN for 3 turns. Higher total damage than Fireball (single target) but can be interrupted. Risk/reward between burst and sustain.

**Comparison:** 
- Arcane Blast x3 = ~30 + 360% MAG over 3 turns (safe, 6 AP)
- Arcane Missiles = ~21 + 300% MAG over 3 turns (risky, 3 AP)
**Trade-off:** Cheaper but vulnerable. The DPS option.

---

## ⚕️ CLERIC ABILITIES

### 1. Heal (2 AP, Instant)
**Type:** Single Target Heal
**Scaling:** 14 base + 130% MAG_DEF (combat stat; driven by spirit)
**Cast Time:** 0

**Design:** The fundamental heal. Instant, targeted, efficient. Good value per AP. This is what keeps the party alive. Scales well with **spirit** (via `mag_def` in combat).

**Use Case:** Reactive healing, topping off allies
**Efficiency:** ~7 healing per AP (at 10 MAG_DEF baseline)

---

### 2. Holy Smite (2 AP, Instant)
**Type:** Damage
**Scaling:** 11 base + 130% MAG_DEF
**Cast Time:** 0

**Design:** The "combat medic" ability. Cleric isn't JUST healing - they can fight too. Same cost as Heal, slightly less potency than Wizard damage. Makes Cleric more interesting than "heal bot."

**Philosophy:** Support characters should have options
**Use Case:** Finishing enemies, contributing when party is healthy
**Surprise factor:** Enemies underestimate Cleric damage

---

### 3. Prayer (3 AP, 3-Turn Channel)
**Type:** Party Heal over Time
**Effect:** All allies gain Regenerating (4 HP/turn for 3 turns)
**Targets:** ALL ALLIES
**Total Healing:** 12 HP per ally over 3 turns

**Design:** The AoE sustain heal. Applies a Regenerating status that heals each turn. Can be interrupted, but if it channels successfully, heals the entire party for substantial amounts. Demonstrates channeled mechanic.

**Comparison:**
- Heal x3 = ~42 HP to ONE ally (6 AP, safe)
- Prayer = ~12 HP to ALL allies (3 AP, risky)
**Strategic Use:** When party is at ~60% health, channel this for efficiency
**Vulnerability:** Interrupts waste 3 AP and healing

---

### 4. Haste (3 AP, Instant)
**Type:** Ally Buff
**Effect:** +4 Speed for 3 turns

**Design:** The "enabler" ability. +4 speed is MASSIVE - it's roughly +40% more turns. This is how you make your Champion or Wizard a monster. Demonstrates speed buff mechanic.

**Strategic Use:**
- Haste Wizard → Fireball resolves faster
- Haste Champion → More stuns, more interrupts
- Haste self → More heals
**High-level play:** Haste whoever has the win condition queued

---

### 5. Silence (3 AP, Instant)
**Type:** Debuff
**Effect:** Target cannot cast for 2 turns

**Design:** Hard counter to casters. Prevents ALL casting for 2 turns. Expensive but devastating against Wizard-type enemies. Demonstrates silence mechanic.

**Best Against:** Enemy mages, healers, channelers
**Useless Against:** Melee enemies with only physical attacks
**Tactical:** If enemy has 3-turn channel active, silencing wastes their AP and time

---

## 🧩 STATUS EFFECTS CREATED

### 1. **Stunned** (1 turn)
- Prevents: Actions, Movement, Casting
- **Full lockdown** - the ultimate CC
- **Balance:** Very short duration (1 turn only)

### 2. **Defensive Stance** (2 turns)
- Effect: +5 `def` (physical defense)
- **Survivability** through damage reduction

### 3. **Shielded** (3 turns, 20 shield)
- Effect: Absorbs 20 damage before health
- **Tactical:** Shields break, so stacking not always better
- **Counterplay:** Focus fire to burn through shield

### 4. **Time Slowed** (3 turns)
- Effect: -3 Speed
- **Tempo control** - one of the strongest debuffs
- **Synergy:** Works with turn-based combat perfectly

### 5. **Hastened** (3 turns)
- Effect: +4 Speed
- **Acceleration** - offensive tempo control
- **Power multiplier:** More turns = more abilities

### 6. **Silenced** (2 turns)
- Prevents: Casting only
- **Selective lockdown** - can still use physical attacks
- **Niche:** Hard counter to casters

### 7. **Regenerating** (3 turns, 4 HP/turn)
- Effect: Heals over time
- **Efficient healing** when safe
- **Trade-off:** Doesn't help burst damage situations

### 8. **Fortified** (2 turns, 15 shield + uninterruptible)
- Effect: Shield + cannot be interrupted
- **Ultimate protection** status
- **Unique:** Not dispellable (represents Champion's unyielding wall)

---

## 🎯 ENEMY VARIETY

### Bandit Warrior
- **Combat stats (Enemy resource):** ATK 12, DEF 0, SPD ~5, MAG 0, MAG_DEF 0 (25 HP)
- **Abilities:** Basic Attack, Power Attack
- **Speed:** ~5 (average)
- **AP/turn:** 3 (average)
- **Philosophy:** Balanced melee threat with burst potential

### Bandit Rogue
- **Combat stats:** ATK 10, DEF 0, SPD ~9 (HIGH), MAG 0, MAG_DEF 0 (18 HP)
- **Abilities:** Basic Attack
- **Speed:** ~9 (FAST!)
- **AP/turn:** 3
- **Philosophy:** Glass cannon - many turns, low damage per turn, fragile

### Dark Cultist
- **Combat stats:** ATK 8, DEF 0, SPD ~4, MAG 13, MAG_DEF 8 (16 HP)
- **Abilities:** Dark Bolt
- **Speed:** ~4.5 (slow)
- **AP/turn:** 3
- **Philosophy:** Caster enemy - dangerous but fragile, priority target

---

## 🎲 ENCOUNTER DESIGNS

### Test Fight (test_fight)
- **Enemies:** 1x Bandit Rogue
- **Difficulty:** Easy
- **Purpose:** Learn controls, see turn order, understand AP system
- **Strategy:** Spam abilities, learn timing

### Bandit Ambush (bandit_ambush)
- **Enemies:** 1x Bandit Warrior, 1x Bandit Rogue
- **Difficulty:** Medium
- **Purpose:** Multiple enemies, target priority
- **Strategy:** Kill fast rogue first, tank warrior

### Cultist Ritual (cultist_ritual)
- **Enemies:** 2x Dark Cultist, 1x Bandit Warrior
- **Difficulty:** Hard
- **Purpose:** Caster enemies, AoE value, target priority
- **Strategy:** Fireball the cultists, interrupt their casts, use Silence

---

## 🧠 DESIGN PHILOSOPHY

### 1. **Spectrum of Cast Times**
- ✅ Instant (0 turns): Arcane Blast, Heal, Shield Bash
- ✅ Delayed (2 turns): Heroic Strike, Power Attack
- ✅ Delayed (3 turns): Fireball
- ✅ Channeled (3 turns): Shield Wall, Prayer, Arcane Missiles

### 2. **Spectrum of AP Costs**
- **2 AP:** Spam abilities (Shield Bash, Arcane Blast, Heal)
- **3 AP:** Tactical abilities (Heroic Strike, Haste, Silence, Slow Time, Arcane Missiles)
- **4 AP:** Ultimate abilities (Fireball, Shield Wall)

### 3. **Counterplay Triangles**
- **Long Casts** ← countered by ← **Interrupts** ← countered by ← **Uninterruptible**
- **Channels** ← countered by ← **Interrupts** ← countered by ← **Shield Wall**
- **Casters** ← countered by ← **Silence** ← countered by ← **Dispel** (future)

### 4. **Tempo Manipulation**
- Speed buffs/debuffs actually matter in timeline system
- Slow Time = enemy skip turns
- Haste = ally extra turns
- Creates strategic depth beyond damage numbers

### 5. **Role Definition**
- **Champion:** "I protect and disrupt"
- **Wizard:** "I deal massive damage... eventually"
- **Cleric:** "I keep us alive and accelerate our win conditions"

### 6. **Resource Management**
- AP is scarce (3/turn base)
- Abilities cost 2-4 AP
- Creates interesting "do I spam or save for big ability?" decisions
- Max HP (from constitution and level) makes this decision different per character

---

## 🎮 RECOMMENDED TESTING FLOW

1. **Test Fight** - Learn controls
2. **Bandit Ambush** - Learn target priority
3. **Try Heroic Strike** - See delayed cast
4. **Try Fireball** - See AoE delayed cast
5. **Try Shield Wall** - See channeled protection
6. **Try Prayer** - See channeled healing
7. **Try Interrupt Strike** - Stop enemy Power Attack
8. **Try Slow Time** - Watch turn order change
9. **Try Haste** - Watch ally turns increase
10. **Cultist Ritual** - Put it all together!

---

## 📈 BALANCE NOTES

### Damage Expectations (at level 1, 10 in main stat)
- **Quick damage:** ~10 (Arcane Blast, Shield Bash)
- **Medium damage:** ~11-14 (Holy Smite)
- **Heavy damage:** ~25 (Heroic Strike, Power Attack)
- **AoE damage:** ~16 per target (Fireball)
- **Channeled DPS:** ~7 per turn (Arcane Missiles, ~21 total)

### Healing Expectations
- **Single heal:** ~14 (Heal)
- **HoT:** ~4 per turn (Regenerating, ~12 total)

### Cast Time Balance
- **0 turns:** Safe, flexible, lower value
- **2 turns:** Telegraphed, higher value, some risk
- **3 turns:** Very telegraphed, highest value, high risk

### AP Economy Balance
- **Efficient:** Arcane Missiles (high damage per AP if not interrupted)
- **Standard:** Most instant casts (fair damage per AP)
- **Premium:** AoE abilities (pay for hitting multiple targets)

---

## 🚀 FUTURE EXPANSION IDEAS

These abilities are designed to be extended:

1. **Champion:** Add positioning abilities (Charge, Guard Ally)
2. **Wizard:** Add elements (Ice Slow, Fire DoT, Lightning Chain)
3. **Cleric:** Add Dispel, Resurrect, Divine Shield
4. **All:** Add ultimate abilities (very high AP cost, game-changing)
5. **Items:** Modify existing abilities (Staff reduces Fireball cast time by 1)
6. **Passives:** Permanent status effects (e.g. +2 `def` while equipped)
7. **Combos:** Abilities interact (Haste + Fireball = Instant cast?)

The system is ready for all of this!

---

**TOTAL CREATED:**
- ✅ 8 Status Effects
- ✅ 15 Class Abilities (5 per class)
- ✅ 3 Shared Abilities (enemy attacks)
- ✅ 3 Enemy Types
- ✅ 3 Encounters
- ✅ All assigned and ready to test!

Just build the combat scene UI and you're ready to go!
