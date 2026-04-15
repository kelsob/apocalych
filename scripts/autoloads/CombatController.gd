extends Node

## CombatController - Global singleton that orchestrates combat
## Manages combat state, timeline, and coordinates between systems

# Signals for combat events
signal combat_started(player_combatants: Array, enemy_combatants: Array)
signal combat_ended(victory: bool, rewards: Dictionary)
signal turn_started(combatant: CombatantData, turn_number: int, status_results: Dictionary)
signal turn_ended(combatant: CombatantData)
signal ability_queued(caster: CombatantData, ability: Ability, targets: Array)
signal ability_resolved(caster: CombatantData, ability: Ability, targets: Array, effects_applied: Array)
signal cast_started(cast: ActiveCast)
signal cast_interrupted(caster: CombatantData, ability: Ability)
signal channeled_tick(cast: ActiveCast)
signal combatant_damaged(combatant: CombatantData, amount: float, source: CombatantData)
signal combatant_healed(combatant: CombatantData, amount: float, source: CombatantData)
signal combatant_died(combatant: CombatantData)
signal status_applied(combatant: CombatantData, status: StatusEffect)
signal status_removed(combatant: CombatantData, status: StatusEffect)
## Emitted when combat was started with test_lab=true (after combat_ended). For CombatTestLab / tools only.
signal combat_test_session_ended(victory: bool, rewards: Dictionary)

# Combat state
var combat_active: bool = false
## True for the duration of a test-lab fight; skips world time and Main handoff when cleared.
var is_combat_test_session: bool = false
var combat_timeline: CombatTimeline = null

## Delay before the first turn begins. Customizable (default 3 seconds).
@export var combat_start_delay: float = 3.0
## Delay after a player's turn ends, before the next character's turn starts (default 1 second).
@export var turn_end_delay_after_player: float = 1.0
var player_combatants: Array[CombatantData] = []
var enemy_combatants: Array[CombatantData] = []
var current_turn_combatant: CombatantData = null
var current_encounter: Resource = null  # CombatEncounter resource

# Waiting for player input
var waiting_for_player_input: bool = false

func _ready():
	print("CombatController initialized")

## If CombatScene is in the tree, return its exported delay; otherwise use default.
func _get_delay(property: String, default_val: float) -> float:
	var nodes = get_tree().get_nodes_in_group("combat_scene")
	for node in nodes:
		if node.get(property) != null:
			return node.get(property)
	return default_val

## Safe display name for logging; avoids Nil access when target died or was removed
func _safe_display_name(c) -> String:
	if c == null or not is_instance_valid(c):
		return "[unknown]"
	if c is CombatantData:
		return (c as CombatantData).display_name
	return str(c)


func _find_ability_by_id(combatant: CombatantData, ability_id: String) -> Ability:
	if combatant == null or combatant.abilities.is_empty():
		return null
	for a in combatant.abilities:
		if a is Ability and (a as Ability).ability_id == ability_id:
			return a as Ability
	return null


func _pull_weather_combat_modifiers() -> Array:
	var root: Window = get_tree().root if get_tree() else null
	if root == null:
		return []
	var wm: Node = root.get_node_or_null("WeatherManager")
	if wm != null and wm.has_method("get_active_combat_weather_modifiers"):
		return wm.get_active_combat_weather_modifiers()
	return []


