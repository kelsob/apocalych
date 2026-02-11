extends Control

## CombatScene - UI controller for combat
## Displays combat state, handles player input, and shows animations

# Node references
@onready var current_turn_label: Label = $MarginContainer/VBoxContainer/CurrentTurnLabel
@onready var turn_order_display: VBoxContainer = $MarginContainer/VBoxContainer/TurnOrderPanel/VBoxContainer/TurnOrderDisplay
@onready var combat_area_player_panel: VBoxContainer = $MarginContainer/VBoxContainer/CombatAreaPanel/HBoxContainer/PlayerPanel
@onready var combat_area_enemy_panel: VBoxContainer = $MarginContainer/VBoxContainer/CombatAreaPanel/HBoxContainer/EnemyPanel
@onready var party_info_panel: VBoxContainer = $MarginContainer/VBoxContainer/CombatPanel/PartyPanel
@onready var ability_panel: PanelContainer = $MarginContainer/VBoxContainer/CombatPanel/AbilityPanel
@onready var combat_log: RichTextLabel = $MarginContainer/VBoxContainer/CombatPanel/CombatLogContainer/CombatLogLabel

# Scene references for instantiation
var combat_character_sprite_scene: PackedScene = preload("res://scenes/combat/CombatCharacterSprite.tscn")
var character_info_panel_scene: PackedScene = preload("res://scenes/combat/CharacterCombatInformationPanel.tscn")

# Current combatant data
var current_player_combatant: CombatantData = null
var selected_ability: Ability = null

# Cached references
var combatant_sprites: Dictionary = {}  # CombatantData -> CombatCharacterSprite
var combatant_info_panels: Dictionary = {}  # CombatantData -> CharacterCombatInformationPanel
var combatant_clickable_areas: Dictionary = {}  # CombatantData -> Button (for targeting)
var ability_buttons: Array[Button] = []

func _ready():
	# Connect to CombatController signals
	CombatController.combat_started.connect(_on_combat_started)
	CombatController.combat_ended.connect(_on_combat_ended)
	CombatController.turn_started.connect(_on_turn_started)
	CombatController.ability_resolved.connect(_on_ability_resolved)
	CombatController.combatant_damaged.connect(_on_combatant_damaged)
	CombatController.combatant_healed.connect(_on_combatant_healed)
	CombatController.combatant_died.connect(_on_combatant_died)
	
	print("CombatScene initialized")

## Called when combat starts
func _on_combat_started(player_combatants: Array, enemy_combatants: Array):
	_log_message("=== COMBAT START ===")
	
	# Clear previous data
	combatant_sprites.clear()
	combatant_info_panels.clear()
	combatant_clickable_areas.clear()
	ability_buttons.clear()
	
	# Generate player combatants (sprites in combat area + info panels below)
	for combatant in player_combatants:
		_create_player_combatant_display(combatant)
	
	# Generate enemy combatants (sprites in combat area only)
	for combatant in enemy_combatants:
		_create_enemy_combatant_display(combatant)
	
	# Update turn order display
	_update_turn_order_display()

## Called when combat ends
func _on_combat_ended(victory: bool, rewards: Dictionary):
	if victory:
		_log_message("=== VICTORY ===")
	else:
		_log_message("=== DEFEAT ===")
	
	# Wait a moment to show results
	await get_tree().create_timer(2.0).timeout
	
	# Find Main node and restore map visibility
	var root = get_tree().root
	for child in root.get_children():
		if child.name == "Main":
			child.map_generator.visible = true
			child.ui_controller.map_ui.visible = true
			break
	
	# Clean up combat scene
	queue_free()

## Called when a turn starts
func _on_turn_started(combatant: CombatantData, turn_number: int):
	_log_message("--- %s's Turn ---" % combatant.display_name)
	
	current_turn_label.text = "%s's Turn" % combatant.display_name
	
	# Update turn order display
	_update_turn_order_display()
	
	# Update info panel for current combatant (AP refreshed)
	_update_combatant_info_panel(combatant)
	
	# If player turn, show abilities
	if combatant.is_player:
		current_player_combatant = combatant
		_show_abilities_for_combatant(combatant)
		_update_ability_button_states()
	else:
		current_player_combatant = null
		_clear_ability_panel()

## Called when an ability resolves
func _on_ability_resolved(caster: CombatantData, ability: Ability, targets: Array, effects_applied: Array):
	_log_message("%s used %s" % [caster.display_name, ability.ability_name])
	
	# Update caster's AP display (spent AP on ability)
	_update_combatant_info_panel(caster)

## Called when a combatant takes damage
func _on_combatant_damaged(combatant: CombatantData, amount: float, source: CombatantData):
	var source_name = source.display_name if source else "Unknown"
	_log_message("  %s takes %.0f damage from %s" % [combatant.display_name, amount, source_name])
	_update_combatant_health_display(combatant)

## Called when a combatant is healed
func _on_combatant_healed(combatant: CombatantData, amount: float, source: CombatantData):
	var source_name = source.display_name if source else "Unknown"
	_log_message("  %s heals %.0f from %s" % [combatant.display_name, amount, source_name])
	_update_combatant_health_display(combatant)

