extends Control
class_name UIController

## UI Controller - Manages visibility of ViewportFX based on game state
## Attach this script to the GameUI node

# References to UI elements (set these in the editor or via @onready)
@onready var viewport_fx: Node = $ViewportFX

# References to individual FX layers (optional - for granular control)
@onready var painterly_effect: CanvasLayer = $ViewportFX/PainterlyEffect
@onready var painterly_effect2: CanvasLayer = $ViewportFX/PainterlyEffect2
@onready var edge_reddening_effect: CanvasLayer = $ViewportFX/EdgeReddeningEffect
@onready var radial_reddening_effect: CanvasLayer = $ViewportFX/RadialReddeningEffect
@onready var blur_effect: CanvasLayer = $ViewportFX/BlurEffect

# Game state constants (matches Main.gd GameState enum values)
const MAIN_MENU = 0
const PARTY_SELECT = 1
const IN_GAME = 2

## Update UI visibility based on game state
## state: int - GameState enum value from Main.gd (0=MAIN_MENU, 1=PARTY_SELECT, 2=IN_GAME)
func update_ui_visibility(state: int):
	match state:
		MAIN_MENU:
			_set_viewport_fx_visible(false)
		PARTY_SELECT:
			_set_viewport_fx_visible(false)
		IN_GAME:
			_set_viewport_fx_visible(true)

## Set visibility of ViewportFX
func _set_viewport_fx_visible(visible: bool):
	# Hide/show the entire GameUI container
	self.visible = visible
	
	viewport_fx.visible = visible
	
	# Individual FX layer control (optional - uncomment if needed)
	# painterly_effect.visible = visible
	# painterly_effect2.visible = visible
	# edge_reddening_effect.visible = visible
	# radial_reddening_effect.visible = visible
	# blur_effect.visible = visible

## Initialize - hide UI by default
func _ready():
	# Start with UI hidden (will be shown when game starts)
	update_ui_visibility(MAIN_MENU)
