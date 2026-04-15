# Combat Design — Official Document

**Status:** Design authority for combat direction.  
**Companion docs:** `COMBAT_SYSTEM_OVERVIEW.md` (what exists today, architecture), `COMBAT_ABILITIES_DESIGN.md` (class ability notes).  
**Last updated:** 2026-04-07 (formation, targeting, stealth & zone effects)

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

**Core:** cost (AP), target scope (self / ally / enemy / all), **range band** (melee / ranged / unlimited), **damage type**, power / scaling, **weapon requirement** (none / any / specific tag).

**Execution:** timing (`INSTANT` / `DELAYED_CAST` / `CHANNELED` — matches `Ability.AbilityType`), targeting (single / AoE), durations, movement (push/pull/dash — future).

**Interaction:** ignore armor/resist, interrupt, modify traits, conditional bonuses, **non-lethal** flag.

### 8.3 Current implementation

- **`Ability` + `AbilityEffect`:** Rich enums for targeting and effect types.
- **`CombatController._apply_ability_effects` resolves:** `DAMAGE`, `HEAL`, `APPLY_STATUS`, `APPLY_GROUNDING`, `MOVE_FORMATION`, `PUSH_TO_BACK`, `PULL_TO_FRONT`, `INTERRUPT_CAST`.
- **Declared but not resolved in controller (yet):** `RESTORE_AP`, `DRAIN_AP`, `SHIELD`, `DISPEL`, `SPAWN`, `LIFESTEAL`.

Many `.tres` abilities may still reference unimplemented effect types; **verify** in controller or effects **do nothing** silently.

**Rogues / stealth:** Example self-buff ability + status: **`resources/abilities/rogue/stealth.tres`**, **`resources/statuses/stealth.tres`** (`status_id` **`stealth`**), referenced from **`rogue.tres`** class abilities.

---

## 9. Status Effects & Combat States

### 9.1 Design

States drive depth: **stunned**, **grounded**, **exposed** (damage amp), **marked**, **panicked** / **fear**, **channeling** (interruptible), **silenced**, etc.

They should be **readable**, **composable**, and **hooked into AI** (e.g. cowardice at low HP).

### 9.2 Current implementation

- **`StatusEffect`:** Durations, stacking, stat mods, ticks (DoT/HoT/AP), shields, stun/silence/root/fear flags, `bypass_defense` for bleed-like ticks, dispel flag.
- **Processing:** Per-turn in `CombatantStats.process_status_effects()`; stun prevents actions; fear exists as a type (flee behavior **not** fully tied in combat AI).
- **Combat-critical ids:** **`grounded`** and **`stealth`** are referenced by **`CombatantData`** / **`CombatTargetRules`**; ship matching **`resources/statuses/*.tres`** (or duplicates with the same ids).

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

---

## 15. Open Questions (Need Product Answers)

1. **Party phase vs speed timeline:** Do we **replace** per-hero timeline slots with one party phase per “round,” or **hybrid** (timeline for enemies only, party acts as a block)? This drives UI and `CombatController` structure.
2. **AP model:** Strictly **shared** party pool, **per-character** only, or **hybrid** (shared tactical pool + character ultimates)?
3. **Magical vs physical on sheet:** Is `mag_def` enough, or do we want **elemental** splits (fire/holy/void) in v1?
4. **Non-lethal and ethics:** Required for ship milestone, or post-MVP?
5. **Difficulty:** Should AI cheat information (see exact HP) or use heuristics (wounded / healthy)?

---

## 16. Content Authoring Checklist (When Adding an Ability)

- [ ] At least one of: situational damage/heal, status, trait interaction, behavior change.
- [ ] Costs fit the intended cadence (spam vs setup vs finisher).
- [ ] Effect types used are **implemented** in `CombatController._apply_ability_effects` (see §8.3) — unimplemented enums **silently do nothing**.
- [ ] **`attack_range`:** Set **`MELEE`** for true melee; default **`RANGED`** for anything that should ignore row / hit flyers unless you intend otherwise.
- [ ] If magical / physical matters for mitigation, **`AbilityEffect`** damage kind / **`is_magical`** matches the pipeline you expect.
- [ ] If using **grounding** or **stealth**, **`status_id`** on the **`StatusEffect`** resource matches **`grounded`** / **`stealth`** (see §6.4, §9.2).
- [ ] Multi-effect order: e.g. **apply grounded before damage** on the same instant ability if both should apply in one resolution.
- [ ] **Enemies:** Set **`formation_row`** and **`preferred_zone`** together for coherent AI + spawn placement.

---

## 17. Does the Original Draft “Make Sense”?

**Yes.** The philosophy, axes, traits, ability principles, and narrative hooks are coherent and align with extant resources (`Ability`, `Enemy`, `StatusEffect`).

**Caveats:**

- **Turn structure** in the draft (**shared party turn + flexible ordering**) does **not** match the **current** speed-based, **one action per player slot** loop.
- Some **`AbilityEffect`** types remain **unimplemented** in the controller (§8.3); validate before shipping content.
- **Rows / melee-ranged / flying / stealth / grounding / push-pull** are **implemented** in logic (§6.4); **visual formation** in scenes is still **authoring**, not required for rules to run.

This document is the bridge: **same creative direction**, **explicit gaps**, **ordered path to implementation**.

---

## 18. Next Step (Engineering)

Pick **Phase A** (damage pipeline + trait hooks) **or** **Phase D** (party-phase prototype) as the next **major** slice; Phase A is lower risk and unblocks content honesty; Phase D is higher impact on feel but touches UI and controller heavily.

When you choose, implementation can proceed in `CombatController.gd`, `CombatantStats.gd`, and optionally a small `CombatDamageResolver.gd` to keep rules testable.
