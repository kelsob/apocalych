extends Control

## CombatScene - UI controller for combat
## Displays combat state, handles player input, and shows animations

# Node references
@onready var current_turn_label: Label = $MarginContainer/VBoxContainer/CurrentTurnLabel
@onready var turn_order_display: HBoxContainer = $MarginContainer/VBoxContainer/TurnOrderPanel/VBoxContainer/ScrollContainer/TurnOrderDisplay
@onready var combat_area_player_panel: VBoxContainer = $MarginContainer/VBoxContainer/CombatAreaPanel/HBoxContainer/PlayerPanel
@onready var combat_area_enemy_panel: VBoxContainer = $MarginContainer/VBoxContainer/CombatAreaPanel/HBoxContainer/EnemyPanel
@onready var party_info_panel: VBoxContainer = $MarginContainer/VBoxContainer/CombatPanel/PartyPanel
@onready var ability_panel_container: VBoxContainer = $MarginContainer/VBoxContainer/CombatPanel/AbilityPanel/VBoxContainer
@onready var combat_log: RichTextLabel = $MarginContainer/VBoxContainer/CombatPanel/CombatLogContainer/CombatLogLabel

# Scene references for instantiation
var combat_character_sprite_scene: PackedScene = preload("res://scenes/combat/CombatCharacterSprite.tscn")
var character_info_panel_scene: PackedScene = preload("res://scenes/combat/CharacterCombatInformationPanel.tscn")
var turn_order_entry_scene: PackedScene = preload("res://scenes/combat/TurnOrderEntry.tscn")
var combat_ability_option_scene: PackedScene = preload("res://scenes/combat/CombatAbilityOption.tscn")

# Current combatant data
var current_player_combatant: CombatantData = null
var selected_ability: Ability = null

# Cached references
var combatant_sprites: Dictionary = {}  # CombatantData -> CombatCharacterSprite
var combatant_info_panels: Dictionary = {}  # CombatantData -> CharacterCombatInformationPanel
var combatant_clickable_areas: Dictionary = {}  # CombatantData -> Button (for targeting)
var ability_buttons: Array[Button] = []

func _ready():
	print("CombatScene _ready() called")
	
	# Verify all node references are valid
	if not current_turn_label:
		push_error("CombatScene: current_turn_label is null!")
	if not turn_order_display:
		push_error("CombatScene: turn_order_display is null!")
	if not party_info_panel:
		push_error("CombatScene: party_info_panel is null!")
	
	# Connect to CombatController signals
	CombatController.combat_started.connect(_on_combat_started)
	CombatController.combat_ended.connect(_on_combat_ended)
	CombatController.turn_started.connect(_on_turn_started)
	CombatController.ability_resolved.connect(_on_ability_resolved)
	CombatController.combatant_damaged.connect(_on_combatant_damaged)
	CombatController.combatant_healed.connect(_on_combatant_healed)
	CombatController.combatant_died.connect(_on_combatant_died)
	
	print("CombatScene initialized and signals connected")

## Called when combat starts
func _on_combat_started(player_combatants: Array, enemy_combatants: Array):
	print("CombatScene: _on_combat_started called with %d players, %d enemies" % [player_combatants.size(), enemy_combatants.size()])
	_log_message("=== COMBAT START ===")
	
	# Clear previous data
	combatant_sprites.clear()
	combatant_info_panels.clear()
	combatant_clickable_areas.clear()
	ability_buttons.clear()
	
	# Generate player combatants (sprites in combat area + info panels below)
	for combatant in player_combatants:
		print("CombatScene: Creating display for player: %s" % combatant.display_name)
		_create_player_combatant_display(combatant)
	
	# Generate enemy combatants (sprites in combat area only)
	for combatant in enemy_combatants:
		print("CombatScene: Creating display for enemy: %s" % combatant.display_name)
		_create_enemy_combatant_display(combatant)
	
	# Update turn order display
	print("CombatScene: Updating turn order display")
	_update_turn_order_display()
	print("CombatScene: Combat start complete")

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
func _on_turn_started(combatant: CombatantData, turn_number: int, status_results: Dictionary):
	_log_message("--- %s's Turn ---" % combatant.display_name)
	
	current_turn_label.text = "%s's Turn" % combatant.display_name
	
	# Log any status effects that triggered (DoTs, HoTs, etc.)
	for effect in status_results.get("effects_triggered", []):
		match effect.type:
			"damage":
				_log_message("  %s takes %.0f damage from %s" % [combatant.display_name, effect.amount, effect.status])
			"heal":
				_log_message("  %s heals %.0f from %s" % [combatant.display_name, effect.amount, effect.status])
	
	# Update turn order display
	_update_turn_order_display()
	
	# Update info panel for current combatant (AP refreshed, health may have changed from DoTs)
	_update_combatant_info_panel(combatant)
	
	# Check if combatant is stunned/incapacitated
	if not status_results.get("can_act", true):
		_log_message("  %s is stunned and cannot act!" % combatant.display_name)
		
		# Show which control effects wore off
		for status_name in status_results.get("control_statuses_consumed", []):
			_log_message("  %s's %s wore off!" % [combatant.display_name, status_name])
		
		current_player_combatant = null
		_clear_ability_panel()
		return
	
	# Log non-control statuses that wore off (buffs, debuffs, DoTs, HoTs)
	for status_name in status_results.get("statuses_expired", []):
		_log_message("  %s's %s wore off!" % [combatant.display_name, status_name])
	
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
	# Filter different effect types
	var damage_effects = effects_applied.filter(func(e): return e.type == "damage")
	var heal_effects = effects_applied.filter(func(e): return e.type == "heal")
	var status_effects = effects_applied.filter(func(e): return e.type == "status")
	var interrupt_effects = effects_applied.filter(func(e): return e.type == "interrupt")
	
	# Single-target damage - combine into one message
	if damage_effects.size() == 1 and heal_effects.is_empty() and status_effects.is_empty():
		var effect = damage_effects[0]
		_log_message("%s attacked %s with %s and dealt %.0f damage" % [
			caster.display_name,
			effect.target.display_name,
			ability.ability_name,
			effect.amount
		])
	# Single-target heal - combine into one message
	elif heal_effects.size() == 1 and damage_effects.is_empty() and status_effects.is_empty():
		var effect = heal_effects[0]
		_log_message("%s healed %s with %s for %.0f health" % [
			caster.display_name,
			effect.target.display_name,
			ability.ability_name,
			effect.amount
		])
	# Multi-target or mixed effects - show ability first, then individual effects
	else:
		_log_message("%s used %s" % [caster.display_name, ability.ability_name])
		
		# Show damage to each target
		for effect in damage_effects:
			_log_message("  → %s takes %.0f damage" % [effect.target.display_name, effect.amount])
		
		# Show healing to each target
		for effect in heal_effects:
			_log_message("  → %s heals %.0f" % [effect.target.display_name, effect.amount])
		
		# Show status effects applied
		for effect in status_effects:
			_log_message("  → %s is afflicted with %s" % [effect.target.display_name, effect.status.status_name])
		
		# Show interrupts
		for effect in interrupt_effects:
			_log_message("  → %s's cast was interrupted!" % effect.target.display_name)
	
	# Update caster's AP display (spent AP on ability)
	_update_combatant_info_panel(caster)

