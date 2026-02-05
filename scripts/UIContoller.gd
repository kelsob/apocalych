extends CanvasLayer

## UIController - Middle layer owning all UI under Main
## Exposes UI children for Main and other scripts to access

@onready var viewport_fx: Control = $ViewportFX
@onready var main_menu: MainMenu = $MainMenu
@onready var party_select_menu: PartySelectMenu = $PartySelectMenu
@onready var event_window: EventWindow = $EventWindow
@onready var rest_controller: RestController = $RestController
@onready var map_ui: Control = $MapUI

# Game state constants (matches Main.gd GameState enum values)
const MAIN_MENU = 0
const PARTY_SELECT = 1
const IN_GAME = 2

## Update UI visibility based on game state
func update_ui_visibility(state: int) -> void:
	match state:
		MAIN_MENU:
			_set_viewport_fx_visible(false)
		PARTY_SELECT:
			_set_viewport_fx_visible(false)
		IN_GAME:
			_set_viewport_fx_visible(true)

func _set_viewport_fx_visible(visible: bool) -> void:
	viewport_fx.visible = visible
