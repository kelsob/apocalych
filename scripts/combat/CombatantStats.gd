extends RefCounted
class_name CombatantStats

## CombatantStats - Runtime stats container for a combatant in combat
## Manages health, AP, speed, core stats, and active status effects

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
var base_ap_per_turn: int = 3  # Calculated from constitution

# Speed (determines turn frequency)
var base_speed: float = 10.0  # Calculated from dexterity
var speed_modifier: float = 0.0  # Applied by statuses/buffs

# Core stats (str, dex, con, int, wis, cha)
var core_stats: Dictionary = {
	"strength": 10,
	"dexterity": 10,
	"constitution": 10,
	"intelligence": 10,
	"wisdom": 10,
	"charisma": 10
}

# Active status effects
var active_statuses: Array[StatusEffect] = []

# Stat cache (for performance - recalculated when statuses change)
var cached_effective_stats: Dictionary = {}
var cache_dirty: bool = true

## Initialize stats from a PartyMember
func initialize_from_party_member(member: PartyMember):
	max_health = member.max_health
	current_health = member.current_health
	core_stats = member.get_final_stats().duplicate()
	
	# Calculate derived stats
	base_speed = _calculate_speed_from_dex(core_stats.dexterity)
	base_ap_per_turn = _calculate_ap_per_turn_from_con(core_stats.constitution)
	
	# Start combat with 3 AP (or max if less than 3)
	current_ap = min(3, max_ap)
	
	cache_dirty = true

## Initialize stats from an Enemy resource
func initialize_from_enemy(enemy: Resource):
	# Enemy resources will have pre-configured stats
	# This will be implemented when we create Enemy.gd
	pass

## Calculate speed from dexterity
## Formula: base 5 + (dex modifier * 2)
## Dex 10 = speed 5, Dex 14 = speed 9, Dex 18 = speed 13
func _calculate_speed_from_dex(dex: int) -> float:
	var dex_modifier = (dex - 10.0) / 2.0
	return 5.0 + (dex_modifier * 2.0)

## Calculate AP per turn from constitution
## Formula: base 3 + (con modifier / 2)
## Con 10 = 3 AP/turn, Con 14 = 4 AP/turn, Con 18 = 5 AP/turn
func _calculate_ap_per_turn_from_con(con: int) -> int:
	var con_modifier = (con - 10) / 2
	return 3 + (con_modifier / 2)

## Get effective stat value (base + modifiers from statuses)
func get_effective_stat(stat_name: String) -> int:
	if cache_dirty:
		_rebuild_stat_cache()
	
	return cached_effective_stats.get(stat_name, core_stats.get(stat_name, 10))

## Get all effective stats as a dictionary
func get_effective_stats() -> Dictionary:
	if cache_dirty:
		_rebuild_stat_cache()
	
	return cached_effective_stats.duplicate()

## Get effective speed (base + modifiers + status effects)
func get_effective_speed() -> float:
	var total_speed = base_speed + speed_modifier
	
	# Apply speed modifiers from statuses
	for status in active_statuses:
		if status.stat_modifiers.has("speed"):
			total_speed += status.stat_modifiers.speed
	
	return max(1.0, total_speed)  # Minimum speed of 1

## Regenerate AP at the start of a turn
func regenerate_ap():
	var old_ap = current_ap
	current_ap = min(max_ap, current_ap + base_ap_per_turn)
	if current_ap != old_ap:
		ap_changed.emit(old_ap, current_ap)

## Spend AP for casting an ability
func spend_ap(amount: int) -> bool:
	if current_ap >= amount:
		var old_ap = current_ap
		current_ap -= amount
		ap_changed.emit(old_ap, current_ap)
		return true
	return false

## Take damage (returns true if still alive)
func take_damage(amount: float) -> bool:
	# Check for shield statuses first
	var remaining_damage = amount
	
	for status in active_statuses:
		if status.status_type == StatusEffect.StatusType.SHIELD and status.current_shield_amount > 0:
			if status.current_shield_amount >= remaining_damage:
				status.current_shield_amount -= remaining_damage
				remaining_damage = 0
				break
			else:
				remaining_damage -= status.current_shield_amount
				status.current_shield_amount = 0
	
	# Apply remaining damage to health
	if remaining_damage > 0:
		var old_health = current_health
		current_health = max(0, current_health - int(remaining_damage))
		health_changed.emit(old_health, current_health)
		
		if current_health <= 0:
			died.emit()
			return false
	
	return true

## Heal (capped at max health)
func heal(amount: float):
	var old_health = current_health
	current_health = min(max_health, current_health + int(amount))
	if current_health != old_health:
		health_changed.emit(old_health, current_health)

