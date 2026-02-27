extends CanvasLayer

## UIController - Middle layer owning all UI under Main
## Exposes UI children for Main and other scripts to access

@onready var main_menu: MainMenu = $MainMenu
@onready var party_select_menu: Control = $PartySelectMenu
@onready var event_window: EventWindow = $EventWindow
@onready var rest_controller: RestController = $RestController
@onready var map_ui: Control = $MapUI
@onready var town_screen: Control = $TownScreen
@onready var vendor_screen: Control = $VendorScreen
@onready var blacksmith_screen: Control = $BlacksmithScreen
@onready var character_details_screen: Control = $CharacterDetailsScreen

var _character_details_displayed_member: PartyMember = null  # Member currently shown in CharacterDetailsScreen
var _awaiting_potion_target: bool = false  # True when health potion clicked, waiting for player to choose target

signal potion_target_selected(member: PartyMember)

# Game state constants (matches Main.gd GameState enum values)
const MAIN_MENU = 0
const PARTY_SELECT = 1
const IN_GAME = 2

func _ready() -> void:
	_connect_character_details_buttons()
	if character_details_screen and character_details_screen.has_signal("closed"):
		character_details_screen.closed.connect(_on_character_details_screen_closed)

func _connect_character_details_buttons() -> void:
	var party_details: Node = get_node_or_null("MapUI/PartyDetails")
	if not party_details:
		return
	for cd in [party_details.get_node_or_null("CharacterDetails"), party_details.get_node_or_null("CharacterDetails2"), party_details.get_node_or_null("CharacterDetails3")]:
		if cd and cd.has_signal("character_clicked"):
			cd.character_clicked.connect(_on_character_clicked)

func _on_character_clicked(member: PartyMember) -> void:
	if not member:
		return
	if _awaiting_potion_target:
		potion_target_selected.emit(member)
		return
	if not character_details_screen:
		return
	if character_details_screen.visible and member == _character_details_displayed_member:
		character_details_screen.close()
		return
	if character_details_screen.has_method("open_character"):
		_character_details_displayed_member = member
		character_details_screen.open_character(member)

func request_potion_target_selection() -> void:
	_awaiting_potion_target = true
	if map_ui and map_ui.has_method("enter_potion_target_selection_mode"):
		map_ui.enter_potion_target_selection_mode()

func cancel_potion_target_selection() -> void:
	_awaiting_potion_target = false
	if map_ui and map_ui.has_method("exit_potion_target_selection_mode"):
		map_ui.exit_potion_target_selection_mode()

func _on_character_details_screen_closed() -> void:
	_character_details_displayed_member = null
