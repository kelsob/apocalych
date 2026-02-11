extends RefCounted
class_name CombatantData

## CombatantData - Runtime wrapper that connects PartyMember/Enemy to combat systems
## Provides a unified interface for combat logic regardless of combatant source

signal turn_started()
signal ability_cast(ability: Ability, targets: Array)
signal took_damage(amount: float, source: CombatantData)
signal died()

# Source reference (PartyMember or Enemy resource)
var source: Variant = null
var is_player: bool = false

# Combat stats
var combatant_stats: CombatantStats = null

# Available abilities
var abilities: Array[Ability] = []

# Combat state
var display_name: String = ""
var is_dead: bool = false
var current_target: CombatantData = null

# Timeline tracking
var next_turn_time: float = 0.0
var turn_count: int = 0

## Initialize from a PartyMember
func initialize_from_party_member(member: PartyMember):
	source = member
	is_player = true
	display_name = member.member_name
	
	# Create and initialize combat stats
	combatant_stats = CombatantStats.new()
	combatant_stats.initialize_from_party_member(member)
	
	# Connect signals
	combatant_stats.died.connect(_on_died)
	
	# Load abilities from class
	if member.class_resource:
		_load_abilities_from_class(member.class_resource)
	
	# Calculate first turn time (will be set by CombatTimeline)
	next_turn_time = 0.0

## Initialize from an Enemy resource
func initialize_from_enemy(enemy: Enemy):
	source = enemy
	is_player = false
	display_name = enemy.enemy_name
	
	# Create combat stats from enemy definition
	combatant_stats = enemy.create_combat_stats()
	
	# Connect signals
	combatant_stats.died.connect(_on_died)
	
	# Copy abilities
	abilities = enemy.abilities.duplicate()
	
	# Calculate first turn time (will be set by CombatTimeline)
	next_turn_time = 0.0

## Load abilities from a Class resource
func _load_abilities_from_class(class_resource: Class):
	abilities = class_resource.abilities.duplicate()

## Start a turn for this combatant
func start_turn():
	turn_count += 1
	
	# Tick status effects
	combatant_stats.tick_statuses()
	
	# Regenerate AP
	combatant_stats.regenerate_ap()
	
	# Emit signal
	turn_started.emit()

## Cast an ability at target(s)
func cast_ability(ability: Ability, targets: Array) -> bool:
	# Check if can act
	if not combatant_stats.can_act():
		return false
	
	# Check if can cast
	if not combatant_stats.can_cast():
		return false
	
	# Check AP cost
	var ap_cost = ability.get_modified_ap_cost()
	if not combatant_stats.spend_ap(ap_cost):
		return false
	
	# Emit signal
	ability_cast.emit(ability, targets)
	
	return true

## Take damage from a source
func take_damage(amount: float, source_combatant: CombatantData = null):
	var survived = combatant_stats.take_damage(amount)
	took_damage.emit(amount, source_combatant)
	
	if not survived:
		is_dead = true

## Sync combat state back to source (called after combat ends)
func sync_back_to_source():
	if source is PartyMember:
		source.current_health = combatant_stats.current_health
		# Could sync other persistent effects here (e.g., permanent stat changes)

## Get effective speed for turn calculation
func get_effective_speed() -> float:
	return combatant_stats.get_effective_speed()

## Check if this combatant can be targeted
func can_be_targeted() -> bool:
	return not is_dead

## Called when combatant dies
func _on_died():
	is_dead = true
	died.emit()