## Start combat from an encounter and party members.
## If [param test_lab] is true, world time does not advance and [signal combat_test_session_ended] fires;
## rewards include [code]_test_lab = true[/code] for UI routing.
func start_combat_from_encounter(encounter: Resource, party_members: Array, test_lab: bool = false):
	if combat_active:
		push_warning("CombatController: Combat already active")
		return
	
	print("=== COMBAT STARTING ===")
	combat_active = true
	is_combat_test_session = test_lab
	current_encounter = encounter

	# Weather → combat (stub): read modifiers when WeatherManager implements non-empty returns.
	var _weather_mods: Array = _pull_weather_combat_modifiers()
	# When non-empty, apply modifiers to encounter / combatants here.
	if not _weather_mods.is_empty():
		print("CombatController: weather modifiers registered (application not implemented): ", _weather_mods)
	
	# Initialize timeline
	combat_timeline = CombatTimeline.new()
	
	# Initialize player combatants from party members
	player_combatants.clear()
	for member in party_members:
		if member is HeroCharacter:
			var combatant = CombatantData.new()
			combatant.initialize_from_hero_character(member)
			combatant.died.connect(_on_combatant_died.bind(combatant))
			player_combatants.append(combatant)
			combat_timeline.register_combatant(combatant)
			print("Registered player: %s (Speed: %.2f, AP: %d)" % [_safe_display_name(combatant), combatant.get_effective_speed(), combatant.combatant_stats.base_ap_per_turn])
	
	# Initialize enemy combatants from encounter
	enemy_combatants.clear()
	if encounter is CombatEncounter:
		for enemy in encounter.enemies:
			var combatant = CombatantData.new()
			combatant.initialize_from_enemy(enemy)
			combatant.died.connect(_on_combatant_died.bind(combatant))
			enemy_combatants.append(combatant)
			combat_timeline.register_combatant(combatant)
			print("Registered enemy: %s (Speed: %.2f, AP: %d)" % [_safe_display_name(combatant), combatant.get_effective_speed(), combatant.combatant_stats.base_ap_per_turn])
	
	# Emit signal
	combat_started.emit(player_combatants, enemy_combatants)
	
	# Delay before first turn (CombatScene exports override when in tree)
	var start_delay := _get_delay("combat_start_delay", combat_start_delay)
	await get_tree().create_timer(start_delay).timeout
	if not combat_active:
		return
	# Start first turn
	_advance_to_next_turn()

## Advance to the next turn
func _advance_to_next_turn():
	if not combat_active:
		return
	
	# Check victory conditions
	if _check_victory_conditions():
		return
	
	# Advance timeline
	var turn_event = combat_timeline.advance_timeline()
	
	if turn_event == null:
		push_error("CombatController: No turns in queue!")
		return
	
	current_turn_combatant = turn_event.combatant
	
	# Start turn for combatant (processes status effects, regenerates AP)
	var status_results = current_turn_combatant.start_turn()
	
	# EMIT TURN STARTED SIGNAL FIRST (so "--- Turn ---" logs before anything else)
	turn_started.emit(current_turn_combatant, turn_event.turn_number, status_results)
	
	# THEN process active casts for this combatant
	var cast_tick_results = combat_timeline.process_cast_ticks(current_turn_combatant)
	
	# Check if they have a channeled cast that's still ticking
	var has_channeling = false
	for cast in cast_tick_results.ticking_casts:
		if cast.ability.ability_type == Ability.AbilityType.CHANNELED:
			has_channeling = true
			# Apply effects each turn for channeled abilities
			print("  -> Channeled tick %d/%d" % [cast.current_tick, cast.total_ticks])
			var effects_applied = _apply_ability_effects(cast.caster, cast.ability, cast.targets)
			
			# Emit signal with effects so combat log can display them
			ability_resolved.emit(cast.caster, cast.ability, cast.targets, effects_applied)
			channeled_tick.emit(cast)
			
			# Log individual effects (with null checks)
			for effect in effects_applied:
				if effect.type == "damage" and effect.has("target"):
					print("    -> %s takes %d damage" % [_safe_display_name(effect.get("target")), effect.amount])
	
	# Resolve completed casts
	for cast in cast_tick_results.completed_casts:
		if cast.ability.ability_type == Ability.AbilityType.CHANNELED:
			# Channeled: Just ends, no final effect (already applied on last tick)
			ability_resolved.emit(cast.caster, cast.ability, cast.targets, [])
			print("  -> Channeled cast complete (no final effect, already applied)")
		else:
			# Delayed: Apply effects ONCE at the end
			_resolve_ability_cast(cast)
	
	# Check if combatant can act after processing status effects
	if not status_results.can_act:
		print("%s cannot act (stunned/incapacitated), skipping turn" % _safe_display_name(current_turn_combatant))
		# Give a moment for the log to display status effects
		await get_tree().create_timer(1.0).timeout
		_end_current_turn()
		return
	
	# If channeling, automatically end turn (channeling continues)
	if has_channeling:
		print("  -> %s continues channeling, turn ends automatically" % _safe_display_name(current_turn_combatant))
		await get_tree().create_timer(0.5).timeout
		_end_current_turn()
		return
	
	# If player turn, wait for input
	if current_turn_combatant.is_player:
		waiting_for_player_input = true
		print("Player turn: %s (AP: %d/%d)" % [_safe_display_name(current_turn_combatant), current_turn_combatant.combatant_stats.current_ap, current_turn_combatant.combatant_stats.max_ap])
	else:
		# AI turn - execute immediately
		_execute_ai_turn()

