extends PanelContainer

## CharacterWeaponPanel - Displays a party member's weapon and upgrade options.
## Call setup() to populate. Emits upgrade_gold_requested / upgrade_stone_requested when buttons pressed.

signal upgrade_gold_requested()
signal upgrade_stone_requested()

@onready var _texture_rect: TextureRect = $MarginContainer/VBoxContainer/TextureRect
@onready var _weapon_name_label: Label = $MarginContainer/VBoxContainer/Label
@onready var _upgrade_tier_label: Label = $MarginContainer/VBoxContainer/HBoxContainer2/Label2
@onready var _upgrade_row: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer2
@onready var _cost_buttons_row: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer
@onready var _gold_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/Button
@onready var _stone_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/Button2

func _ready() -> void:
	if _gold_button:
		_gold_button.pressed.connect(_on_gold_pressed)
	if _stone_button:
		_stone_button.pressed.connect(_on_stone_pressed)

## Populate the panel with weapon data and upgrade costs.
## Pass null for texture to keep default. Set is_max_tier true to hide upgrade options.
func setup(
	weapon_name: String,
	target_tier_name: String,
	gold_cost: int,
	stone_cost: int,
	texture: Texture2D = null,
	is_max_tier: bool = false,
	can_afford_gold: bool = false,
	can_afford_stones: bool = false
) -> void:
	if _weapon_name_label:
		_weapon_name_label.text = weapon_name
	if _texture_rect and texture:
		_texture_rect.texture = texture

	if is_max_tier:
		if _upgrade_tier_label:
			_upgrade_tier_label.text = "Max tier"
		if _upgrade_row:
			_upgrade_row.visible = true
		if _cost_buttons_row:
			_cost_buttons_row.visible = false
	else:
		if _upgrade_tier_label:
			_upgrade_tier_label.text = target_tier_name
		if _upgrade_row:
			_upgrade_row.visible = true
		if _cost_buttons_row:
			_cost_buttons_row.visible = true
		if _gold_button:
			_gold_button.text = str(gold_cost)
			_gold_button.disabled = not can_afford_gold
		if _stone_button:
			_stone_button.text = str(stone_cost)
			_stone_button.disabled = not can_afford_stones

func _on_gold_pressed() -> void:
	upgrade_gold_requested.emit()

func _on_stone_pressed() -> void:
	upgrade_stone_requested.emit()
