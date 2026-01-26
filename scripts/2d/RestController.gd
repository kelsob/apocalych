extends Control
class_name RestController

## RestController - Manages the rest screen and rest mechanics
## Handles UI for resting, resource recovery, and party management

# Signals
signal rest_complete()  # Emitted when rest is finished and should return to map

# References (set these via @onready or in editor)
@onready var rest_button: Button = $RestButton

# Rest state
var is_resting: bool = false

func _ready():
	# Hide rest screen initially
	visible = false

## Show the rest screen and begin resting
func start_rest():
	if is_resting:
		return
	
	is_resting = true
	visible = true
	
	print("RestController: Rest started")
	
	# TODO: Implement rest mechanics:
	# - Heal party members
	# - Restore resources
	# - Consume food/supplies
	# - Pass time
	# - Random rest events?

## Called when player confirms rest
func _on_rest_button_pressed():
	complete_rest()

## Finish resting and return to map
func complete_rest():
	if not is_resting:
		return
	
	is_resting = false
	
	# TODO: Apply rest benefits here
	# - Heal party HP
	# - Restore mana/stamina
	# - Remove certain debuffs
	
	print("RestController: Rest completed")
	
	# Hide rest screen
	visible = false
	
	# Emit signal to return to map
	rest_complete.emit()

## Cancel rest without benefits (if needed)
func cancel_rest():
	is_resting = false
	visible = false
	print("RestController: Rest cancelled")