## Apply a status effect
func apply_status(status: StatusEffect):
	# Check for existing status with same ID
	var existing_status = _find_status_by_id(status.status_id)
	
	if existing_status:
		# Handle stack behavior
		match status.stack_behavior:
			StatusEffect.StackBehavior.REFRESH:
				existing_status.remaining_duration = status.base_duration
			StatusEffect.StackBehavior.STACK:
				existing_status.stack_count += 1
				existing_status.remaining_duration = max(existing_status.remaining_duration, status.base_duration)
			StatusEffect.StackBehavior.REPLACE:
				remove_status(status.status_id)
				var new_instance = status.create_instance()
				active_statuses.append(new_instance)
				status_applied.emit(new_instance)
	else:
		# Add new status
		var new_instance = status.create_instance()
		active_statuses.append(new_instance)
		status_applied.emit(new_instance)
	
	cache_dirty = true
	stats_changed.emit()

## Remove a status effect by ID
func remove_status(status_id: String):
	for i in range(active_statuses.size() - 1, -1, -1):
		if active_statuses[i].status_id == status_id:
			var removed_status = active_statuses[i]
			active_statuses.remove_at(i)
			status_removed.emit(removed_status)
			cache_dirty = true
			stats_changed.emit()
			return

## Process all status effects at the start of a turn
## Returns a dictionary with information about what happened
func process_status_effects() -> Dictionary:
	var result = {
		"can_act": true,
		"can_cast": true,
		"total_damage": 0.0,
		"total_heal": 0.0,
		"effects_triggered": [],
		"statuses_expired": [],
		"control_statuses_consumed": []  # Control effects that prevented action
	}
	
	var expired_statuses: Array[String] = []
	var prevented_action: bool = false
	
	# FIRST: Check if any control effects would prevent action BEFORE processing
	# We need to know this before we decrement/remove them
	print("DEBUG: Processing %d active statuses" % active_statuses.size())
	for status in active_statuses:
		if status.prevents_actions:
			print("DEBUG: Found prevents_actions status: %s (duration: %d)" % [status.status_name, status.remaining_duration])
			prevented_action = true
			result.control_statuses_consumed.append(status.status_name)
			result.effects_triggered.append({
				"status": status.status_name,
				"type": "prevented_action",
				"amount": 0
			})
	
	# SECOND: Process all status ticks (decrements duration, applies effects)
	for status in active_statuses:
		var tick_result = status.process_tick()
		
		# Apply tick damage (poison, DoTs, etc.)
		if tick_result.damage > 0:
			take_damage(tick_result.damage)
			result.total_damage += tick_result.damage
			result.effects_triggered.append({
				"status": status.status_name,
				"type": "damage",
				"amount": tick_result.damage
			})
		
		# Apply tick healing (regen, HoTs, etc.)
		if tick_result.heal > 0:
			heal(tick_result.heal)
			result.total_heal += tick_result.heal
			result.effects_triggered.append({
				"status": status.status_name,
				"type": "heal",
				"amount": tick_result.heal
			})
		
		# Apply AP restoration
		if tick_result.ap_restore > 0:
			var old_ap = current_ap
			current_ap = min(max_ap, current_ap + int(tick_result.ap_restore))
			if current_ap != old_ap:
				ap_changed.emit(old_ap, current_ap)
				result.effects_triggered.append({
					"status": status.status_name,
					"type": "ap_restore",
					"amount": current_ap - old_ap
				})
		
		# Mark expired statuses (durations were decremented in process_tick)
		if status.is_expired():
			expired_statuses.append(status.status_id)
			# Track non-control status expirations for "wore off" messages
			if not (status.prevents_actions or status.prevents_casting or status.prevents_movement):
				result.statuses_expired.append(status.status_name)
	
	# THIRD: Remove ALL expired statuses
	for status_id in expired_statuses:
		remove_status(status_id)
	
	# FOURTH: Set final can_act state (after removals)
	result.can_act = not prevented_action
	result.can_cast = can_cast()
	
	print("DEBUG: Result - can_act: %s, prevented_action: %s" % [result.can_act, prevented_action])
	print("DEBUG: control_statuses_consumed: %s" % str(result.control_statuses_consumed))
	print("DEBUG: statuses_expired: %s" % str(result.statuses_expired))
	
	return result

## Tick all active statuses (called at start of turn) - DEPRECATED, use process_status_effects()
func tick_statuses():
	process_status_effects()

## Check if combatant can act (not stunned/incapacitated)
func can_act() -> bool:
	for status in active_statuses:
		if status.prevents_actions:
			return false
	return true

## Check if combatant can cast (not silenced)
func can_cast() -> bool:
	for status in active_statuses:
		if status.prevents_casting:
			return false
	return true

## Check if combatant is uninterruptible
func is_uninterruptible() -> bool:
	for status in active_statuses:
		if status.grants_uninterruptible:
			return true
	return false

## Check if combatant is alive
func is_alive() -> bool:
	return current_health > 0

## Find a status by ID
func _find_status_by_id(status_id: String) -> StatusEffect:
	for status in active_statuses:
		if status.status_id == status_id:
			return status
	return null

## Rebuild the stat cache
func _rebuild_stat_cache():
	cached_effective_stats = core_stats.duplicate()
	
	# Apply stat modifiers from all active statuses
	for status in active_statuses:
		for stat_name in status.stat_modifiers:
			if cached_effective_stats.has(stat_name):
				cached_effective_stats[stat_name] += status.stat_modifiers[stat_name]
	
	cache_dirty = false
