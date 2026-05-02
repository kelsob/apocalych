# Combat Design — Official Document

**Status:** Design authority for combat direction.  
**Companion docs:** `COMBAT_SYSTEM_OVERVIEW.md` (what exists today, architecture), `COMBAT_ABILITIES_DESIGN.md` (class ability notes).  
**Last updated:** 2026-04-07 — **Implementation snapshot:** preset hero templates use **slot-only** loadout (`weapon_slot_a` / `weapon_slot_b`, no legacy `weapon` field), **`duplicate_equipped_weapons_for_run()`** on instantiate, starter **weapon** + **basic attack** content under `resources/weapons/starters/` and `resources/abilities/starters/`. **§6.5–6.6** add the **primary stat contract** and **Threat** targeting system (design authority; code may lag). Roadmap §14 / next steps refreshed below.

---

## 1. Purpose

This document defines **what combat should be** (goals, rules, vocabulary) and **how it relates to the current codebase**, so design, content, and implementation stay aligned.

---

## 2. Core Philosophy

Combat should be **simple at the foundation** but **emergent** through interactions, behaviors, and context.

Goals:

- **Player choice matters moment-to-moment** — not only build optimization.
- **Situational variety** — same party, different problems.
- **Non-standard outcomes** — flee, surrender, capture, protect NPCs, survive X turns, not only “clear the board.”
- **Narrative and event integration** — combat results feed story and world systems.

We are **not** trying to reinvent classic turn-based combat wholesale; we are layering readable systems that support story and tactics.

---

## 3. Design Pillars (Stable Vocabulary)

| Pillar | Meaning |
|--------|--------|
| **Readable** | Players can infer *why* something happened (damage type, trait, status). |
| **Interaction-first** | Depth comes from *states and traits*, not from opaque stat piles. |
| **Data-driven** | Abilities, enemies, statuses live in resources; code interprets rules. |
| **Minimal but expressive** | Few core axes; combine them rather than adding one-off rules. |

---

## 4. Turn Structure

### 4.1 Target model (design intent)

**Party phase turn:**

- The player controls **all party members** during a **single shared turn** (a “round” or “phase”).
- Actions consume **AP** from a **shared pool** and/or **per-character** pools (see §4.3 — *open decision*).
- The player may act with **any** character, in **any order**, until AP is exhausted or the player **ends the phase**.

**Why:** Flexible sequencing, combo setups, and clear “this is our turn” pacing without a fixed per-hero initiative order *inside* the player round.

### 4.2 Current implementation (audit)

The shipped loop is **different**:

- **Speed-based timeline:** Each combatant gets individual turns; faster stats ⇒ more frequent turns (`CombatTimeline`).
- **One action per player turn slot:** After `player_cast_ability` succeeds, `CombatController` ends the turn; the UI does not offer multiple casts in one timeline slot. AP **banks** across rotations for expensive abilities, but **does not** simulate a multi-action party phase.
- **Enemy turns:** One ability per enemy turn (random affordable ability in `_execute_ai_turn`).

**Gap:** The party-phase model in §4.1 is **not** implemented. Moving toward it is a **primary architectural decision** (see §11.1).

---

## 5. Resource Model (AP)

### 5.1 Design intent

- AP should fund **multiple meaningful choices** per party phase (once §4.1 exists), or per character turn if we keep a hybrid.
- Costs should make **cheap fillers** vs **finishers** vs **setup** distinct.

### 5.2 Current implementation

- `CombatantStats`: `max_ap` (default 10), `base_ap_per_turn` (3 for heroes and enemies from `Enemy.create_combat_stats()`), regeneration at `start_turn()`.
- Constitution / narrative stats **do not** currently modify AP regen in code (`COMBAT_SYSTEM_OVERVIEW.md` notes this).

---

## 6. Combat Axes

### 6.1 Damage types (design)

| Type | Mitigation |
|------|------------|
| **Physical** | Reduced by **armor** (implementation: flat `def` or future %/armor stat). |
| **Magical** | Reduced by **resistance** (implementation: `mag_def` or dedicated resist). |
| **True** | Ignores defenses — **rare**, for finishers or special cases. |

### 6.2 Attack / range types (design)

| Concept | Role |
|---------|------|
| **Melee** | Requires proximity (when positioning exists) or “front line” eligibility. |
| **Ranged** | Works at distance; may ignore some melee-only responses. |

### 6.3 Current implementation (stats & damage pipeline)

- **Stats:** `atk`, `def`, `spd`, `mag`, `mag_def` on `CombatantStats`.
- **Ability damage:** Hits go through **`CombatDamageResolver`** + **`DamagePacket`** + **`AbilityEffect.get_effective_damage_kind()`** (magical effects use `mag_def` where applicable). Legacy notes in older docs may predate this pipeline.
- **True damage:** Supported via damage kind on effects / packets where wired.

### 6.3.1 Proposed: armor, critical hits, and glancing blows (not implemented)

