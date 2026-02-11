extends Resource
class_name StatusEffect

## StatusEffect - Buffs, debuffs, DoTs, HoTs, shields, etc.
## Can modify stats, apply periodic effects, and have special flags

enum StatusType {
	BUFF,
	DEBUFF,
	DOT,  # Damage over time
	HOT,  # Heal over time
	SHIELD,
	STUN,
	ROOT,
	SILENCE,
	IMMUNITY
}

enum StackBehavior {
	REFRESH,  # Resets duration
	STACK,    # Adds another instance
	REPLACE   # Removes old, applies new
}

@export var status_name: String = ""
@export var status_id: String = ""
@export var description: String = ""
@export var status_type: StatusType = StatusType.BUFF
@export var base_duration: int = 1  # Turns
@export var stack_behavior: StackBehavior = StackBehavior.REFRESH

# Stat modifiers (applied while status is active)
@export var stat_modifiers: Dictionary = {}  # e.g., {"speed": -5, "strength": 2}

# Periodic effects (applied each turn)
@export var tick_damage: float = 0.0
@export var tick_heal: float = 0.0
@export var tick_ap_restore: float = 0.0

# Shield amount (absorbed before health damage)
@export var shield_amount: float = 0.0

# Special flags
@export var prevents_actions: bool = false  # Like stun
@export var prevents_movement: bool = false  # Like root
@export var prevents_casting: bool = false  # Like silence
@export var grants_uninterruptible: bool = false
@export var is_dispellable: bool = true

# Runtime data (not exported, set during combat)
var remaining_duration: int = 0
var current_shield_amount: float = 0.0
var stack_count: int = 1

## Initialize a new status instance
func create_instance() -> StatusEffect:
	var instance = self.duplicate(true)
	instance.remaining_duration = base_duration
	instance.current_shield_amount = shield_amount
	instance.stack_count = 1
	return instance

## Process a tick (called each turn on the affected combatant)
## Returns damage/heal amounts that should be applied
func process_tick() -> Dictionary:
	remaining_duration -= 1
	
	return {
		"damage": tick_damage,
		"heal": tick_heal,
		"ap_restore": tick_ap_restore
	}

## Check if status has expired
func is_expired() -> bool:
	return remaining_duration <= 0
