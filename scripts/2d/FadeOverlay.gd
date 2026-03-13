extends ColorRect
class_name FadeOverlay

## FadeOverlay - Full-screen black ColorRect used for scene transitions.
## Lives in a high-layer CanvasLayer so it renders above all other UI.
## Scene expects: Full Rect anchors, black color.

@export var fade_duration: float = 0.3

func _ready():
	modulate.a = 0.0
	visible = false

## Fade from transparent to fully black. Awaitable.
func fade_to_black() -> void:
	modulate.a = 0.0
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)
	await tween.finished

## Fade from fully black to transparent. Awaitable.
func fade_from_black() -> void:
	modulate.a = 1.0
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	await tween.finished
	visible = false
