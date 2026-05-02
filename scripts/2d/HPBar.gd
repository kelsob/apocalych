extends TextureProgressBar
class_name HPBar

## Health bar with smooth value interpolation. Use set_health() for animated updates.
## Horizontal length scales with max HP: [code]effective_max_hp * hp_bar_width_per_max_hp + hp_bar_width_added[/code].

@export_group("Bar width from max HP")
@export var scale_width_from_max_hp: bool = true
## Length along X when [member scale_width_from_max_hp] is on: [code]max(1, maximum_hp) * hp_bar_width_per_max_hp + hp_bar_width_added[/code].
@export var hp_bar_width_per_max_hp: float = 4.0
@export var hp_bar_width_added: float = 4.0

@export var animation_duration: float = 0.35

var _health_tween: Tween = null


## Bar width uses [member hp_bar_width_per_max_hp] and [member hp_bar_width_added]; [code]effective_max_hp[/code] is at least [code]1[/code] when [code]maximum[/code] is zero.
func _compute_bar_width_for_max_hp(maximum_hp: int) -> float:
	var eff: int = maxi(maximum_hp, 1)
	return float(eff) * hp_bar_width_per_max_hp + hp_bar_width_added


## Set health with optional smooth interpolation. Use this instead of setting value directly.
func set_health(current: int, maximum: int) -> void:
	max_value = float(maximum if maximum > 0 else 1)
	min_value = 0
	if scale_width_from_max_hp:
		custom_minimum_size.x = _compute_bar_width_for_max_hp(maximum)
	var target_max: int = maxi(maximum, 0)
	var target := float(clampi(current, 0, target_max))
	if animation_duration <= 0.0:
		value = target
		return
	if _health_tween:
		_health_tween.kill()
	_health_tween = create_tween()
	_health_tween.tween_property(self, "value", target, animation_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