**Intent:** Make **armor** (`def`) do more than flat subtraction: it should also **reduce the chance to suffer a critical hit** (and, symmetrically, highly armored or defensive attackers might **crit less often** if we tie crit to agility or a dedicated stat later). Separately, introduce **glancing blows** (WoW-style “anti-crit”): a low roll or mitigation context turns a would-be normal hit into a **glancing** hit that deals **reduced damage** (e.g. **50%** of the post-mitigation amount, tunable), distinct from **block**/**dodge** (full avoid) and from **crit** (bonus damage).

**Why:** Adds texture to long fights, rewards armor stacking without only inflating HP, and gives designers a third outcome beside hit/miss and crit.

**Implementation sketch (when ready):** After accuracy / targeting resolves “hit,” roll **outcome band**: miss → glance → normal → crit, with armor (and optionally agility) shifting weights. Apply **glance multiplier** before or after flat mitigation per balance needs; document the order in `CombatDamageResolver` so traits and statuses can hook the same pipeline.

### 6.4 Formation, rows & targeting (implemented)

**Goal:** Simple **front / back** zones per side, readable targeting rules, and hooks for stealth, flyers, grounding, and repositioning — **data-driven**, centralized in **`CombatTargetRules`**, minimal special cases in UI.

| Piece | Role |
|--------|------|
| **`CombatRow.Kind`** | `FRONT`, `BACK` — runtime row on **`CombatantData.formation_row`**. |
| **Source of truth (start of combat)** | **`HeroCharacter.combat_formation_row`**, **`Enemy.formation_row`** (exports). |
| **`formation_row_base`** | Snapshot used when **grounded** expires (restore row). Updated when the character **voluntarily moves**, is **pushed/pulled**, or **swaps** rows. |
| **`Ability.attack_range`** | **`MELEE`** vs **`RANGED`** (`AttackRangeProfile`). Default **`RANGED`** so existing ability assets stay valid until content is tagged. |

**Who is a valid target (opponents)?** — After building a candidate list, **`CombatTargetRules.filter_by_attack_profile()`** runs for offensive modes: **`SINGLE_ENEMY`**, **`ALL_ENEMIES`**, **`RANDOM_ENEMY`**. Ally/self heals and **`ALL_COMBATANTS`** do **not** use the same row-blocking rule set (see code for exact scope).

**Rules (summary):**

- **Ranged** abilities: may target any opponent row; may hit **flying** targets.
- **Melee** abilities: cannot target **effective flyers**; cannot target an enemy in the **back** row while **any other living** unit on **that enemy’s side** is in the **front** row — **unless** the **caster** has **`stealth`** (status id **`stealth`**), which bypasses that front-line block for **melee vs back row** (does **not** ignore **flying**).
- **Flying:** **`Enemy.TAG_FLYING`** on the resource; **`CombatantData.is_effective_flying()`** is false while **`grounded`** is active.

**Grounding (innate flyers only):**

- Effect type **`APPLY_GROUNDING`** applies a **`StatusEffect`** (typically **`resources/statuses/grounded.tres`**, **`status_id` = `grounded`**). **`CombatantStats.apply_status()`** moves innate flyers to **front** when grounded is applied; on remove, row restores from **`formation_row_base`**. Duration = status **`base_duration`** (stack behavior per resource).

**Voluntary row change (“Move”):**

- Shared ability **`resources/abilities/shared/move.tres`** is **injected** onto every combatant if missing (`ability_id` **`move`**, **`MOVE_FORMATION`** effect, **SELF**). Costs AP per resource (default full-turn style). **Blocked while `grounded`** (voluntary only). Enemies: **`Enemy.preferred_zone`** (**Front / Back / Indifferent**); AI tries **Move** first when biased and in the wrong row, and does **not** randomly spam Move when indifferent.

**Forced row change:**

- **`PUSH_TO_BACK`** / **`PULL_TO_FRONT`** — effect types on **`AbilityEffect`**; call **`CombatantData.force_to_back_row()`** / **`force_to_front_row()`** (updates **`formation_row_base`**). **Not** blocked by grounded (forced movement ≠ voluntary Move).

**Best practices (content & code):**

- Treat **`status_id`** strings as **contracts**: **`grounded`**, **`stealth`** must match **`CombatantData`** expectations and **`CombatTargetRules`**.
- Tag **true melee** abilities **`attack_range = MELEE`** in the inspector.
- For “ground then hit” in **one** instant resolution, order effects **grounding before damage** on the ability.
- Set **`Enemy.preferred_zone`** for predictable AI positioning alongside **`formation_row`** spawn placement.

---

## 6.5 Primary attribute contract (heroes)

**Authority:** This section is the **target** behavior for the seven primaries on **`HeroCharacter`**: `strength`, `agility`, `constitution`, `intellect`, `spirit`, `charisma`, `luck`. Implementation today still uses an older mapping in **`get_combat_core_stats()`** (e.g. STR→`atk`, AGI→`spd`, INT→`mag`, SPR→`mag_def`, CON→`def`); migrating code and content to match this contract is **intentional follow-up**.

**Design goal:** **Mewgenics-simple** — each stat should have **one obvious job** (at most two where noted), readable on the sheet. **Abilities** may declare **scaling overrides** (e.g. a melee skill that scales off **DEX** instead of **STR**) so kits stay flexible without bloating the stat list.

| Stat | Role (combat + character sheet) |
|------|----------------------------------|
| **Strength** | **Melee damage** (category: melee attacks and melee-tagged abilities). **Block value** (mitigation or proc against physical — exact formula TBD). Individual abilities may **override** default scaling to use another stat. |
| **Agility** | **Ranged damage** (category: ranged attacks and ranged-tagged abilities). **Dodge** (avoidance vs eligible hits — stack with statuses as needed). Per-ability **scaling overrides** allowed (e.g. a ranged skill that scales off **STR**). |
| **Intellect** | **Magical damage** in **all** forms (melee-range magic, ranged magic, pure spells): one unified “spell power” bucket unless an ability overrides. Optional / future: **spell block** or **spell suppression** hook (design space: mirror physical block at a different mitigation layer). |
| **Constitution** | **Max health** only (level-up and out-of-combat scaling should stay legible — e.g. simple linear or tiered formula). |
| **Spirit** | **Magic regen per turn** (mana / arcane resource — align naming with whatever pool **Charisma** caps; if the shipped resource remains **AP**, map this design to **AP regen per turn** until a dedicated mana bar exists). **Spell resistance** (mitigation vs magical damage — may fold into or replace current `mag_def` semantics). |
| **Charisma** | **Starting and maximum mana** (or **max AP + starting AP** in combat if mana is not yet split from AP — **one** pool, two knobs: how much you **start** with vs **cap**). |
| **Luck** | **Critical hits** (and crit mitigation if we add symmetry). **All RNG** the player cares about: loot/event rolls where appropriate, proc chances, variance bands — **document** which systems read LUK so nothing feels “hidden.” |

**Ability scaling overrides:** Default rule: **melee physical** scales with **STR**, **ranged physical** with **DEX**, **magical** with **INT**. Any **`Ability`** (or effect) can specify **`scaling_stat`** / override so designers can ship exceptions without new core stats.

**Weapons:** Weapon tier/enchant damage should **stack** with the correct **category** (melee vs ranged vs magic) so gear and stats don’t double-count the same axis unintentionally — tune bases so total output stays in band.

---

## 6.6 Threat (turn-based “aggro”)

**Intent:** Bring **MMO-style encounter tension** into **turn-based** play: someone **voluntarily or accidentally** pulls attention; **tanks** want to sit high; **glass cannons** want to stay **low** or **negative** so the AI prefers the beefier targets.

**Core idea:** **Threat** is a **simple, stackable value** (buff / debuff / resource) on each combatant, modified by abilities, passives, and gear.

- **Higher threat** ⇒ **more likely** to be chosen when an enemy resolves **“who do I hit?”** (single-target, or weighted in **random** / **AoE** tie-breaks).
- **Lower or negative threat** ⇒ **less likely** to be targeted — **negative threat** is allowed: “below baseline attention,” **not** just “zero aggro.”
- **Generating threat** is **putting a target on your back**; **dumping threat** (self or ally) is a **tactical** tool.

**Rules of thumb (design, not yet full spec):**

- **Stacks or integer threat:** Easiest to show in UI (“Threat: +12” / “Threat: −3”). Alternative: **tiers** if you want less arithmetic.
- **Enemy behavior:** Default AI uses **threat as a weight** alongside **range**, **row**, **stealth**, **marks**, etc. Bosses may use **ignore threat** phases or **fixate** (forced target) as exceptions — **data-driven** per encounter.
- **Tank fantasy:** Taunts **spike threat** or set **minimum threat vs party**; **mitigation** and **self-heal** might add small passive threat where it fits fantasy.
- **Risk/reward:** High damage or healing from backliners might **generate threat** so **positioning and cooldowns** matter even without real-time positioning.

**Implementation sketch (when ready):** Store threat on **`CombatantStats`** or as a **`StatusEffect`** with a numeric **`threat_delta`** / stacks; **`CombatController`** or a dedicated **`ThreatResolver`** adjusts values when abilities resolve; **enemy AI** reads the threat list when picking **`RANDOM_ENEMY`** / single-target skills. **Document** every ability that adds/removes threat in ability copy or data flags.

**Why it’s strong for this project:** Many systems (damage, healing, buffs, **who dies first**) can be **balanced around** “how much attention did you draw?” without adding five new resources. It reinforces **readable** decisions: *I taunted, so I expect the hits*.

---

## 7. Enemy (and PC) Identity — Traits

### 7.1 Design

Enemies (and optionally PCs) should express identity through **traits** more than raw numbers. Examples (illustrative, not exhaustive):

| Trait | Tactical meaning |
|-------|-------------------|
| **Armored** | Strong vs physical; encourages magic/armor shred. |
| **Spectral** | Resistant or immune to physical; weak to magic. |
| **Flying** | Cannot be hit by melee until **grounded**. |
| **Massive** | Resistant to control / knockback. |
| **Regenerating** | Heals over time unless **burn**, **bleed**, or **suppress heal**. |
| **Unstable** | On death, triggers explosion, summon, or curse. |

Traits are **build checks** and **answer keys** for ability design.

### 7.2 Current implementation

- **`Enemy` resource:** Per-tag booleans (`tag_beast`, `tag_humanoid`, … `tag_fel`) in a **Creature tags** group; **`Enemy.get_creature_tag_mask()`** builds the bitmask for combat. **Spectral** and other tag rules are honored in the **damage** pipeline via **`CreatureTagDamageRules`** where wired; not every trait row in §7.1 is fully implemented.
- **Flying:** **`TAG_FLYING`** drives **`innately_flying()`** / **`is_effective_flying()`**; melee cannot target flyers until **`grounded`** (or similar) removes airborne targeting — see §6.4.
- **StatusEffect:** `StatusType.IMMUNITY` exists but is not wired as a general “immune to physical/magic” pipeline for all cases.

**Gap:** Remaining trait rows from §7.1 (e.g. **Massive**, **Unstable** on death) are **partially** or **not** implemented — extend **`CreatureTagDamageRules`** and encounter logic as needed.

---

## 8. Abilities

### 8.1 Design principles

Every ability should do **at least one** of:

- Deal damage / heal (with clear type).
- Apply or remove a **status** that changes decisions.
- **Interact with a trait** (ground flying, break armor, reveal hidden).
- **Change behavior** (interrupt, silence, fear, **reposition**: voluntary Move, push/pull, grounding — see §6.4).

**Pure damage** abilities should be **limited**; most should change **state** or **situation**.

### 8.2 Unified property model (target schema)

**Core:** cost (AP), target scope (self / ally / enemy / all), **range band** (melee / ranged — `Ability.attack_range`), **damage type**, power / scaling, **weapon requirement** via **`required_weapon_type_ids`** (see §8.4), not by hand slot name.

**Execution:** timing (`INSTANT` / `DELAYED_CAST` / `CHANNELED` — matches `Ability.AbilityType`), targeting (single / AoE), durations, movement (push/pull/dash — future).

**Interaction:** ignore armor/resist, interrupt, modify traits, conditional bonuses, **non-lethal** flag.

### 8.3 Current implementation

- **`Ability` + `AbilityEffect`:** Rich enums for targeting and effect types.
- **`CombatController._apply_ability_effects` resolves:** `DAMAGE`, `HEAL`, `APPLY_STATUS`, `APPLY_GROUNDING`, `MOVE_FORMATION`, `PUSH_TO_BACK`, `PULL_TO_FRONT`, `INTERRUPT_CAST`.
- **Declared but not resolved in controller (yet):** `RESTORE_AP`, `DRAIN_AP`, `SHIELD`, `DISPEL`, `SPAWN`, `LIFESTEAL`.

Many `.tres` abilities may still reference unimplemented effect types; **verify** in controller or effects **do nothing** silently.

**Rogues / stealth:** Example self-buff ability + status: **`resources/abilities/rogue/stealth.tres`**, **`resources/statuses/stealth.tres`** (`status_id` **`stealth`**), referenced from **`rogue.tres`** class abilities.

**Loadout & basics:** See **§8.4.6–8.4.7**. Party flow is **`HeroCharacter` templates** only (`HeroDatabase.instantiate_for_run` / **`PartySelectMenu`**). **Starter weapons and allow-lists live on each hero `.tres`**, not on **`Class`** — **`Class.weapon_type`** is **display / flavor** (e.g. UI label) until you choose to sync it with real gear. Combat injects **`Weapon.granted_basic_attacks`** ahead of class specials (strip class **`basic_attack`** when weapons supply basics). **`Weapon.create_default()`** + **`basic_attack.tres`** remain the **fallback** if a template ever has an empty slot A after sanitize. **Blacksmith** still upgrades **slot A** only; second row / slot B in **character UI** is open (§8.4.7). Deprecated **`CharacterSelect`** UI script is a stub — remove the scene when convenient.

### 8.4 Loadout slots, weapon-granted basics & special ability cadence

**Goals:** Keep the combat bar **readable** (Mewgenics-inspired cadence), make the **basic attack** the **spine** of the kit (FF-style “Attack,” unique per class / weapon), and support **hybrid gear** (e.g. hunter **bow** + **twin daggers** as one logical “dual-wield” item) without ambiguous “main hand” fiction in rules.

#### 8.4.1 Loadout slots (A and B)

- Each hero has **two loadout slots** for weapons: **slot A** and **slot B** (names are **positional only** in UI; rules use **weapon type ids**, not “main/off”).
- **Two-handed and dual-wield (single entity):** A **two-hander** or a **dual-wield bundle** (e.g. rogue **twin daggers** on slot A only) uses **`occupies_both_slots`** — **one** inventory resource **occupies both slots**. **Slot B remains visible** in UI but **greyed / blocked** while slot A holds that item. (*Hybrid* hunter is the opposite: **bow + dagger pair** as **two** items in A and B — see example below.)
- **Examples:**
   - **Hunter (implemented on `unlockable_sellsword.tres`):** slot A = **bow** (`occupies_both_slots = false`); slot B = **dagger pair** (`occupies_both_slots = false`) — **two items**, **two** `granted_basic_attacks` (e.g. **Bow Shot** + **Dagger Strike**). *Rogue* twin daggers are different: **one** resource in slot A with **`occupies_both_slots = true`**, slot B disabled in data.
  - **Tank (implemented on `starter_human_champion.tres`):** slot A = **sword**; slot B = **shield** (two items).
  - **Cleric / wizard staffs:** slot A = **staff** (`occupies_both_slots`); slot B **cleared / disallowed** in template data.

#### 8.4.2 Basics vs specials

- **Basic attacks** are normal **`Ability`** resources. **Shared fallback:** **`resources/abilities/shared/basic_attack.tres`**. **Starter variants (shipped):** **`resources/abilities/starters/`** — e.g. **`basic_sword_strike`**, **`basic_bow_shot`**, **`basic_dagger_strike`**, **`basic_staff_strike`** — referenced from **`resources/weapons/starters/`** via **`granted_basic_attacks`**.
- **Weapon-granted:** Each **weapon** (or dedicated **loadout item** resource) **references** the **`Ability`(ies)** it grants as basics — typically **one** basic per equipped weapon; a **hybrid** loadout can grant **two** basics (hunter).
- **One basic use per character turn** (current **speed timeline** model): a player may have **two** basics on the bar (hunter) but **using either** consumes the **basic action** for that turn — **not both**.
- **Special abilities cadence (run / meta):** Start with a **small random subset** of specials; unlock **at most ~2–3** more over a run; **hard cap of 4** specials; learning a new special **replaces** an old one (player choice of which to drop, when specified). **Basics do not count** toward the 4 and **cannot** be replaced by the “learn ability” flow — but **swapping equipment** can **change** which basic **`Ability`** is granted.
- **UI:** Basics are **visually grouped** or **styled** so they read as a family; exact dividers are **presentation** (author in scenes).

#### 8.4.3 Requirements: weapon **types**, not slots

- Abilities declare **`required_weapon_type_ids`** (or equivalent): e.g. **`["bow"]`**, **`["daggers"]`**, **`["staff"]`**. Validation checks **equipped** weapon(s) for a matching **`weapon_type_id`** on the item resource — **not** “slot A.”
- **Disarm** (if added later): disable abilities whose required types are **not** satisfied by current gear; dual-slot gear can define which types are “active.”

#### 8.4.4 Who may equip what

- **Narrow allow-lists** per hero (or class template): e.g. arrays of **allowed item ids** or **allowed weapon type ids** per slot. Narrative can still say “only our champion uses tower shields”; **data** remains explicit so UI and validation do not guess.

#### 8.4.5 Row context (basics and abilities)

- **Ranged basic in front row** is allowed; **risk** is **formation** (exposure to melee targeting), not a hard ban unless an ability says otherwise. **Future** hooks (accuracy, crit taken) are optional (see §6.4).
- Abilities may later expose **front / back** text variants (copy or mechanical branches); not required for the first loadout implementation slice.

#### 8.4.6 Schema (code + pending)

| Piece | Shape | Status |
|--------|--------|--------|
| **`Weapon`** | `weapon_type_id`, `occupies_both_slots`, `granted_basic_attacks: Array[Ability]`; tier/enchant unchanged | **In code** (`Weapon.gd`) |
| **`HeroCharacter`** | `weapon_slot_a`, `weapon_slot_b`; `allows_weapon_slot_b`; `duplicate_equipped_weapons_for_run()`, `apply_loadout_constraints()`, `get_total_weapon_damage_bonus()`, `ability_allowed_by_equipment()` | **In code**; **allow-lists** on **preset** templates (**done**); custom picker heroes still **TBD** (see §14.1 step 6) |
| **`Ability`** | `required_weapon_type_ids`, `is_basic_attack` | **In code**; shared **`basic_attack.tres`** sets **`is_basic_attack = true`** |
| **`CombatController`** | **`basic_attack_used_this_turn`** via **`CombatantData`**; **`can_cast_ability_this_turn`** checked in **`player_cast_ability`**, **`_execute_ability_cast`**, AI pick | **Done** |
| **`CombatantData`** | **`_prepend_weapon_granted_abilities`**, **`_filter_abilities_by_equipment`**, **`_strip_class_basics_for_weapon_grants`** | **Done** |
| **`CombatantStats`** | ATK bonus from **`get_total_weapon_damage_bonus()`** | **Done** |
| **`HeroCharacter` allow-lists** | **`allowed_weapon_type_ids_slot_a/b`**, **`sanitize_weapon_slots_to_allow_lists()`** | **Done** (preset starters filled; empty lists = no restriction) |
| **Starter content** | `resources/weapons/starters/*.tres`, `resources/abilities/starters/*.tres`, hero templates in `resources/heroes/starter_*.tres` + `unlockable_sellsword.tres` | **Done** for listed presets |

#### 8.4.7 UI recommendations (you implement in scenes)

- **Second weapon row:** Duplicate or mirror the equipment block for **slot B**; when **`get_weapon_slot_a().occupies_both_slots`** (or slot A is a two-hander / dual bundle), **disable or grey** the slot B display and show a short label (“Two-handed” / “Dual wield”).
- **Combat ability bar:** Optionally style **`CombatAbilityOption`** instances whose **`Ability.is_basic_attack`** is true (tint, icon, or group under a “Basics” header). No script changes required if you only adjust theme / child nodes on instanced buttons.
- **Blacksmith:** Currently upgrades **slot A** only; ATK label uses **total** weapon bonus. When you add true dual-weapon upgrades, add a second upgrade control bound to **`weapon_slot_b`**.

**Note:** **`HeroCharacter`** loadout is **`weapon_slot_a` / `weapon_slot_b` only** (no separate legacy weapon field).

---

## 9. Status Effects & Combat States

### 9.1 Design

States drive depth: **stunned**, **grounded**, **exposed** (damage amp), **marked**, **panicked** / **fear**, **channeling** (interruptible), **silenced**, etc.

They should be **readable**, **composable**, and **hooked into AI** (e.g. cowardice at low HP).

### 9.2 Current implementation

- **`StatusEffect`:** Durations, stacking, stat mods, ticks (DoT/HoT/AP), shields, stun/silence/root/fear flags, `bypass_defense` for bleed-like ticks, dispel flag.
- **Processing:** Per-turn in `CombatantStats.process_status_effects()`; stun prevents actions; fear exists as a type (flee behavior **not** fully tied in combat AI).
- **Combat-critical ids:** **`grounded`** and **`stealth`** are referenced by **`CombatantData`** / **`CombatTargetRules`**; ship matching **`resources/statuses/*.tres`** (or duplicates with the same ids).

### 9.3 Status inventory (content vs code)

| Status (resource / id) | In `resources/statuses/` | Works today (summary) | Gaps |
|------------------------|---------------------------|------------------------|------|
| **Bleed** (`bleeding`) | yes | DoT each turn; **`bypass_defense`** → physical tick skips `def` in resolver | — |
| **Poison** (`poisoned`) | yes | DoT each turn; uses **`CombatDamageKind`** on tick (default **physical**) | No dedicated “nature/poison” kind yet; tune `tick_damage_kind` / future enum |
| **Stun** (`stunned`) | yes | **`prevents_actions`** (lose turn) | `status_type` on `.tres` may not match enum (cosmetic); flags are what matter |
| **Blind** (`blinded`) | yes | **`stat_modifiers` atk** apply | **`blind_miss_chance`** is **not read** anywhere in hit resolution — only the atk penalty applies unless wired |
| **Grounded** (`grounded`) | yes | Blocks voluntary **Move**; flyer rules; formation snap for innate flyers | — |
| **Silence** (`silenced`) | yes | **`prevents_casting`** | — |
| **Root** (`rooted`) | yes | **`prevents_movement`** set | **Move / push/pull ignore `prevents_movement`** in code — root does **not** actually block row change |
| **Fear** (`feared`) | yes | **`prevents_actions`** (like stun for turns) | No AI “flee” / morale tie-in |
| **Shield** (`shielded`) | yes | **`SHIELD`** absorbs in `apply_resolved_hit` | Applying via **`AbilityEffect.SHIELD`** is **not** wired in `CombatController` (only direct `apply_status` / content) |
| **Corroded** (`corroded`) | yes | **`def`** penalty via stat cache | Design “**exposed**” / vuln could be this or a separate **`mag_def`** shred |
| **Knockdown**, **slowed**, **weakened**, **hastened**, **inspired**, **fortified**, **enraged**, **regenerating**, **defensive stance**, **berserk**, **time slowed**, **stealth** | yes | Buff/debuff via **stat_mods** and/or ticks where set | **Regen vs bleed/poison “suppress heal”** from §7.1 is **not** implemented |
| **Reflect** | no | — | **Not ideated as a resource**; would need thorns / % reflect / shield-like rules |
| **Disarmed** | no | — | Would need **`prevents_*`** for weapon abilities or tag on abilities as “martial” |
| **Exposed** (armour / vuln) | no (use **corroded** or add) | — | Design doc name; closest content is **corroded** |

**`AbilityEffect` gaps:** `RESTORE_AP`, `DRAIN_AP`, `SHIELD`, `DISPEL`, `SPAWN`, `LIFESTEAL` exist on the resource enum but **are not handled** in `CombatController._apply_ability_effects` — abilities using only those lines **do nothing** until wired.

---

## 10. Enemy Behavior & Intent

### 10.1 Design

Enemies act toward **goals**, not only random damage:

| Archetype | Behavior sketch |
|-----------|-----------------|
| Hunter | Prioritize low HP or squishy targets. |
| Protector | Bodyguard, buff allies, intercept. |
| Coward | Flee or defensive at low HP. |
| Fanatic | Never flee; may self-buff or suicide rush. |
| Assassin | Backline / healer focus. |
| Summoner | Stall while spawning or empowering adds. |

### 10.2 Current implementation

- **`Enemy.ai_behavior`:** `"Aggressive" | "Defensive" | "Balanced" | "Support"` — **not used** in `_execute_ai_turn`.
- **`Enemy.preferred_zone`:** **Front / Back / Indifferent** — used so AI **prioritizes Move** when a **Front/Back** bias does not match current **`formation_row`** (see §6.4). Indifferent enemies do not randomly waste turns on Move.
- **AI (baseline):** Otherwise picks a **random** affordable non-Move ability and random / full-AoE targets.

**Gap:** Rich archetypes (§10.1) and **`ai_behavior`** — still to be wired; formation preference is a first step.

---

## 11. Alternative Objectives & Outcomes

### 11.1 Design

Not every fight is elimination:

- Survive N **party phases** or timeline turns.
- Kill or protect a **specific** unit.
- Prevent escape / ritual completion.
- **Escape** (flee already exists at UI level).
- **Capture / non-lethal** — requires damage rules and morale.

### 11.2 Current implementation

- **Victory:** All enemies dead. **Defeat:** All players dead. **Flee:** Implemented (`attempt_flee` succeeds immediately; rewards adjusted).
- **`CombatEncounter`:** Can be extended for objectives; not fully driven by a unified objective evaluator in code (verify per your encounter resources).

---

## 12. Morale, Non-Lethal, Capture

### 12.1 Design

- **Morale** (lightweight): thresholds for panic, surrender, retreat — ties to **events** and **rewards**.
- **Non-lethal:** flag on ability or “subdual” damage that cannot kill (drops to 1 HP or “downed” state).

### 12.2 Current implementation

- **Morale / capture:** Not implemented as first-class systems.
- **Fear** status exists; **flee** is a player button, not an enemy morale outcome.

---

## 13. World & Event Integration

- **Weather → combat:** `CombatController` reads `WeatherManager.get_active_combat_weather_modifiers()` but applies modifiers only as a stub log when non-empty.
- **Post-combat:** `combat_ended` → `Main.on_combat_scene_fully_ended` — good hook for narrative branching.

Design intent: **combat outcomes** (fled, captured, protected NPC died) should map cleanly to **event variables** (align with `EVENT_DESIGN.md` patterns).

---

## 14. Implementation Roadmap (Suggested Phases)

Phases are ordered by **dependency** and **player-visible value**.

| Phase | Focus | Outcome |
|-------|--------|--------|
| **A** | **Damage pipeline** | Respect `is_magical` → `mag_def`; add true damage flag; optional trait/tag resists. |
| **B** | **Complete `AbilityEffect` resolution** | Wire RESTORE_AP, DRAIN_AP, SHIELD, DISPEL, SPAWN, LIFESTEAL or cut from enum until ready. |
| **C** | **Trait resolution** | Central function: given effect + target, apply trait rules (Spectral, Flying, etc.). |
| **D** | **Party phase vs timeline** | Decide model (§11.1); refactor `CombatController` + UI for multi-action party turns if adopted. |
| **E** | **Enemy AI** | Map `ai_behavior` + tags to target/ability scoring. |
| **F** | **Objectives & morale** | Encounter objectives, non-lethal, morale thresholds. |
| **G** | **Positioning (logic done)** | Row/range/targeting rules live in **`CombatTargetRules`** + data; **scene/UI** can stay minimal until you add visuals. |
| **H** | **Loadout & weapon types** | **Largely done:** template-only party, slot-only **`HeroCharacter`**, per-run weapon dup, **`Weapon.contributes_attack_bonus`** (shields), starter weapons + hero assignments + allow-lists. **Remaining:** equip validation in **vendor**/trade if not already strict; second-slot **Blacksmith** + dual-weapon details UI (§8.4.7). |
| **I** | **Basics & gating** | **Done** for combat core: gear filter, one basic per turn, weapon-granted basics, starter basics per weapon. **Remaining:** meta **specials cap** (Phase **J**); ongoing **`attack_range`** / **`required_weapon_type_ids`** hygiene on new class abilities (section 16). |
| **J** | **Specials cadence (meta)** | Run/progression: starter specials subset, unlocks, **cap 4**, replace-on-learn; **UI** lists basics separately from specials (scene authoring). |

