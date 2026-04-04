extends RefCounted
class_name EventStatCheck

## Resolves event choices that use `stat_challenge` JSON: pick tier (RNG), actor, effects, outcome text.
## Primary stat keys match `HeroCharacter.PRIMARY_STAT_KEYS`.

const TIER_CRIT_FAIL: String = "crit_fail"
const TIER_FAIL: String = "fail"
const TIER_SUCCESS: String = "success"
const TIER_CRIT_SUCCESS: String = "crit_success"

const TIER_ORDER: Array[String] = [TIER_CRIT_FAIL, TIER_FAIL, TIER_SUCCESS, TIER_CRIT_SUCCESS]

## At primary stat == 10, tier odds match a neutral d20-style spread (5 / 45 / 45 / 5).
const _BASE_P_CF: float = 0.05
const _BASE_P_F: float = 0.45
const _BASE_P_S: float = 0.45
const _BASE_P_CS: float = 0.05
const _BASE_BAD_SUM: float = _BASE_P_CF + _BASE_P_F
const _BASE_GOOD_SUM: float = _BASE_P_S + _BASE_P_CS

## Diminishing returns above/below baseline (10): first step moves 5% of total mass (bad↔good), each further point moves `REFINEMENT_RATIO` times the previous step’s increment.
## Effective stat is clamped to `STAT_CHECK_MAX_STAT` for odds (god-tier ceiling).
const STAT_CHECK_FIRST_STEP_SHIFT: float = 0.05
const STAT_CHECK_REFINEMENT_RATIO: float = 0.92
const STAT_CHECK_MAX_STAT: int = 30
## Never drain the opposite tier-group to zero: tiny tail remains on the “losing” side (fail at god-tier, success at rock-bottom).
const STAT_CHECK_MIN_TAIL_FRACTION: float = 0.0005

## Short labels for choice UI (editor can hardcode different copy in the scene).
const STAT_ABBREV: Dictionary = {
	"strength": "STR",
	"agility": "AGI",
	"constitution": "CON",
	"intellect": "INT",
	"spirit": "SPR",
	"charisma": "CHA",
	"luck": "LUK",
}


static func is_valid_primary_stat(stat_key: String) -> bool:
	return stat_key in HeroCharacter.PRIMARY_STAT_KEYS


static func abbrev_for_stat(stat_key: String) -> String:
	return str(STAT_ABBREV.get(stat_key, stat_key.to_upper().substr(0, 3)))


## Highest stat wins; ties → lowest party index.
static func default_actor_index_for_stat(stat_key: String, members: Array) -> int:
	if members.is_empty():
		return 0
	var best_i: int = 0
	var best_v: int = -999
	for i in members.size():
		var m: HeroCharacter = members[i]
		if m == null:
			continue
		var v: int = int(m.get_final_stats().get(stat_key, 10))
		if v > best_v:
			best_v = v
			best_i = i
	return best_i


static func stat_value_for_member(member: HeroCharacter, stat_key: String) -> int:
	if member == null:
		return 10
	return int(member.get_final_stats().get(stat_key, 10))


## Roll one of four tiers. Higher `stat_value` shifts mass toward success tiers (baseline 10).
## No console output — use `roll_tier_with_console_log` from event resolution when debugging.
static func roll_tier(stat_value: int, rng: RandomNumberGenerator) -> String:
	return _roll_tier_impl(stat_value, rng, false, "", "", "")


## Same as `roll_tier`, but prints cumulative thresholds on [0,1), probabilities, roll, and result. All lines prefixed with `statcheck:`.
static func roll_tier_with_console_log(
	stat_value: int,
	rng: RandomNumberGenerator,
	stat_key: String,
	choice_id: String,
	actor_name: String
) -> String:
	return _roll_tier_impl(stat_value, rng, true, stat_key, choice_id, actor_name)