## Player executes an action (called by UI)
func player_cast_ability(ability: Ability, targets: Array):
	if not waiting_for_player_input:
		push_warning("CombatController: Not waiting for player input")
		return
	
	if current_turn_combatant == null or not current_turn_combatant.is_player:
		push_warning("CombatController: Current turn is not a player")
		return
	
	# Validate targets
	if not _validate_targets(current_turn_combatant, ability, targets):
		push_warning("CombatController: Invalid targets for ability")
		return
	
	# Attempt to cast
	if _execute_ability_cast(current_turn_combatant, ability, targets):
		# End turn
		_end_current_turn()

## Player ends turn without acting (called by UI)
func player_end_turn():
	if not waiting_for_player_input:
		return
	
	print("Player ended turn: %s" % _safe_display_name(current_turn_combatant))
	_end_current_turn()

## Attempt to flee from combat (called by UI).
## Currently always succeeds: ends combat, rewards screen shows XP only for enemies killed before fleeing (no gold).
func attempt_flee() -> bool:
	if not waiting_for_player_input:
		return false
	
	# Immediately succeed and end combat with flee rewards (XP from killed enemies only, no gold)
	waiting_for_player_input = false
	current_turn_combatant = null
	_end_combat_fled()
	return true

## Execute ability cast
func _execute_ability_cast(caster: CombatantData, ability: Ability, targets: Array) -> bool:
	# Try to cast ability
	if not caster.cast_ability(ability, targets):
		return false
	
	print("%s casts %s (AP: %d, Cast Time: %d)" % [_safe_display_name(caster), ability.ability_name, ability.get_modified_ap_cost(), ability.get_modified_cast_time()])
	
	var cast_time = ability.get_modified_cast_time()
	
	if cast_time == 0:
		# Instant cast - resolve immediately
		_resolve_ability_instant(caster, ability, targets)
	else:
		# Delayed/channeled cast - queue it
		var cast = ActiveCast.new(caster, ability, targets)
		combat_timeline.active_casts.append(cast)
		ability_queued.emit(caster, ability, targets)
		cast_started.emit(cast)
		print("  -> Queued with %d turn cast time" % cast_time)
		
		# Channeled abilities: optionally apply first tick on the turn they're cast
		if ability.ability_type == Ability.AbilityType.CHANNELED and ability.channeled_tick_on_cast:
			print("  -> Channeled (tick on cast): applying first tick immediately")
			var effects_applied = _apply_ability_effects(caster, ability, targets)
			ability_resolved.emit(caster, ability, targets, effects_applied)
			# Log the first tick
			for effect in effects_applied:
				if effect.type == "damage" and effect.has("target"):
					print("    -> %s takes %d damage (tick 1/%d)" % [_safe_display_name(effect.get("target")), effect.amount, cast_time])
	
	return true

## Resolve an instant ability
func _resolve_ability_instant(caster: CombatantData, ability: Ability, targets: Array):
	var effects_applied = _apply_ability_effects(caster, ability, targets)
	ability_resolved.emit(caster, ability, targets, effects_applied)
	print("  -> Resolved instantly")

