extends RefCounted
class_name CombatTimeline

## CombatTimeline - Manages turn order based on speed stats
## Handles the speed-based turn system where faster characters get more turns

signal turn_ready(turn_event: TurnEvent)
signal timeline_advanced(new_time: float)

# Global time tracker (starts at 0, increments based on turn frequency)
var global_time: float = 0.0

# All combatants in combat
var combatants: Array[CombatantData] = []

# Active casts being tracked
var active_casts: Array[ActiveCast] = []

# Turn queue (sorted by turn_time)
var turn_queue: Array[TurnEvent] = []

# Turn counter for display
var global_turn_counter: int = 0

## Register a combatant and schedule their first turn
func register_combatant(combatant: CombatantData):
	if combatant in combatants:
		return
	
	combatants.append(combatant)
	
	# Calculate first turn time
	var speed = combatant.get_effective_speed()
	var first_turn_time = _calculate_next_turn_time(speed, global_time)
	
	# Create and queue first turn
	var turn_event = TurnEvent.new(combatant, first_turn_time, 0)
	_insert_turn_into_queue(turn_event)
	
	combatant.next_turn_time = first_turn_time

## Unregister a combatant (when they die)
func unregister_combatant(combatant: CombatantData):
	combatants.erase(combatant)
	
	# Remove their turns from the queue
	for i in range(turn_queue.size() - 1, -1, -1):
		if turn_queue[i].combatant == combatant:
			turn_queue.remove_at(i)

## Calculate next turn time based on speed
## Formula: current_time + (1.0 / speed)
## Speed 10 = turn every 0.1 time units
## Speed 15 = turn every 0.0667 time units (faster)
## Speed 5 = turn every 0.2 time units (slower)
func _calculate_next_turn_time(speed: float, current_time: float) -> float:
	return current_time + (1.0 / speed)

## Advance timeline to the next turn
## Returns the TurnEvent that is now active, or null if combat ended
func advance_timeline() -> TurnEvent:
	if turn_queue.is_empty():
		return null
	
	# Get the next turn
	var next_turn = turn_queue.pop_front()
	
	# Update global time
	global_time = next_turn.turn_time
	global_turn_counter += 1
	timeline_advanced.emit(global_time)
	
	# Schedule the combatant's next turn
	_schedule_next_turn_for_combatant(next_turn.combatant)
	
	# Emit signal
	turn_ready.emit(next_turn)
	
	return next_turn

## Schedule the next turn for a combatant
func _schedule_next_turn_for_combatant(combatant: CombatantData):
	if combatant.is_dead:
		return
	
	var speed = combatant.get_effective_speed()
	var next_turn_time = _calculate_next_turn_time(speed, global_time)
	
	var turn_event = TurnEvent.new(combatant, next_turn_time, combatant.turn_count)
	_insert_turn_into_queue(turn_event)
	
	combatant.next_turn_time = next_turn_time

## Insert a turn into the queue in sorted order (by turn_time)
## If tied, prioritize by speed (higher speed goes first)
func _insert_turn_into_queue(turn_event: TurnEvent):
	var inserted = false
	
	for i in range(turn_queue.size()):
		var existing_turn = turn_queue[i]
		
		# Compare turn times
		if turn_event.turn_time < existing_turn.turn_time:
			turn_queue.insert(i, turn_event)
			inserted = true
			break
		elif turn_event.turn_time == existing_turn.turn_time:
			# Tied - compare speeds (higher speed goes first)
			if turn_event.combatant.get_effective_speed() > existing_turn.combatant.get_effective_speed():
				turn_queue.insert(i, turn_event)
				inserted = true
				break
	
	if not inserted:
		turn_queue.append(turn_event)

## Queue an ability cast
func queue_ability_cast(caster: CombatantData, ability: Ability, targets: Array):
	var cast = ActiveCast.new(caster, ability, targets)
	active_casts.append(cast)

## Process cast ticks for a combatant's turn
## Returns array of casts that completed this turn
func process_cast_ticks(combatant: CombatantData) -> Array[ActiveCast]:
	var completed_casts: Array[ActiveCast] = []
	
	for i in range(active_casts.size() - 1, -1, -1):
		var cast = active_casts[i]
		
		if cast.caster == combatant:
			if cast.tick():
				# Cast completed
				completed_casts.append(cast)
				active_casts.remove_at(i)
	
	return completed_casts

## Interrupt all casts by a combatant
func interrupt_casts(combatant: CombatantData):
	for i in range(active_casts.size() - 1, -1, -1):
		var cast = active_casts[i]
		
		if cast.caster == combatant and cast.can_interrupt():
			active_casts.remove_at(i)

## Get preview of upcoming turns (for UI display)
## Simulates future turns without modifying the actual queue
func get_turn_preview(count: int = 10) -> Array[TurnEvent]:
	var preview: Array[TurnEvent] = []
	
	# Start with current queue
	var simulated_queue = turn_queue.duplicate()
	
	# Track next turn time for each combatant
	var combatant_next_times: Dictionary = {}
	for combatant in combatants:
		if not combatant.is_dead:
			combatant_next_times[combatant] = combatant.next_turn_time
	
	# Generate turns until we have enough
	while preview.size() < count:
		if simulated_queue.is_empty():
			# Queue is empty, need to generate more turns
			# Find the combatant with the earliest next turn time
			var earliest_combatant: CombatantData = null
			var earliest_time: float = INF
			
			for combatant in combatant_next_times:
				if not combatant.is_dead:
					var next_time = combatant_next_times[combatant]
					if next_time < earliest_time:
						earliest_time = next_time
						earliest_combatant = combatant
			
			if earliest_combatant == null:
				break  # No more combatants
			
			# Create turn event for this combatant
			var turn_event = TurnEvent.new(earliest_combatant, earliest_time, 0)
			simulated_queue.append(turn_event)
			
			# Schedule their next turn
			var speed = earliest_combatant.get_effective_speed()
			combatant_next_times[earliest_combatant] = earliest_time + (1.0 / speed)
		
		# Sort simulated queue by time
		simulated_queue.sort_custom(func(a, b): return a.turn_time < b.turn_time)
		
		# Take the next turn from simulated queue
		if not simulated_queue.is_empty():
			var next_turn = simulated_queue.pop_front()
			preview.append(next_turn)
			
			# Schedule this combatant's next turn in the simulation
			if not next_turn.combatant.is_dead:
				var speed = next_turn.combatant.get_effective_speed()
				var next_time = next_turn.turn_time + (1.0 / speed)
				
				# Insert the next turn for this combatant into simulated queue
				var new_turn = TurnEvent.new(next_turn.combatant, next_time, 0)
				simulated_queue.append(new_turn)
	
	return preview

## Check if a specific combatant has any active casts
func has_active_cast(combatant: CombatantData) -> bool:
	for cast in active_casts:
		if cast.caster == combatant:
			return true
	return false

## Get active cast for a combatant (returns null if none)
func get_active_cast(combatant: CombatantData) -> ActiveCast:
	for cast in active_casts:
		if cast.caster == combatant:
			return cast
	return null