## Called when a combatant takes damage
func _on_combatant_damaged(combatant: CombatantData, amount: float, source: CombatantData):
	# Don't log here - it's handled in ability_resolved
	_update_combatant_health_display(combatant)

## Called when a combatant is healed
func _on_combatant_healed(combatant: CombatantData, amount: float, source: CombatantData):
	# Don't log here - it's handled in ability_resolved
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
	
	# Add regular abilities
	for ability in combatant.abilities:
		var ability_option = combat_ability_option_scene.instantiate()
		ability_panel_container.add_child(ability_option)
		ability_option.setup(ability)
		ability_option.pressed.connect(_on_ability_button_pressed.bind(ability))
		ability_buttons.append(ability_option)
	
	# Add separator or spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	ability_panel_container.add_child(spacer)
	
	# Add "Pass Turn" button
	var pass_turn_button = Button.new()
	pass_turn_button.text = "Pass Turn"
	pass_turn_button.custom_minimum_size = Vector2(150, 40)
	pass_turn_button.pressed.connect(_on_pass_turn_pressed)
	ability_panel_container.add_child(pass_turn_button)
	
	# Add "Flee" button
	var flee_button = Button.new()
	flee_button.text = "Flee"
	flee_button.custom_minimum_size = Vector2(150, 40)
	flee_button.pressed.connect(_on_flee_pressed)
	ability_panel_container.add_child(flee_button)

## Clear ability panel
func _clear_ability_panel():
	# Clear all children (abilities, spacers, action buttons)
	for child in ability_panel_container.get_children():
		child.queue_free()
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
			var ability_option = ability_buttons[i]
			var can_afford = ability.get_modified_ap_cost() <= current_ap
			ability_option.set_ability_enabled(can_afford)

## Update turn order display
func _update_turn_order_display():
	if not CombatController.combat_timeline:
		print("CombatScene: No combat timeline available")
		return
	
	if not turn_order_display:
		push_error("CombatScene: turn_order_display is null!")
		return
	
	# Clear existing display
	for child in turn_order_display.get_children():
		child.queue_free()
	
	# Get upcoming turns (show up to 25 turns into the future for scrolling)
	var preview = CombatController.combat_timeline.get_turn_preview(25)
	print("CombatScene: Got %d turns in preview" % preview.size())
	
	for i in range(preview.size()):
		var turn_event = preview[i]
		var entry = turn_order_entry_scene.instantiate()
		turn_order_display.add_child(entry)
		
		# Update display - first entry (i==0) is the next turn
		entry.update_display(
			turn_event.get_display_name(),
			turn_event.turn_time,
			i == 0  # is_next_turn
		)
	
	print("CombatScene: Turn order display updated with %d entries" % preview.size())

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

## Called when Pass Turn button pressed
func _on_pass_turn_pressed():
	if current_player_combatant:
		_log_message("%s passes their turn" % current_player_combatant.display_name)
		CombatController.player_end_turn()

## Called when Flee button pressed
func _on_flee_pressed():
	if current_player_combatant:
		_log_message("%s attempts to flee..." % current_player_combatant.display_name)
		_attempt_flee()

## Attempt to flee from combat
func _attempt_flee():
	var success = CombatController.attempt_flee()
	if success:
		_log_message("  Successfully fled from combat!")
		# Combat will end via CombatController
	else:
		_log_message("  Failed to flee! (Feature not yet implemented)")
		# Could end turn on failed flee attempt
		# CombatController.player_end_turn()

## Auto-select targets for an ability
func _auto_select_targets(ability: Ability) -> Array:
	if not current_player_combatant:
		return []
	
	return CombatController.get_valid_targets(current_player_combatant, ability)

## Log a message to combat log
func _log_message(message: String):
	print("[Combat] " + message)
	combat_log.text += message + "\n"