### 14.1 Loadout & basics — suggested implementation order (code)

Ordered steps to reduce rework:

1. **`Weapon` / item schema** — ~~Add **`weapon_type_id`**, **`occupies_both_slots`**, **`granted_basic_attacks`**, **`contributes_attack_bonus`**.~~ **Done** (`Weapon.gd`). ~~Canonical **`weapon_type_id`** strings~~ — see **section 16.0** (registry).
2. **`HeroCharacter`** — ~~Slots A/B only, **`apply_loadout_constraints()`**, **`allows_weapon_slot_b`**, **`get_total_weapon_damage_bonus()`**, **`duplicate_equipped_weapons_for_run()`**.~~ **Done.** *Next:* any **equip / trade** path should call **`sanitize_weapon_slots_to_allow_lists()`** (or equivalent) so **`allowed_weapon_type_ids_slot_*`** never drifts silently.
3. **`Ability`** — ~~**`required_weapon_type_ids`**, **`is_basic_attack`**.~~ **Done**; validation via **`HeroCharacter.ability_allowed_by_equipment(ability)`**.
4. **`CombatantData` / party build** — ~~Inject **`granted_basic_attacks`**, strip class basics, filter by gear, **Move** last.~~ **Done.**
5. **`CombatController`** — ~~**`can_cast_ability_this_turn`**, set **`basic_attack_used_this_turn`** in **`_execute_ability_cast`**, clear in **`start_turn`**.~~ **Done.**
6. **Content pass** — ~~**Preset** hero templates + starters + class ability **`attack_range`** / **`required_weapon_type_ids`** baseline (champion / cleric / rogue PC set; see section 16.0).~~ **Done** for current shipped PC roster; repeat section 16 when adding classes or abilities.
7. **UI** — §**8.4.7** (scene authoring): second weapon row on **character details**, basic styling on bar, **Blacksmith** control for **`weapon_slot_b`** when you want dual upgrades.
8. **Meta / specials cap** — Replace-on-learn and cap-of-4 in **recruitment / event / level-up** after combat basics are stable (**Phase J**).