static func _roll_tier_impl(
	stat_value: int,
	rng: RandomNumberGenerator,
	log: bool,
	stat_key: String,
	choice_id: String,
	actor_name: String
) -> String:
	var p: Dictionary = _tier_probabilities(stat_value)
	var r: float = rng.randf()
	var acc: float = 0.0
	var tier_result: String = TIER_ORDER[TIER_ORDER.size() - 1]

	if log:
		print("statcheck: ----- stat_challenge roll -----")
		if not choice_id.is_empty():
			print("statcheck: choice_id=%s" % choice_id)
		print("statcheck: actor=%s  primary_stat=%s  stat_value=%d" % [actor_name, stat_key, stat_value])
		print(
			"statcheck: tier probabilities (sum=1.0)  %s=%.4f  %s=%.4f  %s=%.4f  %s=%.4f"
			% [
				TIER_CRIT_FAIL,
				float(p.get(TIER_CRIT_FAIL, 0.0)),
				TIER_FAIL,
				float(p.get(TIER_FAIL, 0.0)),
				TIER_SUCCESS,
				float(p.get(TIER_SUCCESS, 0.0)),
				TIER_CRIT_SUCCESS,
				float(p.get(TIER_CRIT_SUCCESS, 0.0)),
			]
		)
		var p_cf: float = float(p.get(TIER_CRIT_FAIL, 0.0))
		var p_f: float = float(p.get(TIER_FAIL, 0.0))
		var p_s: float = float(p.get(TIER_SUCCESS, 0.0))
		var p_cs: float = float(p.get(TIER_CRIT_SUCCESS, 0.0))
		var c1: float = p_cf
		var c2: float = p_cf + p_f
		var c3: float = p_cf + p_f + p_s
		print(
			"statcheck: explicit r partitions (code walks tiers in order; first `r <= cumulative` wins):  "
			+ "[0, %.6f]→%s;  (%.6f, %.6f]→%s;  (%.6f, %.6f]→%s;  (%.6f, 1.0)→%s"
			% [c1, TIER_CRIT_FAIL, c1, c2, TIER_FAIL, c2, c3, TIER_SUCCESS, c3, TIER_CRIT_SUCCESS]
		)
		print(
			"statcheck: aggregate — P(fail or worse)=%.4f  P(success)=%.4f  P(crit_success)=%.4f  P(success or crit_success)=%.4f"
			% [p_cf + p_f, p_s, p_cs, p_s + p_cs]
		)
		print("statcheck: RNG draw — r = %.6f (uniform [0.0, 1.0))" % r)

	acc = 0.0
	for tier in TIER_ORDER:
		acc += float(p.get(tier, 0.0))
		if r <= acc:
			tier_result = tier
			break

	if log:
		var e1: float = float(p.get(TIER_CRIT_FAIL, 0.0))
		var e2: float = e1 + float(p.get(TIER_FAIL, 0.0))
		var e3: float = e2 + float(p.get(TIER_SUCCESS, 0.0))
		var band: String = ""
		match tier_result:
			TIER_CRIT_FAIL:
				band = "r in [0, %.6f] → %s" % [e1, TIER_CRIT_FAIL]
			TIER_FAIL:
				band = "r in (%.6f, %.6f] → %s" % [e1, e2, TIER_FAIL]
			TIER_SUCCESS:
				band = "r in (%.6f, %.6f] → %s" % [e2, e3, TIER_SUCCESS]
			TIER_CRIT_SUCCESS:
				band = "r in (%.6f, 1.0) → %s" % [e3, TIER_CRIT_SUCCESS]
			_:
				band = "(unknown tier)"
		print("statcheck: outcome — r=%.6f → tier=%s  |  %s" % [r, tier_result, band])
		print("statcheck: ----- end stat_challenge roll -----")

	return tier_result


## Sum of `STAT_CHECK_FIRST_STEP_SHIFT * r^k` for k = 0 .. delta-1 (delta steps). delta=1 → 0.05; then diminishing.
static func _cumulative_shift_magnitude(delta: int) -> float:
	if delta <= 0:
		return 0.0
	var r: float = STAT_CHECK_REFINEMENT_RATIO
	return STAT_CHECK_FIRST_STEP_SHIFT * (1.0 - pow(r, delta)) / (1.0 - r)


## Baseline at stat 10: 5% crit_fail, 45% fail, 45% success, 5% crit_success (d20-style neutral).
## Above 10: each point shifts mass from bad→good with diminishing returns (first step +5%, then geometric decay). Below 10: symmetric toward bad. Stat is clamped to `STAT_CHECK_MAX_STAT` for the curve. Mass splits preserve the 5:45 / 45:5 ratio within bad and good groups.
static func _tier_probabilities(stat_value: int) -> Dictionary:
	var t: int = clampi(stat_value, 1, STAT_CHECK_MAX_STAT)
	var delta: int = t - 10
	var shift: float = 0.0
	if delta >= 0:
		shift = _cumulative_shift_magnitude(delta)
	else:
		shift = -_cumulative_shift_magnitude(-delta)

	var p_cf: float = _BASE_P_CF
	var p_f: float = _BASE_P_F
	var p_s: float = _BASE_P_S
	var p_cs: float = _BASE_P_CS

	if shift > 0.0:
		var mv: float = minf(shift, _BASE_BAD_SUM - STAT_CHECK_MIN_TAIL_FRACTION)
		p_cf -= mv * (_BASE_P_CF / _BASE_BAD_SUM)
		p_f -= mv * (_BASE_P_F / _BASE_BAD_SUM)
		p_s += mv * (_BASE_P_S / _BASE_GOOD_SUM)
		p_cs += mv * (_BASE_P_CS / _BASE_GOOD_SUM)
	elif shift < 0.0:
		var mv: float = minf(-shift, _BASE_GOOD_SUM - STAT_CHECK_MIN_TAIL_FRACTION)
		p_s -= mv * (_BASE_P_S / _BASE_GOOD_SUM)
		p_cs -= mv * (_BASE_P_CS / _BASE_GOOD_SUM)
		p_cf += mv * (_BASE_P_CF / _BASE_BAD_SUM)
		p_f += mv * (_BASE_P_F / _BASE_BAD_SUM)

	# Clamp and renormalize (float edge cases / extreme stats)
	p_cf = maxf(p_cf, 0.0)
	p_f = maxf(p_f, 0.0)
	p_s = maxf(p_s, 0.0)
	p_cs = maxf(p_cs, 0.0)
	var sum: float = p_cf + p_f + p_s + p_cs
	if sum <= 0.0:
		return {
			TIER_CRIT_FAIL: _BASE_P_CF,
			TIER_FAIL: _BASE_P_F,
			TIER_SUCCESS: _BASE_P_S,
			TIER_CRIT_SUCCESS: _BASE_P_CS,
		}
	return {
		TIER_CRIT_FAIL: p_cf / sum,
		TIER_FAIL: p_f / sum,
		TIER_SUCCESS: p_s / sum,
		TIER_CRIT_SUCCESS: p_cs / sum,
	}


