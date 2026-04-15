extends RefCounted
class_name CombatantData

## CombatantData - Runtime wrapper that connects HeroCharacter/Enemy to combat systems
## Provides a unified interface for combat logic regardless of combatant source

signal turn_started()
signal ability_cast(ability: Ability, targets: Array)
signal took_damage(amount: float, source: CombatantData)
signal died()

# Source reference (HeroCharacter or Enemy resource)
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

const STATUS_ID_GROUNDED := "grounded"
const ABILITY_ID_MOVE := "move"
const MOVE_ABILITY_PATH := "res://resources/abilities/shared/move.tres"

static var _move_ability_cache: Ability = null

enum PreferredFormation {
	FRONT,
	BACK,
	INDIFFERENT
}

## Front / back — who blocks melee on this side of the fight (runtime; can change when grounded).
var formation_row: CombatRow.Kind = CombatRow.Kind.FRONT
## Snapshot from hero/enemy resource at combat start; restored when [const STATUS_ID_GROUNDED] expires.
var formation_row_base: CombatRow.Kind = CombatRow.Kind.FRONT
## Enemies: where AI tries to stand (heroes default to INDIFFERENT).
var preferred_formation: PreferredFormation = PreferredFormation.INDIFFERENT

## Initialize from a HeroCharacter
func initialize_from_hero_character(member: HeroCharacter):
	source = member
	is_player = true
	display_name = member.member_name
	
	# Create and initialize combat stats
	combatant_stats = CombatantStats.new()
	combatant_stats.initialize_from_hero_character(member)
	combatant_stats.combatant_owner = self
	
	# Connect signals
	combatant_stats.died.connect(_on_died)
	combatant_stats.status_removed.connect(_on_status_removed)
	
	# Load abilities from class
	if member.class_resource:
		_load_abilities_from_class(member.class_resource)
	_ensure_move_ability()
	
	var row_i: int = member.resolve_initial_formation_row()
	assert(row_i == 0 or row_i == 1, "combat positioning: '%s' resolved invalid row index %d (expected 0=Front, 1=Back)" % [display_name, row_i])
	formation_row = CombatRow.Kind.FRONT if row_i == 0 else CombatRow.Kind.BACK
	formation_row_base = formation_row
	print("combat positioning: CombatantData init player '%s' formation_row=%s (resolved_index=%d)" % [display_name, "FRONT" if formation_row == CombatRow.Kind.FRONT else "BACK", row_i])
	
	# Calculate first turn time (will be set by CombatTimeline)
	next_turn_time = 0.0

## Initialize from an Enemy resource
func initialize_from_enemy(enemy: Enemy):
	source = enemy
	is_player = false
	display_name = enemy.enemy_name
	
	# Create combat stats from enemy definition
	combatant_stats = enemy.create_combat_stats()
	combatant_stats.combatant_owner = self
	
	# Connect signals
	combatant_stats.died.connect(_on_died)
	combatant_stats.status_removed.connect(_on_status_removed)
	
	# Copy abilities
	abilities = enemy.abilities.duplicate()
	_ensure_move_ability()
	
	match enemy.preferred_zone:
		0:
			preferred_formation = PreferredFormation.FRONT
		1:
			preferred_formation = PreferredFormation.BACK
		_:
			preferred_formation = PreferredFormation.INDIFFERENT
	
	formation_row = CombatRow.Kind.FRONT if enemy.formation_row == 0 else CombatRow.Kind.BACK
	formation_row_base = formation_row
	
	# Calculate first turn time (will be set by CombatTimeline)
	next_turn_time = 0.0

## Load abilities from a Class resource
func _load_abilities_from_class(class_resource: Class):
	abilities = class_resource.abilities.duplicate()


func _ensure_move_ability() -> void:
	for a in abilities:
		if a is Ability and (a as Ability).ability_id == ABILITY_ID_MOVE:
			return
	if _move_ability_cache == null:
		if not ResourceLoader.exists(MOVE_ABILITY_PATH):
			push_warning("CombatantData: Move ability missing at %s" % MOVE_ABILITY_PATH)
			return
		var loaded = load(MOVE_ABILITY_PATH)
		if loaded is Ability:
			_move_ability_cache = loaded
		else:
			push_warning("CombatantData: %s is not an Ability" % MOVE_ABILITY_PATH)
			return
	abilities.append(_move_ability_cache)

