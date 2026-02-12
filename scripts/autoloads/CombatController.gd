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

# Combat state
var combat_active: bool = false
var combat_timeline: CombatTimeline = null
var player_combatants: Array[CombatantData] = []
var enemy_combatants: Array[CombatantData] = []
var current_turn_combatant: CombatantData = null
var current_encounter: Resource = null  # CombatEncounter resource

# Waiting for player input
var waiting_for_player_input: bool = false

func _ready():
	print("CombatController initialized")

## Start combat from an encounter and party members
func start_combat_from_encounter(encounter: Resource, party_members: Array):
	if combat_active:
		push_warning("CombatController: Combat already active")
		return
	
	print("=== COMBAT STARTING ===")
	combat_active = true
	current_encounter = encounter
	
	# Initialize timeline
	combat_timeline = CombatTimeline.new()
	
	# Initialize player combatants from party members
	player_combatants.clear()
	for member in party_members:
		if member is PartyMember:
			var combatant = CombatantData.new()
			combatant.initialize_from_party_member(member)
			combatant.died.connect(_on_combatant_died.bind(combatant))
			player_combatants.append(combatant)
			combat_timeline.register_combatant(combatant)
			print("Registered player: %s (Speed: %.2f, AP: %d)" % [combatant.display_name, combatant.get_effective_speed(), combatant.combatant_stats.base_ap_per_turn])
	
	# Initialize enemy combatants from encounter
	enemy_combatants.clear()
	if encounter is CombatEncounter:
		for enemy in encounter.enemies:
			var combatant = CombatantData.new()
			combatant.initialize_from_enemy(enemy)
			combatant.died.connect(_on_combatant_died.bind(combatant))
			enemy_combatants.append(combatant)
			combat_timeline.register_combatant(combatant)
			print("Registered enemy: %s (Speed: %.2f, AP: %d)" % [combatant.display_name, combatant.get_effective_speed(), combatant.combatant_stats.base_ap_per_turn])
	
	# Emit signal
	combat_started.emit(player_combatants, enemy_combatants)
	
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
	
	# Process any active casts for this combatant
	var completed_casts = combat_timeline.process_cast_ticks(current_turn_combatant)
	for cast in completed_casts:
		_resolve_ability_cast(cast)
	
	# Emit signal with status results
	turn_started.emit(current_turn_combatant, turn_event.turn_number, status_results)
	
	# Check if combatant can act after processing status effects
	if not status_results.can_act:
		print("%s cannot act (stunned/incapacitated), skipping turn" % current_turn_combatant.display_name)
		# Give a moment for the log to display status effects
		await get_tree().create_timer(1.0).timeout
		_end_current_turn()
		return
	
	# If player turn, wait for input
	if current_turn_combatant.is_player:
		waiting_for_player_input = true
		print("Player turn: %s (AP: %d/%d)" % [current_turn_combatant.display_name, current_turn_combatant.combatant_stats.current_ap, current_turn_combatant.combatant_stats.max_ap])
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
	
	print("Player ended turn: %s" % current_turn_combatant.display_name)
	_end_current_turn()

## Attempt to flee from combat (called by UI)
func attempt_flee() -> bool:
	if not waiting_for_player_input:
		return false
	
	# TODO: Implement flee chance calculation
	# Could be based on party speed vs enemy speed, luck stat, etc.
	# For now, just always fail
	print("Flee attempt failed (not yet implemented)")
	return false

## Execute ability cast
func _execute_ability_cast(caster: CombatantData, ability: Ability, targets: Array) -> bool:
	# Try to cast ability
	if not caster.cast_ability(ability, targets):
		return false
	
	print("%s casts %s (AP: %d, Cast Time: %d)" % [caster.display_name, ability.ability_name, ability.get_modified_ap_cost(), ability.get_modified_cast_time()])
	
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
	
	return true

## Resolve an instant ability
func _resolve_ability_instant(caster: CombatantData, ability: Ability, targets: Array):
	var effects_applied = _apply_ability_effects(caster, ability, targets)
	ability_resolved.emit(caster, ability, targets, effects_applied)
	print("  -> Resolved instantly")

