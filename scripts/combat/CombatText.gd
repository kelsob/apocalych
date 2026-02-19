extends Label

## CombatText - Floating damage/heal/status text over a combatant. Play animation then free.
## Uses vertical_slot so multiple texts stack and don't overlap.

signal finished()

const FLOAT_DISTANCE: float = 40.0
const DURATION: float = 0.8
const VERTICAL_SLOT_OFFSET: float = 32.0

var _vertical_slot: int = 0

func _ready() -> void:
	call_deferred("_center_on_parent")

func _center_on_parent() -> void:
	var parent_control = get_parent_control()
	if parent_control:
		position = parent_control.size / 2 - size / 2 + Vector2(0, -_vertical_slot * VERTICAL_SLOT_OFFSET)

func setup(p_text: String, p_color: Color, vertical_slot: int = 0) -> void:
	_vertical_slot = vertical_slot
	text = p_text
	# Use modulate so we can animate alpha for fade-out; keep RGB from p_color
	modulate = Color(p_color.r, p_color.g, p_color.b, 1.0)
	# Defer animation start so _center_on_parent has run and position is set
	call_deferred("play_float_and_fade")

func play_float_and_fade() -> void:
	var start_pos := position
	var end_pos := start_pos + Vector2(0, -FLOAT_DISTANCE)
	var start_mod := modulate
	var end_mod := Color(modulate.r, modulate.g, modulate.b, 0.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", end_pos, DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", end_mod, DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_tween_finished)

func _on_tween_finished() -> void:
	finished.emit()
	queue_free()