## Resolve a completed cast
func _resolve_ability_cast(cast: ActiveCast):
	# Null check
	if not cast or not cast.caster:
		push_warning("CombatController: Attempted to resolve cast with null caster")
		return
	
	print("%s's %s resolves!" % [_safe_display_name(cast.caster), cast.ability.ability_name])
	
	# For channeled abilities, apply effects one last time on the final turn
	if cast.ability.ability_type == Ability.AbilityType.CHANNELED:
		var effects_applied = _apply_ability_effects(cast.caster, cast.ability, cast.targets)
		ability_resolved.emit(cast.caster, cast.ability, cast.targets, effects_applied)
	else:
		# Delayed casts only resolve once at the end
		var effects_applied = _apply_ability_effects(cast.caster, cast.ability, cast.targets)
		ability_resolved.emit(cast.caster, cast.ability, cast.targets, effects_applied)

## Apply ability effects to targets
func _apply_ability_effects(caster: CombatantData, ability: Ability, targets: Array) -> Array:
	var effects_applied = []
	var caster_stats = caster.combatant_stats.get_effective_stats()
	
	for effect in ability.effects:
		match effect.effect_type:
			AbilityEffect.EffectType.DAMAGE:
				var potency = effect.calculate_final_potency(caster_stats)
				var dmg_kind: CombatDamageKind.Kind = effect.get_effective_damage_kind()
				for target in targets:
					if target is CombatantData and target.can_be_targeted():
						var packet := DamagePacket.make(potency, dmg_kind, false)
						var damage_result = target.apply_incoming_damage(packet, caster)
						var actual_damage = damage_result.get("damage_dealt", 0)
						effects_applied.append({"type": "damage", "target": target, "amount": actual_damage})
						combatant_damaged.emit(target, actual_damage, caster)
						print("  -> %s takes %d damage" % [_safe_display_name(target), actual_damage])
			
			AbilityEffect.EffectType.HEAL:
				var potency = effect.calculate_final_potency(caster_stats)
				for target in targets:
					if target is CombatantData and target.can_be_targeted():
						target.combatant_stats.heal(potency)
						effects_applied.append({"type": "heal", "target": target, "amount": potency})
						combatant_healed.emit(target, potency, caster)
						print("  -> %s heals %.1f" % [_safe_display_name(target), potency])
			
			AbilityEffect.EffectType.APPLY_STATUS:
				if effect.status_to_apply:
					for target in targets:
						if target is CombatantData and target.can_be_targeted():
							target.combatant_stats.apply_status(effect.status_to_apply)
							effects_applied.append({"type": "status", "target": target, "status": effect.status_to_apply})
							status_applied.emit(target, effect.status_to_apply)
							print("  -> %s gains %s" % [_safe_display_name(target), effect.status_to_apply.status_name])
			
			AbilityEffect.EffectType.APPLY_GROUNDING:
				if effect.status_to_apply:
					for target in targets:
						if target is CombatantData and target.can_be_targeted() and target.innately_flying():
							target.combatant_stats.apply_status(effect.status_to_apply)
							effects_applied.append({"type": "grounding", "target": target, "status": effect.status_to_apply})
							status_applied.emit(target, effect.status_to_apply)
							print("  -> %s grounded (%s)" % [_safe_display_name(target), effect.status_to_apply.status_name])
			
			AbilityEffect.EffectType.MOVE_FORMATION:
				for target in targets:
					if target is CombatantData and target == caster:
						var cd: CombatantData = target as CombatantData
						if not cd.can_use_formation_move():
							continue
						cd.swap_formation_row()
						var row_name := "front" if cd.formation_row == CombatRow.Kind.FRONT else "back"
						effects_applied.append({"type": "move_zone", "target": cd})
						print("  -> %s moves to %s row" % [_safe_display_name(cd), row_name])
			
			AbilityEffect.EffectType.PUSH_TO_BACK:
				for target in targets:
					if target is CombatantData and target.can_be_targeted() and target != caster:
						var cd: CombatantData = target as CombatantData
						var was_front := cd.formation_row == CombatRow.Kind.FRONT
						cd.force_to_back_row()
						if was_front:
							effects_applied.append({"type": "push_back", "target": cd})
							print("  -> %s pushed to back row" % _safe_display_name(cd))
			
			AbilityEffect.EffectType.PULL_TO_FRONT:
				for target in targets:
					if target is CombatantData and target.can_be_targeted() and target != caster:
						var cd: CombatantData = target as CombatantData
						var was_back := cd.formation_row == CombatRow.Kind.BACK
						cd.force_to_front_row()
						if was_back:
							effects_applied.append({"type": "pull_front", "target": cd})
							print("  -> %s pulled to front row" % _safe_display_name(cd))
			
			AbilityEffect.EffectType.INTERRUPT_CAST:
				for target in targets:
					if target is CombatantData and target.can_be_targeted():
						if combat_timeline.has_active_cast(target):
							var interrupted_cast = combat_timeline.get_active_cast(target)
							if interrupted_cast.can_interrupt():
								combat_timeline.interrupt_casts(target)
								effects_applied.append({"type": "interrupt", "target": target})
								cast_interrupted.emit(target, interrupted_cast.ability)
								print("  -> Interrupted %s's %s" % [_safe_display_name(target), interrupted_cast.ability.ability_name])
	
	return effects_applied

