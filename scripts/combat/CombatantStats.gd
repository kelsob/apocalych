extends RefCounted
class_name CombatantStats

## CombatantStats - Runtime stats container for a combatant in combat.
## Uses the simplified ATK / DEF / SPD / MAG / MAG_DEF stat system.

signal stats_changed()
signal health_changed(old_value: int, new_value: int)
signal ap_changed(old_value: int, new_value: int)
signal status_applied(status: StatusEffect)
signal status_removed(status: StatusEffect)
signal died()

# Health
var max_health: int = 10
var current_health: int = 10

# Action Points
var max_ap: int = 10
var current_ap: int = 10
var base_ap_per_turn: int = 3

# Speed (determines turn frequency in the combat timeline)
var base_speed: float = 5.0
var speed_modifier: float = 0.0

# Core stats — keys: "atk", "def", "spd", "mag", "mag_def"
var core_stats: Dictionary = {
	"atk": 5,
	"def": 0,
	"spd": 5,
	"mag": 0,
	"mag_def": 0
}

# Active status effects
var active_statuses: Array[StatusEffect] = []

# Stat cache
var cached_effective_stats: Dictionary = {}
var cache_dirty: bool = true

## Initialize stats from a PartyMember
func initialize_from_party_member(member: PartyMember):
	max_health = member.max_health
	current_health = member.current_health
	core_stats = member.get_final_stats().duplicate()

	# Fold equipment bonuses directly into stats
	if member.weapon:
		core_stats["atk"] = core_stats.get("atk", 5) + member.weapon.get_damage_bonus()
	if member.armour:
		core_stats["def"] = core_stats.get("def", 0) + member.armour.get_defense_bonus()

	base_speed = float(core_stats.get("spd", 5))
	base_ap_per_turn = 3
	current_ap = 3
	cache_dirty = true

## Initialize stats from an Enemy resource
func initialize_from_enemy(enemy: Resource):
	# Handled by Enemy.create_combat_stats() — this stub kept for interface completeness
	pass

## Get effective speed (base + speed modifiers from active statuses)
func get_effective_speed() -> float:
	var total := base_speed + speed_modifier
	for status in active_statuses:
		if status.stat_modifiers.has("spd"):
			total += float(status.stat_modifiers["spd"])
	return max(1.0, total)

## Regenerate AP at the start of a turn
func regenerate_ap():
	var old_ap := current_ap
	current_ap = min(max_ap, current_ap + base_ap_per_turn)
	if current_ap != old_ap:
		ap_changed.emit(old_ap, current_ap)

## Spend AP for casting an ability. Returns false if insufficient.
func spend_ap(amount: int) -> bool:
	if current_ap >= amount:
		var old_ap := current_ap
		current_ap -= amount
		ap_changed.emit(old_ap, current_ap)
		return true
	return false

## Take damage. bypass_def skips flat defense reduction (e.g. bleed).
func take_damage(amount: float, bypass_def: bool = false) -> Dictionary:
	var remaining := amount

	# Absorb shields first
	var damage_absorbed := 0.0
	for status in active_statuses:
		if status.status_type == StatusEffect.StatusType.SHIELD and status.current_shield_amount > 0:
			if status.current_shield_amount >= remaining:
				status.current_shield_amount -= remaining
				damage_absorbed += remaining
				remaining = 0.0
				break
			else:
				damage_absorbed += status.current_shield_amount
				remaining -= status.current_shield_amount
				status.current_shield_amount = 0.0

	# Flat defense reduction (skip if bypass_def is set, e.g. bleed)
	if not bypass_def:
		var effective_def := get_effective_stat("def")
		remaining = max(0.0, remaining - float(effective_def))

	var actual_health_damage := 0
	if remaining > 0.0:
		var old_health := current_health
		actual_health_damage = int(remaining)
		current_health = max(0, current_health - actual_health_damage)
		health_changed.emit(old_health, current_health)

	if current_health <= 0:
		died.emit()

	return {
		"alive": current_health > 0,
		"damage_dealt": actual_health_damage + int(damage_absorbed),
		"damage_to_health": actual_health_damage,
		"damage_to_shield": int(damage_absorbed)
	}

## Heal (capped at max health)
func heal(amount: float):
	var old_health := current_health
	current_health = min(max_health, current_health + int(amount))
	if current_health != old_health:
		health_changed.emit(old_health, current_health)