**Where we are:** Steps **1–6** are **shipped** for template-based party + current PC abilities. **Next:** **step 7** (UI + Blacksmith B), **Phase J** (specials meta), then **Phase A/B** (resolver honesty) per product priority.

Dependencies: **H → I** are in good shape; **J** can trail once UI catches up.

---

## 15. Open Questions (Need Product Answers)

1. **Party phase vs speed timeline:** Do we **replace** per-hero timeline slots with one party phase per “round,” or **hybrid** (timeline for enemies only, party acts as a block)? This drives UI and `CombatController` structure.
2. **AP model:** Strictly **shared** party pool, **per-character** only, or **hybrid** (shared tactical pool + character ultimates)?
3. **Magical vs physical on sheet:** Is `mag_def` enough, or do we want **elemental** splits (fire/holy/void) in v1?
4. **Non-lethal and ethics:** Required for ship milestone, or post-MVP?
5. **Difficulty:** Should AI cheat information (see exact HP) or use heuristics (wounded / healthy)?

---

## 16. Content authoring — registry & checklist

### 16.0 Canonical `weapon_type_id` strings (use on `Weapon`, `HeroCharacter` allow-lists, `Ability.required_weapon_type_ids`)

| `weapon_type_id` | Typical use (examples) |
|------------------|------------------------|
| **`sword`** | Champion sword, melee sword basics |
| **`shield`** | Off-hand shield; shield-bash-style specials |
| **`bow`** | Hunter / ranged basics |
| **`daggers`** | Rogue twin bundle, hunter off-hand daggers, dagger basics |
| **`staff`** | Cleric / wizard two-hand staff (starters use this for divine casters even if **`Class.weapon_type`** still says “Mace” — align class display later if desired) |