## Validate ability targets
func _validate_targets(caster: CombatantData, ability: Ability, targets: Array) -> bool:
	# Self-targeting abilities
	if ability.targeting_type == Ability.TargetingType.SELF:
		return targets.size() == 1 and targets[0] == caster
	
	# AoE abilities don't need target validation (targets are auto-selected)
	if ability.targeting_type in [Ability.TargetingType.ALL_ALLIES, Ability.TargetingType.ALL_ENEMIES, Ability.TargetingType.ALL_COMBATANTS]:
		return true
	
	# Single target abilities
	if targets.size() != 1:
		return false
	
	var target = targets[0]
	if not target is CombatantData:
		return false
	
	if not ability.can_target(caster.is_player, target.is_player):
		return false
	if CombatTargetRules.ability_uses_opponent_formation_rules(ability):
		return CombatTargetRules.can_select_opponent(caster, ability, target, player_combatants, enemy_combatants)
	return true

## Get valid targets for an ability
func get_valid_targets(caster: CombatantData, ability: Ability) -> Array:
	var valid_targets = []
	
	match ability.targeting_type:
		Ability.TargetingType.SELF:
			valid_targets.append(caster)
		
		Ability.TargetingType.SINGLE_ALLY:
			if caster.is_player:
				for combatant in player_combatants:
					if combatant.can_be_targeted():
						valid_targets.append(combatant)
			else:
				for combatant in enemy_combatants:
					if combatant.can_be_targeted():
						valid_targets.append(combatant)
		
		Ability.TargetingType.SINGLE_ENEMY:
			if caster.is_player:
				for combatant in enemy_combatants:
					if combatant.can_be_targeted():
						valid_targets.append(combatant)
			else:
				for combatant in player_combatants:
					if combatant.can_be_targeted():
						valid_targets.append(combatant)
		
		Ability.TargetingType.ALL_ALLIES:
			if caster.is_player:
				valid_targets = player_combatants.duplicate()
			else:
				valid_targets = enemy_combatants.duplicate()
		
		Ability.TargetingType.ALL_ENEMIES:
			if caster.is_player:
				valid_targets = enemy_combatants.duplicate()
			else:
				valid_targets = player_combatants.duplicate()
		
		Ability.TargetingType.ALL_COMBATANTS:
			valid_targets = player_combatants.duplicate() + enemy_combatants.duplicate()
		
		Ability.TargetingType.RANDOM_ENEMY:
			if caster.is_player:
				for combatant in enemy_combatants:
					if combatant.can_be_targeted():
						valid_targets.append(combatant)
			else:
				for combatant in player_combatants:
					if combatant.can_be_targeted():
						valid_targets.append(combatant)
		
		Ability.TargetingType.RANDOM_ALLY:
			if caster.is_player:
				for combatant in player_combatants:
					if combatant.can_be_targeted():
						valid_targets.append(combatant)
			else:
				for combatant in enemy_combatants:
					if combatant.can_be_targeted():
						valid_targets.append(combatant)
	
	return CombatTargetRules.filter_by_attack_profile(caster, ability, valid_targets, player_combatants, enemy_combatants)

