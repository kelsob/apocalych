extends Control

## MapUI - Overlay UI for map gameplay (RestButton, TownButton, LocationDetailDisplay, PartyDetails)

signal rest_requested()
signal town_requested()
signal health_potion_use_requested()

@onready var location_detail_display: Control = $LocationDetailDisplay
@onready var party_details: VBoxContainer = $PartyDetails
@onready var rest_button: Button = $HBoxContainer/RestButton
@onready var town_button: Button = $HBoxContainer/TownButton
@onready var reset_map_button: Button = $HBoxContainer/ResetMapButton

@onready var gold_count_label: Label = $ResourcesDisplay/GridContainer/MarginContainer/HBoxContainer/CountLabel
@onready var health_potion_count_label: Label = $ResourcesDisplay/GridContainer/MarginContainer2/HBoxContainer/CountLabel
@onready var camping_supplies_count_label: Label = $ResourcesDisplay/GridContainer/MarginContainer4/HBoxContainer/CountLabel
@onready var sharpening_stones_count_label: Label = $ResourcesDisplay/GridContainer/MarginContainer3/HBoxContainer/CountLabel
@onready var arcane_powder_count_label: Label = $ResourcesDisplay/GridContainer/MarginContainer5/HBoxContainer/CountLabel

@onready var health_potion_button: Button = $ResourcesDisplay/GridContainer/MarginContainer2/Button

@onready var party_tag_display_label: Label = $PartyTagsLabel

func _ready():
	rest_button.pressed.connect(_on_rest_button_pressed)
	rest_button.visible = false
	town_button.pressed.connect(_on_town_button_pressed)
	town_button.visible = false
	reset_map_button.pressed.connect(_on_reset_map_button_pressed)
	if health_potion_button:
		health_potion_button.pressed.connect(_on_health_potion_button_pressed)
	_refresh_party_tags_display()
	if Engine.is_editor_hint() == false and TagManager:
		TagManager.tags_changed.connect(_refresh_party_tags_display)

func _on_health_potion_button_pressed():
	health_potion_use_requested.emit()

func enter_potion_target_selection_mode():
	if party_details and party_details.has_method("enter_potion_target_mode"):
		party_details.enter_potion_target_mode()

func exit_potion_target_selection_mode():
	if party_details and party_details.has_method("exit_potion_target_mode"):
		party_details.exit_potion_target_mode()

func _on_reset_map_button_pressed():
	if has_node("%MapGenerator"):
		%MapGenerator.regenerate_map()

func _on_rest_button_pressed():
	rest_requested.emit()

func update_rest_button_visibility(can_rest: bool):
	rest_button.visible = can_rest

func update_town_button_visibility(can_show: bool):
	if town_button:
		town_button.visible = can_show

func _on_town_button_pressed():
	town_requested.emit()

func _refresh_party_tags_display() -> void:
	if not party_tag_display_label:
		return
	if TagManager:
		var tags: Array[String] = TagManager.get_all_tags()
		var stripped: Array[String] = []
		for tag in tags:
			stripped.append(tag.trim_prefix("<").trim_suffix(">"))
		party_tag_display_label.text = "\n".join(stripped) if stripped.size() > 0 else "(no tags)"
	else:
		party_tag_display_label.text = "(TagManager unavailable)"

func initialize_party_ui(members: Array[PartyMember]) -> void:
	party_details.initialize_party(members)

## Update the 5 resource labels. Call whenever gold or bulk items change.
## party_resources: optional dict (item_id -> count) for party-wide bulk items; if null/empty, counts default to 0.
func update_resource_labels(party_members: Array, party_gold: int, party_resources: Dictionary = {}) -> void:
	if gold_count_label:
		gold_count_label.text = str(party_gold)
	var health_potions := int(party_resources.get("health_potion", 0))
	var camping_supplies := int(party_resources.get("camping_supplies", 0))
	var sharpening_stones := int(party_resources.get("sharpening_stone", 0))
	var arcane_powder := int(party_resources.get("magical_dust", 0))
	if health_potion_count_label:
		health_potion_count_label.text = str(health_potions)
	if camping_supplies_count_label:
		camping_supplies_count_label.text = str(camping_supplies)
	if sharpening_stones_count_label:
		sharpening_stones_count_label.text = str(sharpening_stones)
	if arcane_powder_count_label:
		arcane_powder_count_label.text = str(arcane_powder)
