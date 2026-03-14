extends TextureProgressBar
class_name XPBar

## XP / experience bar with optional smooth tween animation.
## Use set_experience() for animated updates, or pass animated=false for instant changes.

@export var animation_duration: float = 0.5

var _xp_tween: Tween = null

## Set current XP and the threshold for the next level.
## Returns the Tween when animated so callers can await tween.finished for sequencing.
## Pass animated=false for instant changes (returns null).
func set_experience(current: int, to_next_level: int, animated: bool = true) -> Tween:
	max_value = to_next_level if to_next_level > 0 else 1
	min_value = 0
	var target := float(clampi(current, 0, to_next_level))
	if not animated or animation_duration <= 0.0:
		if _xp_tween:
			_xp_tween.kill()
		value = target
		return null
	if _xp_tween:
		_xp_tween.kill()
	_xp_tween = create_tween()
	_xp_tween.tween_property(self, "value", target, animation_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	return _xp_tween
