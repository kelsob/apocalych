extends Control

## TownScreen - Town hub UI driven by town_services on the MapNode2D.
## Services not in town_node.town_services are hidden. Main connects town_closed, rest_from_town_requested, warmaster_training_requested.

signal town_closed()
signal rest_from_town_requested(town_node: MapNode2D, gold_cost: int)
signal warmaster_training_requested(member_index: int, gold_cost: int, xp_amount: int)

const INN_GOLD_COST := 5
const WARMASTER_GOLD_PER_XP := 10
const WARMASTER_XP_AMOUNT := 10

var _town_node: MapNode2D = null
var _party_members: Array = []
var _current_gold: int = 0

@onready var inn_button: Button = $VBoxContainer/InnButton
@onready var blacksmith_button: Button = $VBoxContainer/BlacksmithButton
@onready var vendor_button: Button = $VBoxContainer/VendorButton
@onready var warmaster_button: Button = $VBoxContainer/WarmasterButton
@onready var casino_button: Button = $VBoxContainer/CasinoButton
@onready var leave_button: Button = $VBoxContainer/LeaveButton

func _ready():
	visible = false
	leave_button.pressed.connect(_on_leave_pressed)
	inn_button.pressed.connect(_on_inn_pressed)
	blacksmith_button.pressed.connect(_on_blacksmith_pressed)
	vendor_button.pressed.connect(_on_vendor_pressed)
	casino_button.pressed.connect(_on_casino_pressed)
	warmaster_button.pressed.connect(_on_warmaster_pressed)

## Called by Main when opening town. Show only services in town_node.town_services.
func open_town(town_node: MapNode2D, party_members: Array, party_gold: int):
	_town_node = town_node
	_party_members = party_members
	_current_gold = party_gold
	var services: Array = town_node.town_services
	leave_button.visible = true
	inn_button.visible = "inn" in services
	blacksmith_button.visible = "blacksmith" in services
	vendor_button.visible = "merchant" in services
	casino_button.visible = "casino" in services
	warmaster_button.visible = "warmaster" in services
	inn_button.disabled = _current_gold < INN_GOLD_COST

func update_party_gold(new_gold: int):
	_current_gold = new_gold
	inn_button.disabled = _current_gold < INN_GOLD_COST

func _on_leave_pressed():
	town_closed.emit()

func _on_inn_pressed():
	rest_from_town_requested.emit(_town_node, INN_GOLD_COST)

func _on_blacksmith_pressed():
	print("TownScreen: Blacksmith - coming soon")

func _on_vendor_pressed():
	print("TownScreen: Merchant - coming soon")

func _on_casino_pressed():
	print("TownScreen: Casino - coming soon")

func _on_warmaster_pressed():
	warmaster_training_requested.emit(0, WARMASTER_GOLD_PER_XP, WARMASTER_XP_AMOUNT)