**Rules**

- Add new ids **here and in code comments** (`Weapon.gd`) when you introduce a new weapon family; keep **lower_snake** or single-word consistency.
- **`HeroCharacter`** **allow-lists** and **`weapon_slot_*`** assignments are the **source of truth** for what a **named hero** equips. **`Class`** does **not** auto-equip weapons.
- **PC class abilities (baseline pass, 2026-04):** Champion weapon attacks set **`attack_range = MELEE`** and **`required_weapon_type_ids`** **`["sword"]`** or **`["shield"]`** as appropriate; cleric kit uses **`["staff"]`**; rogue **Stealth** uses **`["daggers"]`**; wizard arcane kit stays **`required_weapon_type_ids` empty** (innate spells). Enemy abilities are unchanged by this pass.

### 16.1 Checklist (when adding an ability)

- [ ] At least one of: situational damage/heal, status, trait interaction, behavior change.
- [ ] Costs fit the intended cadence (spam vs setup vs finisher).
- [ ] Effect types used are **implemented** in `CombatController._apply_ability_effects` (see §8.3) — unimplemented enums **silently do nothing**.
- [ ] **`attack_range`:** Set **`MELEE`** for true melee; default **`RANGED`** for anything that should ignore row / hit flyers unless you intend otherwise.
- [ ] If magical / physical matters for mitigation, each **`AbilityEffect`** (**`damage_kind`**, **`is_magical`**) matches **`CombatDamageResolver`** / **`get_effective_damage_kind()`**.
- [ ] **`Ability.primary_damage_kind`:** Set to match the **main** DAMAGE effect (UI / filters). **`Ability.get_resolved_primary_damage_kind()`** returns the first damage effect’s kind when present.
- [ ] **Weapon gate (when §8.4 is live):** Set **`required_weapon_type_ids`** for any ability that needs a **bow**, **staff**, etc.; leave empty for spells / innate moves.
- [ ] **Basics:** If this is a **weapon-granted basic**, reference it from the **`Weapon`**’s **`granted_basic_attacks`** and set **`is_basic_attack = true`** on the **`Ability`** (see presets in **`resources/abilities/starters/`**) so **one-basic-per-turn** applies.
- [ ] If using **grounding** or **stealth**, **`status_id`** on the **`StatusEffect`** resource matches **`grounded`** / **`stealth`** (see §6.4, §9.2).
- [ ] Multi-effect order: e.g. **apply grounded before damage** on the same instant ability if both should apply in one resolution.
- [ ] **Enemies:** Set **`formation_row`** and **`preferred_zone`** together for coherent AI + spawn placement.

