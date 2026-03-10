extends Resource
class_name StatusEffect

## StatusEffect - Buffs, debuffs, DoTs, HoTs, shields, control effects, etc.

enum StatusType {
	BUFF,      ## 0 — positive effect
	DEBUFF,    ## 1 — negative stat modifier
	DOT,       ## 2 — damage over time
	HOT,       ## 3 — heal over time
	SHIELD,    ## 4 — absorbs incoming damage
	STUN,      ## 5 — prevents all action
	ROOT,      ## 6 — prevents movement
	SILENCE,   ## 7 — prevents casting
	IMMUNITY,  ## 8 — immune to a damage type
	BLEED,     ## 9 — physical DoT, can bypass defense
	POISON,    ## 10 — nature DoT
	FEAR       ## 11 — terror: prevents action, enemy may flee
}

enum StackBehavior {
	REFRESH,  ## Reset duration
	STACK,    ## Add another instance (stack_count increases)
	REPLACE   ## Remove old, apply new
}

@export var status_name: String = ""
@export var status_id: String = ""
@export var description: String = ""
@export var status_type: StatusType = StatusType.BUFF
@export var base_duration: int = 1  ## Turns
@export var stack_behavior: StackBehavior = StackBehavior.REFRESH

# Stat modifiers applied while status is active (keys match core_stats: "atk","def","spd","mag","mag_def")
@export var stat_modifiers: Dictionary = {}

# Periodic effects (applied each turn)
@export var tick_damage: float = 0.0
@export var tick_heal: float = 0.0
@export var tick_ap_restore: float = 0.0

# Shield amount (absorbed before health damage)
@export var shield_amount: float = 0.0

# Behavior flags
@export var prevents_actions: bool = false    ## Stun / Fear
@export var prevents_movement: bool = false   ## Root
@export var prevents_casting: bool = false    ## Silence
@export var grants_uninterruptible: bool = false
@export var is_dispellable: bool = true

## BLEED: if true, tick_damage ignores the target's def
@export var bypass_defense: bool = false

## BLIND: miss chance added on top of normal accuracy (0.0–1.0, e.g. 0.5 = 50% miss)
@export var blind_miss_chance: float = 0.0

# Runtime data (not exported — set during combat)
var remaining_duration: int = 0
var current_shield_amount: float = 0.0
var stack_count: int = 1

## Create a fresh instance ready for combat
func create_instance() -> StatusEffect:
	var instance := self.duplicate(true)
	instance.remaining_duration = base_duration
	instance.current_shield_amount = shield_amount
	instance.stack_count = 1
	return instance

## Process one tick. Returns amounts to apply to the combatant.
func process_tick() -> Dictionary:
	remaining_duration -= 1
	return {
		"damage": tick_damage,
		"heal": tick_heal,
		"ap_restore": tick_ap_restore,
		"bypass_defense": bypass_defense
	}

## True when the status has expired
func is_expired() -> bool:
	return remaining_duration <= 0
