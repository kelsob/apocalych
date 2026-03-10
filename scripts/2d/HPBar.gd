extends TextureProgressBar
class_name HPBar

## Health bar with smooth value interpolation. Use set_health() for animated updates.

@export var animation_duration: float = 0.35

var _health_tween: Tween = null

## Set health with optional smooth interpolation. Use this instead of setting value directly.
func set_health(current: int, maximum: int):
	max_value = maximum if maximum > 0 else 1
	min_value = 0
	var target := float(clampi(current, 0, maximum))
	if animation_duration <= 0.0:
		value = target
		return
	if _health_tween:
		_health_tween.kill()
	_health_tween = create_tween()
	_health_tween.tween_property(self, "value", target, animation_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