## Called when a combatant dies
func _on_combatant_died(combatant: CombatantData):
	_log_message("  %s has fallen!" % combatant.display_name)
	
	# Grey out sprite to show death
	if combatant_sprites.has(combatant):
		var sprite_control = combatant_sprites[combatant]
		sprite_control.set_sprite_modulation(Color(0.3, 0.3, 0.3, 0.7))
	
	# Update info panel
	if combatant_info_panels.has(combatant):
		var info_panel = combatant_info_panels[combatant]
		info_panel.modulate = Color(0.5, 0.5, 0.5, 0.8)
	
	# Disable clickability
	if combatant_clickable_areas.has(combatant):
		var button = combatant_clickable_areas[combatant]
		button.disabled = true

## Create player combatant display (sprite + info panel)
func _create_player_combatant_display(combatant: CombatantData):
	# Create sprite in combat area
	var sprite_instance = combat_character_sprite_scene.instantiate()
	combat_area_player_panel.add_child(sprite_instance)
	combatant_sprites[combatant] = sprite_instance
	
	# TODO: Set sprite texture based on class/character
	# sprite_instance.sprite.texture = load("res://assets/characters/%s.png" % combatant.display_name)
	
	# Create clickable button overlay for targeting (invisible, just for clicks)
	var click_button = Button.new()
	click_button.flat = true
	click_button.custom_minimum_size = sprite_instance.size
	click_button.pressed.connect(_on_combatant_clicked.bind(combatant))
	sprite_instance.add_child(click_button)
	combatant_clickable_areas[combatant] = click_button
	
	# Create info panel below in party panel
	var info_panel = character_info_panel_scene.instantiate()
	party_info_panel.add_child(info_panel)
	combatant_info_panels[combatant] = info_panel
	
	# Initialize info panel
	_update_combatant_info_panel(combatant)

## Create enemy combatant display (sprite only, no info panel)
func _create_enemy_combatant_display(combatant: CombatantData):
	# Create sprite in combat area
	var sprite_instance = combat_character_sprite_scene.instantiate()
	combat_area_enemy_panel.add_child(sprite_instance)
	combatant_sprites[combatant] = sprite_instance
	
	# TODO: Set sprite texture based on enemy type
	# sprite_instance.sprite.texture = load("res://assets/enemies/%s.png" % combatant.display_name)
	
	# Create clickable button overlay for targeting
	var click_button = Button.new()
	click_button.flat = true
	click_button.custom_minimum_size = sprite_instance.size
	click_button.pressed.connect(_on_combatant_clicked.bind(combatant))
	sprite_instance.add_child(click_button)
	combatant_clickable_areas[combatant] = click_button
	
	# Enemies don't get info panels (or optionally you could add them above the sprite)

## Show abilities for a combatant
func _show_abilities_for_combatant(combatant: CombatantData):
	_clear_ability_panel()
	
	for ability in combatant.abilities:
		var button = Button.new()
		button.text = "%s (%d AP)" % [ability.ability_name, ability.get_modified_ap_cost()]
		button.custom_minimum_size = Vector2(100, 50)
		button.pressed.connect(_on_ability_button_pressed.bind(ability))
		ability_panel.add_child(button)
		ability_buttons.append(button)

## Clear ability panel
func _clear_ability_panel():
	for button in ability_buttons:
		button.queue_free()
	ability_buttons.clear()
	selected_ability = null

## Update ability button states (enable/disable based on AP)
func _update_ability_button_states():
	if not current_player_combatant:
		return
	
	var current_ap = current_player_combatant.combatant_stats.current_ap
	
	for i in range(ability_buttons.size()):
		if i < current_player_combatant.abilities.size():
			var ability = current_player_combatant.abilities[i]
			var button = ability_buttons[i]
			button.disabled = (ability.get_modified_ap_cost() > current_ap)

## Update turn order display
func _update_turn_order_display():
	if not CombatController.combat_timeline:
		return
	
	# Clear existing display
	for child in turn_order_display.get_children():
		child.queue_free()
	
	# Get upcoming turns
	var preview = CombatController.combat_timeline.get_turn_preview(5)
	
	for turn_event in preview:
		var label = Label.new()
		label.text = "%s (%.2f)" % [turn_event.get_display_name(), turn_event.turn_time]
		turn_order_display.add_child(label)

## Update combatant info panel with current stats
func _update_combatant_info_panel(combatant: CombatantData):
	if combatant_info_panels.has(combatant):
		var info_panel = combatant_info_panels[combatant]
		info_panel.update_display(
			combatant.display_name,
			combatant.combatant_stats.current_health,
			combatant.combatant_stats.max_health,
			combatant.combatant_stats.current_ap,
			combatant.combatant_stats.max_ap
		)

## Update combatant health display
func _update_combatant_health_display(combatant: CombatantData):
	_update_combatant_info_panel(combatant)

## Called when ability button pressed
func _on_ability_button_pressed(ability: Ability):
	selected_ability = ability
	_log_message("Selected: %s" % ability.ability_name)
	
	# Auto-target based on ability type
	var targets = _auto_select_targets(ability)
	
	if targets.size() > 0:
		# Execute ability
		CombatController.player_cast_ability(ability, targets)
		selected_ability = null
	else:
		_log_message("  No valid targets!")

## Called when combatant clicked (for targeting)
func _on_combatant_clicked(combatant: CombatantData):
	if selected_ability and current_player_combatant:
		# Manual targeting
		var targets = [combatant]
		CombatController.player_cast_ability(selected_ability, targets)
		selected_ability = null


## Auto-select targets for an ability
func _auto_select_targets(ability: Ability) -> Array:
	if not current_player_combatant:
		return []
	
	return CombatController.get_valid_targets(current_player_combatant, ability)

## Log a message to combat log
func _log_message(message: String):
	print("[Combat] " + message)
	combat_log.text += message + "\n"