## Start a turn for this combatant
## Returns status effect processing results
func start_turn() -> Dictionary:
	turn_count += 1
	
	# Process status effects FIRST (poison damages, regen heals, etc.)
	var status_results = combatant_stats.process_status_effects()
	
	# Regenerate AP (even if stunned)
	combatant_stats.regenerate_ap()
	
	# Emit signal
	turn_started.emit()
	
	return status_results

## Cast an ability at target(s)
func cast_ability(ability: Ability, targets: Array) -> bool:
	# Check if can act
	if not combatant_stats.can_act():
		return false
	
	# Check if can cast
	if not combatant_stats.can_cast():
		return false
	
	if ability.ability_id == ABILITY_ID_MOVE and not can_use_formation_move():
		push_warning("%s cannot change row while grounded." % display_name)
		return false
	
	# Check AP cost
	var ap_cost = ability.get_modified_ap_cost()
	if not combatant_stats.spend_ap(ap_cost):
		return false
	
	# Emit signal
	ability_cast.emit(ability, targets)
	
	return true

## Apply damage using the full pipeline (mitigation, creature tags, shields, HP).
func apply_incoming_damage(packet: DamagePacket, source_combatant: CombatantData = null) -> Dictionary:
	var resolved: Dictionary = CombatDamageResolver.resolve_incoming(self, packet)
	var damage_result: Dictionary = combatant_stats.apply_resolved_hit(resolved.final_amount)
	damage_result["breakdown"] = resolved.breakdown
	took_damage.emit(packet.base_amount, source_combatant)
	return damage_result


## Back-compat: raw physical hit with full def mitigation (no packet).
func take_damage(amount: float, source_combatant: CombatantData = null, packet: DamagePacket = null) -> Dictionary:
	if packet != null:
		return apply_incoming_damage(packet, source_combatant)
	return apply_incoming_damage(DamagePacket.physical_simple(amount), source_combatant)

## Sync combat state back to source (called after combat ends)
func sync_back_to_source():
	if source is HeroCharacter:
		source.current_health = combatant_stats.current_health
		# Could sync other persistent effects here (e.g., permanent stat changes)

## Get effective speed for turn calculation
func get_effective_speed() -> float:
	return combatant_stats.get_effective_speed()

## Check if this combatant can be targeted
func can_be_targeted() -> bool:
	return not is_dead


func is_stealthed() -> bool:
	return combatant_stats.has_status_id("stealth")


## True if this unit has the flying tag (ignores grounded). Used for grounding abilities.
func innately_flying() -> bool:
	if source is Enemy:
		var e: Enemy = source as Enemy
		return (e.get_creature_tag_mask() & Enemy.TAG_FLYING) != 0
	return false


## Airborne targets can only be damaged by ranged abilities while flying; grounded status negates.
func is_effective_flying() -> bool:
	if combatant_stats.has_status_id(STATUS_ID_GROUNDED):
		return false
	return innately_flying()


## Called when a grounding ability applies [const STATUS_ID_GROUNDED] to an innate flyer.
func apply_grounding_formation():
	formation_row = CombatRow.Kind.FRONT


func restore_formation_row_after_grounded():
	formation_row = formation_row_base


func can_use_formation_move() -> bool:
	return not combatant_stats.has_status_id(STATUS_ID_GROUNDED)


func swap_formation_row() -> void:
	if formation_row == CombatRow.Kind.FRONT:
		formation_row = CombatRow.Kind.BACK
	else:
		formation_row = CombatRow.Kind.FRONT
	formation_row_base = formation_row


## Forced reposition (push/pull abilities). Updates base row like voluntary move. Allowed while grounded.
func force_to_back_row() -> void:
	if formation_row == CombatRow.Kind.BACK:
		return
	formation_row = CombatRow.Kind.BACK
	formation_row_base = formation_row


func force_to_front_row() -> void:
	if formation_row == CombatRow.Kind.FRONT:
		return
	formation_row = CombatRow.Kind.FRONT
	formation_row_base = formation_row


## AI uses Move only when this is true (preferred row != current and not grounded).
func wants_ai_to_reposition() -> bool:
	if preferred_formation == PreferredFormation.INDIFFERENT:
		return false
	if not can_use_formation_move():
		return false
	match preferred_formation:
		PreferredFormation.FRONT:
			return formation_row != CombatRow.Kind.FRONT
		PreferredFormation.BACK:
			return formation_row != CombatRow.Kind.BACK
	return false


func _on_status_removed(status: StatusEffect):
	if status.status_id == STATUS_ID_GROUNDED:
		restore_formation_row_after_grounded()

## Called when combatant dies
func _on_died():
	is_dead = true
	died.emit()