## `choice` must include `stat_challenge` with `primary_stat` and `tier_outcomes` (dict of tier → { text, effects }).
## `actor_slot` is index into `members` (Main.run_roster order).
static func resolve_stat_challenge(
	choice: Dictionary,
	actor_slot: int,
	members: Array,
	rng: RandomNumberGenerator
) -> Dictionary:
	var sc: Variant = choice.get("stat_challenge", {})
	if typeof(sc) != TYPE_DICTIONARY:
		return _empty_resolve(actor_slot, members)

	var stat_key: String = str(sc.get("primary_stat", "strength"))
	if not is_valid_primary_stat(stat_key):
		push_warning("EventStatCheck: invalid primary_stat '%s'" % stat_key)
		stat_key = "strength"

	var idx: int = clampi(actor_slot, 0, maxi(0, members.size() - 1))
	var actor: HeroCharacter = members[idx] if idx < members.size() else null
	var sv: int = stat_value_for_member(actor, stat_key)
	var actor_name: String = actor.member_name if actor else "Unknown"
	var choice_id: String = str(choice.get("id", ""))
	var tier: String = roll_tier_with_console_log(sv, rng, stat_key, choice_id, actor_name)

	var tiers: Variant = sc.get("tier_outcomes", {})
	if typeof(tiers) != TYPE_DICTIONARY:
		return _empty_resolve(idx, members)

	var block: Dictionary = tiers.get(tier, {}) as Dictionary
	if block.is_empty():
		block = tiers.get(TIER_SUCCESS, {}) as Dictionary

	var effects: Array = []
	var raw_e: Variant = block.get("effects", [])
	if raw_e is Array:
		effects = raw_e.duplicate()
	elif raw_e is Dictionary:
		effects = [raw_e]

	var text: String = str(block.get("text", ""))

	return {
		"tier": tier,
		"effects": effects,
		"text": text,
		"actor_index": idx,
		"actor_name": actor_name,
		"primary_stat": stat_key,
		"stat_value": sv,
	}


static func _empty_resolve(_slot: int, members: Array) -> Dictionary:
	var actor: HeroCharacter = members[0] if members.size() > 0 else null
	return {
		"tier": TIER_FAIL,
		"effects": [],
		"text": "",
		"actor_index": 0,
		"actor_name": actor.member_name if actor else "",
		"primary_stat": "strength",
		"stat_value": 10,
	}


## Crit_fail+fail vs success+crit_success as whole percentages (no per-tier breakdown). Sums to 100.
static func fail_success_odds_percent(stat_value: int) -> Dictionary:
	var p: Dictionary = _tier_probabilities(stat_value)
	var p_bad: float = float(p.get(TIER_CRIT_FAIL, 0.0)) + float(p.get(TIER_FAIL, 0.0))
	var p_fail_pct: int = clampi(int(round(p_bad * 100.0)), 0, 100)
	return {"fail": p_fail_pct, "success": 100 - p_fail_pct}


## Build a single-line label: "Action text — Name (STR 14) · 48% fail · 52% success" (odds from current stat value).
static func build_choice_label(base_text: String, stat_key: String, actor_slot: int, members: Array) -> String:
	var idx: int = clampi(actor_slot, 0, maxi(0, members.size() - 1))
	var actor: HeroCharacter = members[idx] if idx < members.size() else null
	var nm: String = actor.member_name if actor else "—"
	var ab: String = abbrev_for_stat(stat_key)
	var v: int = stat_value_for_member(actor, stat_key)
	var odds: Dictionary = fail_success_odds_percent(v)
	return "%s — %s (%s %d) · %d%% fail · %d%% success" % [
		base_text.strip_edges(),
		nm,
		ab,
		v,
		int(odds.get("fail", 50)),
		int(odds.get("success", 50)),
	]
