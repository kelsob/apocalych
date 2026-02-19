extends TextureRect

const PLACEHOLDER_ICON_PATH: String = "res://assets/status-effects/stunned.png"

@onready var stack_count_label: Label = $StackCountLabel

func _ready() -> void:
	var tex = load(PLACEHOLDER_ICON_PATH) as Texture2D
	if tex:
		texture = tex

func set_stack_count(count: int) -> void:
	if stack_count_label:
		stack_count_label.text = str(count) if count > 0 else ""