## Execute AI turn
func _execute_ai_turn():
	print("AI turn: %s (AP: %d/%d)" % [_safe_display_name(current_turn_combatant), current_turn_combatant.combatant_stats.current_ap, current_turn_combatant.combatant_stats.max_ap])
	
	# Pause after "Enemy's Turn" is logged so player can read it before the enemy acts
	await get_tree().create_timer(2.0).timeout
	
	# Note: can_act check is now done in _advance_to_next_turn after status processing
	
	# Prefer Move when not in preferred row (enemies with Front/Back bias only)
	if current_turn_combatant.wants_ai_to_reposition():
		var move_ab := _find_ability_by_id(current_turn_combatant, CombatantData.ABILITY_ID_MOVE)
		if move_ab != null:
			var move_cost := move_ab.get_modified_ap_cost()
			if current_turn_combatant.combatant_stats.current_ap >= move_cost and current_turn_combatant.can_use_formation_move():
				print("  -> AI repositions toward preferred zone")
				if _execute_ability_cast(current_turn_combatant, move_ab, [current_turn_combatant]):
					await get_tree().create_timer(1.0).timeout
					_end_current_turn()
					return
				print("  -> Move failed, falling through to other actions")
	
	# Get available abilities (Move is never random-picked when Indifferent / already in preferred row)
	var available_abilities: Array = []
	if current_turn_combatant.abilities:
		for ability in current_turn_combatant.abilities:
			if ability.ability_id == CombatantData.ABILITY_ID_MOVE:
				if not current_turn_combatant.wants_ai_to_reposition():
					continue
			var ap_cost = ability.get_modified_ap_cost()
			if current_turn_combatant.combatant_stats.current_ap >= ap_cost:
				available_abilities.append(ability)
	
	# If no abilities available, end turn
	if available_abilities.is_empty():
		print("  -> No usable abilities, ending turn")
		await get_tree().create_timer(1.0).timeout
		_end_current_turn()
		return
	
	# Pick random available ability (refine algorithm later)
	var chosen_ability: Ability = available_abilities[randi() % available_abilities.size()]
	
	# Get valid targets
	var valid_targets = get_valid_targets(current_turn_combatant, chosen_ability)
	
	if valid_targets.is_empty():
		print("  -> No valid targets for %s, ending turn" % chosen_ability.ability_name)
		await get_tree().create_timer(1.0).timeout
		_end_current_turn()
		return
	
	# Select targets based on targeting type
	var selected_targets = []
	match chosen_ability.targeting_type:
		Ability.TargetingType.SELF:
			selected_targets = [current_turn_combatant]
		
		Ability.TargetingType.SINGLE_ENEMY, Ability.TargetingType.SINGLE_ALLY, Ability.TargetingType.RANDOM_ENEMY, Ability.TargetingType.RANDOM_ALLY:
			# Pick random valid target
			selected_targets = [valid_targets[randi() % valid_targets.size()]]
		
		Ability.TargetingType.ALL_ALLIES, Ability.TargetingType.ALL_ENEMIES, Ability.TargetingType.ALL_COMBATANTS:
			# AoE - use all valid targets
			selected_targets = valid_targets
	
	# Execute the ability
	if _execute_ability_cast(current_turn_combatant, chosen_ability, selected_targets):
		# Brief pause before ending turn so player sees the result
		await get_tree().create_timer(1.0).timeout
		_end_current_turn()
	else:
		# If cast failed, end turn anyway
		print("  -> Cast failed, ending turn")
		await get_tree().create_timer(1.0).timeout
		_end_current_turn()

## End the current turn
func _end_current_turn():
	var was_player_turn := current_turn_combatant and current_turn_combatant.is_player
	if current_turn_combatant:
		turn_ended.emit(current_turn_combatant)
	
	waiting_for_player_input = false
	current_turn_combatant = null
	
	var end_delay := _get_delay("turn_end_delay_after_player", turn_end_delay_after_player)
	if was_player_turn and end_delay > 0:
		await get_tree().create_timer(end_delay).timeout
	if not combat_active:
		return
	# Advance to next turn
	_advance_to_next_turn()

