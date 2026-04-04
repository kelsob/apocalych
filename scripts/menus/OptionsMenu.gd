extends Control
class_name OptionsMenu

@onready var reset_data_button: Button = $CenterContainer/VBoxContainer/ResetDataButton
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

signal closed
signal meta_progression_reset


func _ready() -> void:
	visible = false
	back_button.pressed.connect(_on_back_pressed)
	reset_data_button.pressed.connect(_on_reset_meta_pressed)


func open_options() -> void:
	visible = true


func close_options() -> void:
	visible = false
	closed.emit()


func _on_back_pressed() -> void:
	close_options()


func _on_reset_meta_pressed() -> void:
	MetaProgression.reset_all_meta()
	meta_progression_reset.emit()