## Resolve a completed cast
func _resolve_ability_cast(cast: ActiveCast):
	print("%s's %s resolves!" % [cast.caster.display_name, cast.ability.ability_name])
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
				for target in targets:
					if target is CombatantData and target.can_be_targeted():
						target.take_damage(potency, caster)
						effects_applied.append({"type": "damage", "target": target, "amount": potency})
						combatant_damaged.emit(target, potency, caster)
						print("  -> %s takes %.1f damage" % [target.display_name, potency])
			
			AbilityEffect.EffectType.HEAL:
				var potency = effect.calculate_final_potency(caster_stats)
				for target in targets:
					if target is CombatantData and target.can_be_targeted():
						target.combatant_stats.heal(potency)
						effects_applied.append({"type": "heal", "target": target, "amount": potency})
						combatant_healed.emit(target, potency, caster)
						print("  -> %s heals %.1f" % [target.display_name, potency])
			
			AbilityEffect.EffectType.APPLY_STATUS:
				if effect.status_to_apply:
					for target in targets:
						if target is CombatantData and target.can_be_targeted():
							target.combatant_stats.apply_status(effect.status_to_apply)
							effects_applied.append({"type": "status", "target": target, "status": effect.status_to_apply})
							status_applied.emit(target, effect.status_to_apply)
							print("  -> %s gains %s" % [target.display_name, effect.status_to_apply.status_name])
			
			AbilityEffect.EffectType.INTERRUPT_CAST:
				for target in targets:
					if target is CombatantData and target.can_be_targeted():
						if combat_timeline.has_active_cast(target):
							var interrupted_cast = combat_timeline.get_active_cast(target)
							if interrupted_cast.can_interrupt():
								combat_timeline.interrupt_casts(target)
								effects_applied.append({"type": "interrupt", "target": target})
								cast_interrupted.emit(target, interrupted_cast.ability)
								print("  -> Interrupted %s's %s" % [target.display_name, interrupted_cast.ability.ability_name])
	
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
	
	return ability.can_target(caster.is_player, target.is_player)

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
	
	return valid_targets

## Execute AI turn
func _execute_ai_turn():
	print("AI turn: %s (AP: %d/%d)" % [current_turn_combatant.display_name, current_turn_combatant.combatant_stats.current_ap, current_turn_combatant.combatant_stats.max_ap])
	
	# Small delay for readability
	await get_tree().create_timer(0.5).timeout
	
	# Note: can_act check is now done in _advance_to_next_turn after status processing
	
	# Get available abilities
	var available_abilities = []
	if current_turn_combatant.abilities:
		for ability in current_turn_combatant.abilities:
			# Check if enemy has enough AP to cast this ability
			var ap_cost = ability.get_modified_ap_cost()
			if current_turn_combatant.combatant_stats.current_ap >= ap_cost:
				available_abilities.append(ability)
	
	# If no abilities available, end turn
	if available_abilities.is_empty():
		print("  -> No usable abilities, ending turn")
		_end_current_turn()
		return
	
	# Simple AI: Pick first available ability
	var chosen_ability = available_abilities[0]
	
	# Get valid targets
	var valid_targets = get_valid_targets(current_turn_combatant, chosen_ability)
	
	if valid_targets.is_empty():
		print("  -> No valid targets for %s, ending turn" % chosen_ability.ability_name)
		_end_current_turn()
		return
	
	# Select targets based on targeting type
	var selected_targets = []
	match chosen_ability.targeting_type:
		Ability.TargetingType.SELF:
			selected_targets = [current_turn_combatant]
		
		Ability.TargetingType.SINGLE_ENEMY, Ability.TargetingType.SINGLE_ALLY:
			# Simple AI: Pick first valid target
			selected_targets = [valid_targets[0]]
		
		Ability.TargetingType.ALL_ALLIES, Ability.TargetingType.ALL_ENEMIES, Ability.TargetingType.ALL_COMBATANTS:
			# AoE - use all valid targets
			selected_targets = valid_targets
	
	# Execute the ability
	if _execute_ability_cast(current_turn_combatant, chosen_ability, selected_targets):
		# End turn after successful cast
		_end_current_turn()
	else:
		# If cast failed, end turn anyway
		print("  -> Cast failed, ending turn")
		_end_current_turn()

## End the current turn
func _end_current_turn():
	if current_turn_combatant:
		turn_ended.emit(current_turn_combatant)
	
	waiting_for_player_input = false
	current_turn_combatant = null
	
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
	print("%s has died!" % combatant.display_name)
	combatant_died.emit(combatant)
	
	# Remove from timeline
	combat_timeline.unregister_combatant(combatant)
	
	# Interrupt any active casts
	combat_timeline.interrupt_casts(combatant)

## End combat
func _end_combat(victory: bool):
	print("=== COMBAT ENDED ===")
	print("Victory: %s" % victory)
	
	combat_active = false
	waiting_for_player_input = false
	
	# Sync combat state back to party members
	for combatant in player_combatants:
		combatant.sync_back_to_source()
	
	# Calculate rewards (placeholder)
	var rewards = {}
	if victory and current_encounter:
		# TODO: Load rewards from encounter
		pass
	
	# Emit signal
	combat_ended.emit(victory, rewards)
	
	# Clean up
	combat_timeline = null
	player_combatants.clear()
	enemy_combatants.clear()
	current_turn_combatant = null
	current_encounter = null
