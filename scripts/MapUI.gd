extends Control

## MapUI - Overlay UI for map gameplay (RestButton, LocationDetailDisplay, PartyDetails)

signal rest_requested()

@onready var location_detail_display: Control = $LocationDetailDisplay
@onready var party_details: Control = $PartyDetails
@onready var rest_button: Button = $HBoxContainer/RestButton
@onready var reset_map_button: Button = $HBoxContainer/ResetMapButton

@onready var gold_count_label: Label = $PartyDetails/ResourcesDisplay/GridContainer/GoldDisplayContainer/MarginContainer/HBoxContainer/CountLabel
@onready var health_potion_count_label: Label = $PartyDetails/ResourcesDisplay/GridContainer/HealthPotionDisplayContainer/MarginContainer/HBoxContainer/CountLabel
@onready var camping_supplies_count_label: Label = $PartyDetails/ResourcesDisplay/GridContainer/CampingSuppliesDisplayContainer/MarginContainer/HBoxContainer/CountLabel
@onready var sharpening_stones_count_label: Label = $PartyDetails/ResourcesDisplay/GridContainer/SharpeningStonesDisplayContainer/MarginContainer/HBoxContainer/CountLabel
@onready var arcane_powder_count_label: Label = $PartyDetails/ResourcesDisplay/GridContainer/ArcanePowderDisplayContainer/MarginContainer/HBoxContainer/CountLabel

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

## Update the 5 resource labels. Call whenever gold or bulk items change.
func update_resource_labels(party_members: Array, party_gold: int) -> void:
	if gold_count_label:
		gold_count_label.text = str(party_gold)
	var health_potions := 0
	var camping_supplies := 0
	var sharpening_stones := 0
	var arcane_powder := 0
	for m in party_members:
		if m is PartyMember:
			health_potions += m.get_item_count("health_potion")
			camping_supplies += m.get_item_count("camping_supplies")
			sharpening_stones += m.get_item_count("sharpening_stone")
			arcane_powder += m.get_item_count("magical_dust")
	if health_potion_count_label:
		health_potion_count_label.text = str(health_potions)
	if camping_supplies_count_label:
		camping_supplies_count_label.text = str(camping_supplies)
	if sharpening_stones_count_label:
		sharpening_stones_count_label.text = str(sharpening_stones)
	if arcane_powder_count_label:
		arcane_powder_count_label.text = str(arcane_powder)