---

## 17. Does the Original Draft “Make Sense”?

**Yes.** The philosophy, axes, traits, ability principles, and narrative hooks are coherent and align with extant resources (`Ability`, `Enemy`, `StatusEffect`).

**Caveats:**

- **Turn structure** in the draft (**shared party turn + flexible ordering**) does **not** match the **current** speed-based, **one action per player slot** loop.
- Some **`AbilityEffect`** types remain **unimplemented** in the controller (§8.3); validate before shipping content.
- **Weapon loadout** uses **slots A/B only**; **preset** heroes ship with **starter weapons** and **starter basics** (§8.4.6). Combat merges **class specials + weapon-granted basics + Move** with gear filtering and **one basic per turn**. **Meta / specials cadence** (cap 4, replace-on-learn) is still **Phase J**.
- **Rows / melee-ranged / flying / stealth / grounding / push-pull** are **implemented** in logic (§6.4); **visual formation** in scenes is still **authoring**, not required for rules to run.

This document is the bridge: **same creative direction**, **explicit gaps**, **ordered path to implementation**.

---

## 18. Next steps (recommended order)

**Near-term (loadout / player-facing):**

1. **New heroes:** Author **`HeroCharacter` `.tres`** (slots, allow-lists, starter **`Weapon`** refs) — same pattern as **`resources/heroes/starter_*.tres`**; class is narrative + stat kit, not the equipment source.
2. **Character / Blacksmith UI:** Second equipment row for slot B; optional upgrade path for **`weapon_slot_b`** (§8.4.7).
3. **Remove dead UI:** Delete **`scenes/2d/CharacterSelect.tscn`** when you no longer need the deprecated stub (see **`scripts/menus/CharacterSelect.gd`**).

**Medium-term (combat systems):**

4. **Phase J:** Specials cap, replace-on-learn, UI separation of basics vs specials.
5. **Phase A / B:** Damage pipeline + **`AbilityEffect`** gaps — reduces “silent no-op” abilities (§8.3).
6. **Phase D** (optional): Party-phase prototype vs keeping speed timeline — product call (§4.1, §15 Q1).

Implementation locus: new heroes and gear in **`resources/heroes/`** + **`resources/weapons/`**; town UI / **`BlacksmithScreen.gd`**; combat depth in **`CombatController.gd`**, **`CombatantStats.gd`**, **`CombatDamageResolver`** (see **`COMBAT_SYSTEM_OVERVIEW.md`**).
