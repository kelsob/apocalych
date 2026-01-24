extends Control
class_name MainMenu

## Main Menu - handles main menu UI and signals

signal start_game_pressed
signal options_pressed
signal quit_pressed

func _on_new_game_button_pressed() -> void:
	start_game_pressed.emit()

func _on_options_button_pressed() -> void:
	# Options functionality to be implemented later
	options_pressed.emit()

func _on_quit_button_pressed() -> void:
	quit_pressed.emit()