## Apply a status effect
func apply_status(status: StatusEffect):
	var existing := _find_status_by_id(status.status_id)
	if existing:
		match status.stack_behavior:
			StatusEffect.StackBehavior.REFRESH:
				existing.remaining_duration = status.base_duration
			StatusEffect.StackBehavior.STACK:
				existing.stack_count += 1
				existing.remaining_duration = max(existing.remaining_duration, status.base_duration)
			StatusEffect.StackBehavior.REPLACE:
				remove_status(status.status_id)
				var inst := status.create_instance()
				active_statuses.append(inst)
				status_applied.emit(inst)
	else:
		var inst := status.create_instance()
		active_statuses.append(inst)
		status_applied.emit(inst)
	cache_dirty = true
	stats_changed.emit()

## Remove a status effect by ID
func remove_status(status_id: String):
	for i in range(active_statuses.size() - 1, -1, -1):
		if active_statuses[i].status_id == status_id:
			var removed := active_statuses[i]
			active_statuses.remove_at(i)
			status_removed.emit(removed)
			cache_dirty = true
			stats_changed.emit()
			return

## Process all status effects at the start of a turn.
## Returns a dictionary describing what happened.
func process_status_effects() -> Dictionary:
	var result := {
		"can_act": true,
		"can_cast": true,
		"total_damage": 0.0,
		"total_heal": 0.0,
		"effects_triggered": [],
		"statuses_expired": [],
		"control_statuses_consumed": []
	}

	var expired_ids: Array[String] = []
	var prevented_action := false

	# First pass: check for action-preventing statuses
	for status in active_statuses:
		if status.prevents_actions:
			prevented_action = true
			result.control_statuses_consumed.append(status.status_name)
			result.effects_triggered.append({
				"status": status.status_name,
				"type": "prevented_action",
				"amount": 0
			})

	# Second pass: process ticks
	for status in active_statuses:
		var tick := status.process_tick()

		if tick.damage > 0:
			var dmg_result := take_damage(tick.damage, tick.get("bypass_defense", false))
			result.total_damage += dmg_result.damage_dealt
			result.effects_triggered.append({
				"status": status.status_name,
				"type": "damage",
				"amount": dmg_result.damage_dealt
			})

		if tick.heal > 0:
			heal(tick.heal)
			result.total_heal += tick.heal
			result.effects_triggered.append({
				"status": status.status_name,
				"type": "heal",
				"amount": tick.heal
			})

		if tick.ap_restore > 0:
			var old_ap := current_ap
			current_ap = min(max_ap, current_ap + int(tick.ap_restore))
			if current_ap != old_ap:
				ap_changed.emit(old_ap, current_ap)

		if status.is_expired():
			expired_ids.append(status.status_id)
			if not (status.prevents_actions or status.prevents_casting or status.prevents_movement):
				result.statuses_expired.append(status.status_name)

	# Remove expired statuses
	for sid in expired_ids:
		remove_status(sid)

	result.can_act = not prevented_action
	result.can_cast = can_cast()
	return result

## Deprecated: use process_status_effects()
func tick_statuses():
	process_status_effects()

## True if not stunned / feared
func can_act() -> bool:
	for status in active_statuses:
		if status.prevents_actions:
			return false
	return true

## True if not silenced
func can_cast() -> bool:
	for status in active_statuses:
		if status.prevents_casting:
			return false
	return true

## True if an ability's cast cannot be interrupted
func is_uninterruptible() -> bool:
	for status in active_statuses:
		if status.grants_uninterruptible:
			return true
	return false

func is_alive() -> bool:
	return current_health > 0

## Get the effective (cached) value of a stat, including status modifiers
func get_effective_stat(stat_name: String) -> int:
	if cache_dirty:
		_rebuild_stat_cache()
	return cached_effective_stats.get(stat_name, core_stats.get(stat_name, 0))

## Get all effective stats as a dictionary
func get_effective_stats() -> Dictionary:
	if cache_dirty:
		_rebuild_stat_cache()
	return cached_effective_stats.duplicate()

func _find_status_by_id(status_id: String) -> StatusEffect:
	for status in active_statuses:
		if status.status_id == status_id:
			return status
	return null

func _rebuild_stat_cache():
	cached_effective_stats = core_stats.duplicate()
	for status in active_statuses:
		for stat_name in status.stat_modifiers:
			if cached_effective_stats.has(stat_name):
				cached_effective_stats[stat_name] += status.stat_modifiers[stat_name]
	cache_dirty = false
