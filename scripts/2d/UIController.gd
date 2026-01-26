extends Control
class_name UIController

## UI Controller - Manages visibility of UI elements based on game state
## Attach this script to the GameUI node

# Signals
signal rest_requested()  # Emitted when player clicks the rest button

# References to UI elements (set these in the editor or via @onready)
@onready var in_game_controls: Control = $InGameControls
@onready var viewport_fx: Node = $ViewportFX

# References to individual FX layers (optional - for granular control)
@onready var painterly_effect: CanvasLayer = $ViewportFX/PainterlyEffect
@onready var painterly_effect2: CanvasLayer = $ViewportFX/PainterlyEffect2
@onready var edge_reddening_effect: CanvasLayer = $ViewportFX/EdgeReddeningEffect
@onready var radial_reddening_effect: CanvasLayer = $ViewportFX/RadialReddeningEffect
@onready var blur_effect: CanvasLayer = $ViewportFX/BlurEffect

@onready var rest_button : Button = $InGameControls/RestButton

# Game state constants (matches Main.gd GameState enum values)
const MAIN_MENU = 0
const PARTY_SELECT = 1
const IN_GAME = 2

## Update UI visibility based on game state
## state: int - GameState enum value from Main.gd (0=MAIN_MENU, 1=PARTY_SELECT, 2=IN_GAME)
func update_ui_visibility(state: int):
	match state:
		MAIN_MENU:
			_set_in_game_ui_visible(false)
		PARTY_SELECT:
			_set_in_game_ui_visible(false)
		IN_GAME:
			_set_in_game_ui_visible(true)

## Set visibility of all in-game UI elements
func _set_in_game_ui_visible(visible: bool):
	# Hide/show the entire GameUI container
	self.visible = visible
	
	# Individual element control (if you want more granular control)
	if in_game_controls:
		in_game_controls.visible = visible
	
	if viewport_fx:
		viewport_fx.visible = visible
	
	# Individual FX layer control (optional - uncomment if needed)
	# if painterly_effect:
	# 	painterly_effect.visible = visible
	# if painterly_effect2:
	# 	painterly_effect2.visible = visible
	# if edge_reddening_effect:
	# 	edge_reddening_effect.visible = visible
	# if radial_reddening_effect:
	# 	radial_reddening_effect.visible = visible
	# if blur_effect:
	# 	blur_effect.visible = visible

## Initialize - hide UI by default
func _ready():
	# Start with UI hidden (will be shown when game starts)
	update_ui_visibility(MAIN_MENU)
	
	# Connect rest button
	if rest_button:
		rest_button.pressed.connect(_on_rest_button_pressed)
		rest_button.visible = false  # Hidden by default, shown when party can rest

## Called when rest button is pressed
func _on_rest_button_pressed():
	rest_requested.emit()

## Update rest button visibility based on whether party can rest at current node
## can_rest: bool - Whether the party can rest at the current location
func update_rest_button_visibility(can_rest: bool):
	if rest_button:
		rest_button.visible = can_rest