## Check victory conditions
func _check_victory_conditions() -> bool:
	var players_alive = false
	var enemies_alive = false
	
	for combatant in player_combatants:
		if not combatant.is_dead:
			players_alive = true
			break
	
	for combatant in enemy_combatants:
		if not combatant.is_dead:
			enemies_alive = true
			break
	
	if not players_alive:
		_end_combat(false)
		return true
	
	if not enemies_alive:
		_end_combat(true)
		return true
	
	return false

## Called when a combatant dies
func _on_combatant_died(combatant: CombatantData):
	print("%s has died!" % _safe_display_name(combatant))
	combatant_died.emit(combatant)
	
	# Remove from timeline (if combat is still active)
	if combat_timeline:
		combat_timeline.unregister_combatant(combatant)
		# Interrupt any active casts
		combat_timeline.interrupt_casts(combatant)
	
	# If an enemy died, check victory immediately (all enemies dead)
	if not combatant.is_player:
		var enemies_alive = false
		for e in enemy_combatants:
			if not e.is_dead:
				enemies_alive = true
				break
		if not enemies_alive:
			_end_combat(true)

## End combat
func _end_combat(victory: bool):
	if not combat_active:
		return
	combat_active = false
	waiting_for_player_input = false
	
	print("=== COMBAT ENDED ===")
	print("Victory: %s" % victory)
	
	# Sync combat state back to party members
	for combatant in player_combatants:
		combatant.sync_back_to_source()
	
	# Build rewards from killed enemies only (awarded at end of combat)
	var rewards = {"victory": victory, "xp": 0, "gold": 0}
	if victory and current_encounter:
		for combatant in enemy_combatants:
			if combatant.is_dead and combatant.source is Enemy:
				rewards.xp += combatant.source.xp_reward
				rewards.gold += combatant.source.gold_reward
		rewards.xp += current_encounter.bonus_xp
		rewards.gold += current_encounter.bonus_gold
		# Randomize gold by ±25%
		var gold_mult: float = randf_range(0.75, 1.25)
		rewards.gold = max(0, int(rewards.gold * gold_mult))
	
	var was_test: bool = is_combat_test_session
	if was_test:
		rewards["_test_lab"] = true
	
	# Advance world time based on combat duration (skip in test lab)
	if not was_test and combat_timeline and TimeManager:
		var combat_duration: float = combat_timeline.global_time
		var turn_count: int = combat_timeline.global_turn_counter
		if combat_duration > 0.0:
			TimeManager.advance_time_from_combat(combat_duration, turn_count)
	
	combat_ended.emit(victory, rewards)
	if was_test:
		combat_test_session_ended.emit(victory, rewards)
	is_combat_test_session = false
	
	combat_timeline = null
	player_combatants.clear()
	enemy_combatants.clear()
	current_turn_combatant = null
	current_encounter = null

## End combat due to flee: same cleanup as _end_combat, but victory=false and rewards = XP only from killed enemies, no gold.
func _end_combat_fled():
	if not combat_active:
		return
	combat_active = false
	waiting_for_player_input = false

	print("=== COMBAT ENDED (FLED) ===")

	# Sync combat state back to party members
	for combatant in player_combatants:
		combatant.sync_back_to_source()

	# Rewards: only XP for enemies already killed; no gold, no bonus XP/gold
	var rewards = {"victory": false, "xp": 0, "gold": 0, "fled": true}
	if current_encounter:
		for combatant in enemy_combatants:
			if combatant.is_dead and combatant.source is Enemy:
				rewards.xp += combatant.source.xp_reward
	
	var was_test_flee: bool = is_combat_test_session
	if was_test_flee:
		rewards["_test_lab"] = true
	
	# Advance world time (skip in test lab)
	if not was_test_flee and combat_timeline and TimeManager:
		var combat_duration: float = combat_timeline.global_time
		var turn_count: int = combat_timeline.global_turn_counter
		if combat_duration > 0.0:
			TimeManager.advance_time_from_combat(combat_duration, turn_count)

	combat_ended.emit(false, rewards)
	if was_test_flee:
		combat_test_session_ended.emit(false, rewards)
	is_combat_test_session = false

	combat_timeline = null
	player_combatants.clear()
	enemy_combatants.clear()
	current_turn_combatant = null
	current_encounter = null
