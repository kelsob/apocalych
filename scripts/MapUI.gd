extends Control

## MapUI - Overlay UI for map gameplay (RestButton, LocationDetailDisplay, PartyDetails)

signal rest_requested()

@onready var location_detail_display: Control = $LocationDetailDisplay
@onready var party_details: Control = $PartyDetails
@onready var rest_button: Button = $HBoxContainer/RestButton
@onready var reset_map_button: Button = $HBoxContainer/ResetMapButton

func _ready():
	rest_button.pressed.connect(_on_rest_button_pressed)
	rest_button.visible = false
	reset_map_button.pressed.connect(_on_reset_map_button_pressed)

func _on_reset_map_button_pressed():
	if has_node("%MapGenerator"):
		%MapGenerator.regenerate_map()

func _on_rest_button_pressed():
	rest_requested.emit()

func update_rest_button_visibility(can_rest: bool):
	rest_button.visible = can_rest

func initialize_party_ui(members: Array[PartyMember]) -> void:
	party_details.initialize_party(members)