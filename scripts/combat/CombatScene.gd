extends Control

## CombatScene - UI controller for combat
## Displays combat state, handles player input, and shows animations

# --- Combat timing (exports override CombatController when this scene is in the tree) ---
@export_group("Combat Delays")
## Delay before the first turn begins (seconds). Overrides CombatController when set > 0.
@export var combat_start_delay: float = 3.0
## Delay after a player's turn ends, before the next character's turn (seconds). Overrides CombatController when set >= 0.
@export var turn_end_delay_after_player: float = 1.0
## Delay after VICTORY/DEFEAT/FLED message before showing rewards or returning to map (seconds).
@export var combat_end_delay: float = 2.0

@export_group("Turn Announcer Animation")
## Turn announcer fade-in duration (seconds).
@export var turn_announcer_fade_in: float = 0.25
## Turn announcer scale-in duration (seconds).
@export var turn_announcer_scale_in: float = 0.5
## Turn announcer fade-out duration (seconds).
@export var turn_announcer_fade_out: float = 0.35
## Turn announcer scale-out duration (seconds).
@export var turn_announcer_scale_out: float = 0.35

# Node references
@onready var current_turn_label: Label = $MarginContainer/VBoxContainer/PanelContainer/MarginContainer/CurrentTurnLabel
@onready var turn_order_panel: Node = $MarginContainer/VBoxContainer/TurnOrderPanel
@onready var combat_area_player_panel: HBoxContainer = $MarginContainer/VBoxContainer/CombatAreaPanel/PlayerPanel
@onready var combat_area_enemy_panel: HBoxContainer = $MarginContainer/VBoxContainer/CombatAreaPanel/EnemyPanel
@onready var party_info_panel: VBoxContainer = $MarginContainer/VBoxContainer/CombatPanel/PartyPanel/MarginContainer/VBoxContainer
@onready var ability_panel_container: VBoxContainer = $MarginContainer/VBoxContainer/CombatPanel/AbilityPanel/MarginContainer/VBoxContainer
@onready var combat_log: RichTextLabel = $MarginContainer/VBoxContainer/CombatPanel/CombatLogPanel/MarginContainer/CombatLogContainer/CombatLogLabel
@onready var turn_announcer_label: Label = $TurnAnnouncerLabel


# Scene references for instantiation
var combat_character_sprite_scene: PackedScene = preload("res://scenes/combat/CombatCharacterSprite.tscn")
var character_info_panel_scene: PackedScene = preload("res://scenes/combat/CharacterCombatInformationPanel.tscn")
var combat_ability_option_scene: PackedScene = preload("res://scenes/combat/CombatAbilityOption.tscn")
var combat_rewards_scene: PackedScene = preload("res://scenes/combat/CombatRewards.tscn")

# Current combatant data
var current_player_combatant: CombatantData = null
var selected_ability: Ability = null

# Targeting state: ability always goes through targeting (except SELF)
var is_targeting: bool = false
var pending_ability: Ability = null
var valid_targets: Array = []  # Array of CombatantData

# Cached references
var combatant_sprites: Dictionary = {}  # CombatantData -> CombatCharacterSprite
var combatant_info_panels: Dictionary = {}  # CombatantData -> CharacterCombatInformationPanel
var combatant_clickable_areas: Dictionary = {}  # CombatantData -> Button (for targeting)
var ability_buttons: Array[Button] = []

# Deaths that happened during an ability; we log them right after the ability log so order is correct
var _pending_death_logs: Array = []  # [CombatantData, ...]

func _ready():
	print("CombatScene _ready() called")
	add_to_group("combat_scene")
	
	# Verify all node references are valid
	if not current_turn_label:
		push_error("CombatScene: current_turn_label is null!")
	if not turn_order_panel:
		push_error("CombatScene: turn_order_panel is null!")
	if not party_info_panel:
		push_error("CombatScene: party_info_panel is null!")
	
	# Cancel targeting on ESC
	set_process_unhandled_input(true)
	
	# Connect to CombatController signals
	CombatController.combat_started.connect(_on_combat_started)
	CombatController.combat_ended.connect(_on_combat_ended)
	CombatController.turn_started.connect(_on_turn_started)
	CombatController.cast_started.connect(_on_cast_started)
	CombatController.channeled_tick.connect(_on_channeled_tick)
	CombatController.ability_resolved.connect(_on_ability_resolved)
	CombatController.combatant_damaged.connect(_on_combatant_damaged)
	CombatController.combatant_healed.connect(_on_combatant_healed)
	CombatController.combatant_died.connect(_on_combatant_died)
	CombatController.status_applied.connect(_on_status_applied)
	
	if turn_order_panel:
		if turn_order_panel.has_signal("combatant_hover_highlighted"):
			turn_order_panel.combatant_hover_highlighted.connect(_on_turn_order_combatant_highlighted)
		if turn_order_panel.has_signal("combatant_hover_unhighlighted"):
			turn_order_panel.combatant_hover_unhighlighted.connect(_on_turn_order_combatant_unhighlighted)
	
	if turn_announcer_label:
		turn_announcer_label.visible = false
	
	if combat_log:
		combat_log.bbcode_enabled = true
	
	print("CombatScene initialized and signals connected")

## Show turn announcer: "X's Turn" with color, fade in/out, scale grow.
func _show_turn_announcer(combatant: CombatantData) -> void:
	if not turn_announcer_label:
		return
	var base_color: Color = Color(0.2, 1.0, 0.3) if combatant.is_player else Color(1.0, 0.2, 0.2)
	turn_announcer_label.text = "%s's Turn" % _safe_combatant_name(combatant)
	turn_announcer_label.visible = true
	turn_announcer_label.modulate = Color(base_color.r, base_color.g, base_color.b, 0.0)
	turn_announcer_label.scale = Vector2(0.7, 0.7)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(turn_announcer_label, "modulate", Color(base_color.r, base_color.g, base_color.b, 1.0), turn_announcer_fade_in)
	tween.tween_property(turn_announcer_label, "scale", Vector2(1.0, 1.0), turn_announcer_scale_in)
	await tween.finished
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(turn_announcer_label, "modulate", Color(base_color.r, base_color.g, base_color.b, 0.0), turn_announcer_fade_out)
	tween.tween_property(turn_announcer_label, "scale", Vector2(1.2, 1.2), turn_announcer_scale_out)
	await tween.finished
	turn_announcer_label.visible = false
	turn_announcer_label.modulate = base_color
	turn_announcer_label.scale = Vector2(1.0, 1.0)

## Safe display name for logging; avoids Nil access when target died or was removed
func _safe_combatant_name(c) -> String:
	if c == null or not is_instance_valid(c):
		return "Unknown"
	if c is CombatantData:
		return (c as CombatantData).display_name
	return str(c)

## Log any queued "X has fallen!" messages (so deaths appear after damage, before next turn)
func _flush_pending_death_logs():
	for combatant in _pending_death_logs:
		_log_message("  %s has fallen!" % _safe_combatant_name(combatant))
	_pending_death_logs.clear()

## Called when combat starts
func _on_combat_started(player_combatants: Array, enemy_combatants: Array):
	print("CombatScene: _on_combat_started called with %d players, %d enemies" % [player_combatants.size(), enemy_combatants.size()])
	_log_message("=== COMBAT START ===", true)
	
	# Clear previous data
	combatant_sprites.clear()
	combatant_info_panels.clear()
	combatant_clickable_areas.clear()
	ability_buttons.clear()
	
	# Generate player combatants (sprites in combat area + info panels below)
	for combatant in player_combatants:
		print("CombatScene: Creating display for player: %s" % _safe_combatant_name(combatant))
		_create_player_combatant_display(combatant)
	
	# Generate enemy combatants (sprites in combat area only)
	for combatant in enemy_combatants:
		print("CombatScene: Creating display for enemy: %s" % _safe_combatant_name(combatant))
		_create_enemy_combatant_display(combatant)
	
	# Update turn order display
	print("CombatScene: Updating turn order display")
	_update_turn_order_display()
	print("CombatScene: Combat start complete")

## Called when combat ends (emitted from death handler; defer so damage/death logs appear first)
func _on_combat_ended(victory: bool, rewards: Dictionary):
	call_deferred("_deferred_combat_end", victory, rewards)

## Runs after current frame so combat log shows damage and "X has fallen!" before VICTORY/DEFEAT/FLED
func _deferred_combat_end(victory: bool, rewards: Dictionary):
	var fled: bool = rewards.get("fled", false)
	if victory:
		_log_message("=== VICTORY ===", true)
	elif fled:
		_log_message("=== FLED ===", true)
	else:
		_log_message("=== DEFEAT ===", true)

	await get_tree().create_timer(combat_end_delay).timeout

	var root = get_tree().root
	var main = null
	for child in root.get_children():
		if child.name == "Main":
			main = child
			break

	var show_rewards_panel: bool = (victory or fled) and main and rewards.get("xp", 0) >= 0 and rewards.get("gold", 0) >= 0
	if show_rewards_panel:
		var rewards_panel = combat_rewards_scene.instantiate()
		add_child(rewards_panel)
		rewards_panel.show_rewards(rewards, main.current_party_members, victory, main)
		await rewards_panel.continue_pressed
		rewards_panel.queue_free()

	# Hand off to Main for post-combat flow (outcome events, game-over, map restore).
	if main:
		main.on_combat_scene_fully_ended(victory, rewards)

	queue_free()

## Called when a turn starts
func _on_turn_started(combatant: CombatantData, turn_number: int, status_results: Dictionary):
	if not combatant or not is_instance_valid(combatant):
		return
	# Flush any deaths from previous turn (e.g. DoT kill) before showing "X's Turn"
	_flush_pending_death_logs()
	
	# Show turn announcer (animate in/out)
	await _show_turn_announcer(combatant)
	
	_log_message("--- %s's Turn ---" % _safe_combatant_name(combatant), true)
	
	current_turn_label.text = "%s's Turn" % _safe_combatant_name(combatant)
	
	# Log any status effects that triggered (DoTs, HoTs, etc.)
	for effect in status_results.get("effects_triggered", []):
		match effect.type:
			"damage":
				_log_message("  %s takes %d damage from %s" % [_safe_combatant_name(combatant), effect.amount, effect.status])
			"heal":
				_log_message("  %s heals %d from %s" % [_safe_combatant_name(combatant), effect.amount, effect.status])
	
	# Update turn order display
	_update_turn_order_display()
	
	# Update info panel for current combatant (AP refreshed, health may have changed from DoTs)
	_update_combatant_info_panel(combatant)
	
	# Update all combatant sprites (casting displays may have changed)
	_update_all_casting_displays()
	
	# Check if combatant is stunned/incapacitated
	if not status_results.get("can_act", true):
		_log_message("  %s is stunned and cannot act!" % _safe_combatant_name(combatant))
		
		# Show which control effects wore off
		for status_name in status_results.get("control_statuses_consumed", []):
			_log_message("  %s's %s wore off!" % [_safe_combatant_name(combatant), status_name])
		
		current_player_combatant = null
		_clear_ability_panel()
		return
	
	# Log non-control statuses that wore off (buffs, debuffs, DoTs, HoTs)
	for status_name in status_results.get("statuses_expired", []):
		_log_message("  %s's %s wore off!" % [_safe_combatant_name(combatant), status_name])
	
	# If player turn, show abilities
	if combatant.is_player:
		current_player_combatant = combatant
		_show_abilities_for_combatant(combatant)
		_update_ability_button_states()
	else:
		current_player_combatant = null
		_clear_ability_panel()

## Called when a delayed/channeled cast starts
func _on_cast_started(cast):
	var cast_time = cast.ability.get_modified_cast_time()
	var caster_name = _safe_combatant_name(cast.caster)
	# Show different messages for delayed vs channeled
	if cast.ability.ability_type == Ability.AbilityType.DELAYED_CAST:
		_log_message("%s begins casting %s - %d turn%s" % [
			caster_name,
			cast.ability.ability_name,
			cast_time,
			"s" if cast_time != 1 else ""
		])
	elif cast.ability.ability_type == Ability.AbilityType.CHANNELED:
		_log_message("%s begins channeling %s - %d turn%s" % [
			caster_name,
			cast.ability.ability_name,
			cast_time,
			"s" if cast_time != 1 else ""
		])
	
	# Update casting display on the caster's sprite
	if combatant_sprites.has(cast.caster):
		var sprite = combatant_sprites[cast.caster]
		sprite.update_casting_display()

## Called when a channeled ability ticks (subsequent turns, not the first)
func _on_channeled_tick(cast):
	# Update casting display
	if combatant_sprites.has(cast.caster):
		var sprite = combatant_sprites[cast.caster]
		sprite.update_casting_display()

## Called when an ability resolves
func _on_ability_resolved(caster: CombatantData, ability: Ability, targets: Array, effects_applied: Array):
	# Null check
	if not caster or not ability:
		_flush_pending_death_logs()
		return
	
	# Filter different effect types
	var damage_effects = effects_applied.filter(func(e): return e.type == "damage")
	var heal_effects = effects_applied.filter(func(e): return e.type == "heal")
	var status_effects = effects_applied.filter(func(e): return e.type == "status")
	var interrupt_effects = effects_applied.filter(func(e): return e.type == "interrupt")
	
	# Check ability type
	var is_delayed_cast = (ability.ability_type == Ability.AbilityType.DELAYED_CAST)
	var is_channeled = (ability.ability_type == Ability.AbilityType.CHANNELED)
	
	# For channeled abilities that just completed with no effects, just log completion
	if is_channeled and effects_applied.is_empty():
		_log_message("  %s's %s completes!" % [_safe_combatant_name(caster), ability.ability_name])
		_flush_pending_death_logs()
		return
	
	# Single-target damage - combine into one message
	if damage_effects.size() == 1 and heal_effects.is_empty() and status_effects.is_empty():
		var effect = damage_effects[0]
		if not effect.get("target"):
			_flush_pending_death_logs()
			return  # Target is null/invalid, skip
		var tname = _safe_combatant_name(effect.get("target"))
		if is_delayed_cast:
			_log_message("%s's %s finishes casting and hits %s for %d damage!" % [
				_safe_combatant_name(caster),
				ability.ability_name,
				tname,
				int(effect.amount)
			])
		else:
			_log_message("%s attacked %s with %s and dealt %d damage" % [
				_safe_combatant_name(caster),
				tname,
				ability.ability_name,
				int(effect.amount)
			])
	# Single-target heal - combine into one message
	elif heal_effects.size() == 1 and damage_effects.is_empty() and status_effects.is_empty():
		var effect = heal_effects[0]
		if not effect.get("target"):
			_flush_pending_death_logs()
			return
		_log_message("%s healed %s with %s for %d health" % [
			_safe_combatant_name(caster),
			_safe_combatant_name(effect.get("target")),
			ability.ability_name,
			int(effect.amount)
		])
	# Multi-target or mixed effects - show ability first, then individual effects
	else:
		# Show appropriate message based on ability type
		if is_delayed_cast:
			_log_message("%s's %s finishes casting!" % [_safe_combatant_name(caster), ability.ability_name])
		elif is_channeled:
			# For channeled ticks, show "channels" instead of "used"
			var has_active_cast = CombatController.combat_timeline and CombatController.combat_timeline.has_active_cast(caster)
			if has_active_cast:
				# Still channeling - this is a tick
				var active_cast = CombatController.combat_timeline.get_active_cast(caster)
				_log_message("  %s channels %s - %d turn%s remaining" % [
					_safe_combatant_name(caster),
					ability.ability_name,
					active_cast.remaining_cast_time if active_cast else 0,
					"s" if (active_cast.remaining_cast_time if active_cast else 0) != 1 else ""
				])
			else:
				# Just completed
				_log_message("  %s's %s completes!" % [_safe_combatant_name(caster), ability.ability_name])
		else:
			_log_message("%s used %s" % [_safe_combatant_name(caster), ability.ability_name])
		
		# Show damage to each target
		for effect in damage_effects:
			if effect.has("target"):
				_log_message("  → %s takes %d damage" % [_safe_combatant_name(effect.get("target")), int(effect.amount)])
		
		# Show healing to each target
		for effect in heal_effects:
			if effect.has("target"):
				_log_message("  → %s heals %d" % [_safe_combatant_name(effect.get("target")), int(effect.amount)])
		
		# Show status effects applied
		for effect in status_effects:
			if effect.has("target") and effect.has("status") and effect.status:
				_log_message("  → %s is afflicted with %s" % [_safe_combatant_name(effect.get("target")), effect.status.status_name])
		
		# Show interrupts
		for effect in interrupt_effects:
			if effect.has("target"):
				_log_message("  → %s's cast was interrupted!" % _safe_combatant_name(effect.get("target")))
	
	# Update caster's AP display (spent AP on ability)
	_update_combatant_info_panel(caster)
	
	# Update casting displays (casts may have completed)
	_update_all_casting_displays()
	
	# Log any deaths from this ability now (after damage lines, before turn advances)
	_flush_pending_death_logs()

## Called when a combatant takes damage
func _on_combatant_damaged(combatant: CombatantData, amount: float, source: CombatantData):
	# Don't log here - it's handled in ability_resolved
	_update_combatant_health_display(combatant)
	if combatant_sprites.has(combatant) and amount > 0:
		combatant_sprites[combatant].spawn_combat_text(str(int(amount)), Color.RED)

## Called when a combatant is healed
func _on_combatant_healed(combatant: CombatantData, amount: float, source: CombatantData):
	# Don't log here - it's handled in ability_resolved
	_update_combatant_health_display(combatant)
	if combatant_sprites.has(combatant) and amount > 0:
		combatant_sprites[combatant].spawn_combat_text(str(int(amount)), Color.GREEN)

## Called when a status effect is applied (e.g. stun) - spawn pale gold status text
func _on_status_applied(combatant: CombatantData, status: StatusEffect):
	if not combatant or not status or not combatant_sprites.has(combatant):
		return
	var text := status.status_name if status.status_name else "Status"
	if status.status_type == StatusEffect.StatusType.STUN:
		text = "Stunned!"
	var pale_gold := Color(0.95, 0.88, 0.55)
	combatant_sprites[combatant].spawn_combat_text(text, pale_gold)

## Hover over a combat sprite: highlight that character's turn order entries
func _on_combat_sprite_hover_entered(combatant: CombatantData):
	if turn_order_panel and turn_order_panel.has_method("highlight_entries_for_combatant") and combatant:
		turn_order_panel.highlight_entries_for_combatant(combatant)

## Hover left combat sprite: clear turn order entry highlights
func _on_combat_sprite_hover_exited():
	if turn_order_panel and turn_order_panel.has_method("unhighlight_all_entries"):
		turn_order_panel.unhighlight_all_entries()

## Turn order panel emitted: highlight this combatant's sprite (hover highlight, not selection)
func _on_turn_order_combatant_highlighted(combatant: CombatantData):
	if combatant and combatant_sprites.has(combatant):
		var sprite = combatant_sprites[combatant]
		if sprite and sprite.has_method("set_hover_highlight"):
			sprite.set_hover_highlight(true)

## Turn order panel emitted: clear all sprite hover highlights
func _on_turn_order_combatant_unhighlighted():
	for c in combatant_sprites:
		var sprite = combatant_sprites[c]
		if sprite and sprite.has_method("set_hover_highlight"):
			sprite.set_hover_highlight(false)

## Called when a combatant dies
func _on_combatant_died(combatant: CombatantData):
	# Queue the death log; we flush it after the ability log so order is: damage → fallen → next turn
	_pending_death_logs.append(combatant)
	
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
	
	# Setup sprite with combatant data
	sprite_instance.setup(combatant)
	
	# TODO: Set sprite texture based on class/character
	# sprite_instance.character_sprite.texture = load("res://assets/characters/%s.png" % combatant.display_name)
	
	# Create clickable button overlay for targeting (invisible, just for clicks)
	var click_button = Button.new()
	click_button.flat = true
	click_button.custom_minimum_size = sprite_instance.size
	click_button.pressed.connect(_on_combatant_clicked.bind(combatant))
	click_button.mouse_entered.connect(_on_combat_sprite_hover_entered.bind(combatant))
	click_button.mouse_exited.connect(_on_combat_sprite_hover_exited)
	sprite_instance.add_child(click_button)
	combatant_clickable_areas[combatant] = click_button
	
	# Create info panel below in party panel
	var info_panel = character_info_panel_scene.instantiate()
	party_info_panel.add_child(info_panel)
	combatant_info_panels[combatant] = info_panel
	info_panel.mouse_entered.connect(_on_combat_sprite_hover_entered.bind(combatant))
	info_panel.mouse_exited.connect(_on_combat_sprite_hover_exited)
	
	# Initialize info panel
	_update_combatant_info_panel(combatant)

## Create enemy combatant display (sprite only, no info panel)
func _create_enemy_combatant_display(combatant: CombatantData):
	# Create sprite in combat area
	var sprite_instance = combat_character_sprite_scene.instantiate()
	combat_area_enemy_panel.add_child(sprite_instance)
	combatant_sprites[combatant] = sprite_instance
	
	# Setup sprite with combatant data
	sprite_instance.setup(combatant)
	
	# TODO: Set sprite texture based on enemy type
	# sprite_instance.character_sprite.texture = load("res://assets/enemies/%s.png" % combatant.display_name)
	
	# Create clickable button overlay for targeting
	var click_button = Button.new()
	click_button.flat = true
	click_button.custom_minimum_size = sprite_instance.size
	click_button.pressed.connect(_on_combatant_clicked.bind(combatant))
	click_button.mouse_entered.connect(_on_combat_sprite_hover_entered.bind(combatant))
	click_button.mouse_exited.connect(_on_combat_sprite_hover_exited)
	sprite_instance.add_child(click_button)
	combatant_clickable_areas[combatant] = click_button
	
	# Enemies don't get info panels (their health is shown on the sprite)

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
	
	# Add "Pass Turn" and "Flee" using same button scene as abilities
	var pass_turn_button = combat_ability_option_scene.instantiate()
	pass_turn_button.setup_simple("Pass Turn")
	pass_turn_button.pressed.connect(_on_pass_turn_pressed)
	ability_panel_container.add_child(pass_turn_button)
	
	var flee_button = combat_ability_option_scene.instantiate()
	flee_button.setup_simple("Flee")
	flee_button.pressed.connect(_on_flee_pressed)
	ability_panel_container.add_child(flee_button)

## Clear ability panel
func _clear_ability_panel():
	# Clear all children (abilities, spacers, action buttons)
	for child in ability_panel_container.get_children():
		child.queue_free()
	ability_buttons.clear()
	selected_ability = null
	_exit_targeting()

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

## Update turn order display (delegates to TurnOrderPanel)
func _update_turn_order_display():
	if turn_order_panel and turn_order_panel.has_method("refresh_turn_order"):
		turn_order_panel.refresh_turn_order()

## Update combatant info panel with current stats
func _update_combatant_info_panel(combatant: CombatantData):
	if not combatant or not is_instance_valid(combatant) or not combatant_info_panels.has(combatant):
		return
	var info_panel = combatant_info_panels[combatant]
	var stats = combatant.combatant_stats
	if not stats:
		return
	info_panel.update_display(
		_safe_combatant_name(combatant),
		stats.current_health,
		stats.max_health,
		stats.current_ap,
		stats.max_ap
	)

## Update combatant health display
func _update_combatant_health_display(combatant: CombatantData):
	if not combatant or not is_instance_valid(combatant):
		return
	# Update info panel if they have one (players)
	_update_combatant_info_panel(combatant)
	
	# Update sprite health bar (all combatants)
	if combatant_sprites.has(combatant):
		var sprite = combatant_sprites[combatant]
		sprite.update_health_display()

## Update all casting displays (after turns change or casts start/complete)
func _update_all_casting_displays():
	for combatant in combatant_sprites:
		var sprite = combatant_sprites[combatant]
		sprite.update_casting_display()

## Called when ability button pressed - enter targeting; never auto-fire
func _on_ability_button_pressed(ability: Ability):
	selected_ability = ability
	_log_message("Selected: %s — choose a target" % ability.ability_name)
	
	# SELF: no targeting UI, execute immediately
	if ability.targeting_type == Ability.TargetingType.SELF:
		CombatController.player_cast_ability(ability, [current_player_combatant])
		selected_ability = null
		return
	
	var targets = CombatController.get_valid_targets(current_player_combatant, ability)
	if targets.is_empty():
		_log_message("  No valid targets!")
		selected_ability = null
		return
	
	# Enter targeting mode: require explicit selection
	_enter_targeting(ability, targets)

## Called when combatant clicked (for targeting)
func _on_combatant_clicked(combatant: CombatantData):
	if not is_targeting or not pending_ability or not current_player_combatant:
		return
	if combatant not in valid_targets:
		return
	
	# Build selected targets: single = [combatant], AOE = full valid list (one click = confirm team)
	var selected: Array = []
	match pending_ability.targeting_type:
		Ability.TargetingType.SINGLE_ALLY, Ability.TargetingType.SINGLE_ENEMY:
			selected = [combatant]
		Ability.TargetingType.ALL_ALLIES, Ability.TargetingType.ALL_ENEMIES, Ability.TargetingType.ALL_COMBATANTS:
			selected = valid_targets.duplicate()
		_:
			selected = [combatant]
	
	# Show selected visual on clicked combatant (and for AOE, on all valid targets)
	if combatant_sprites.has(combatant):
		combatant_sprites[combatant].set_selected(true)
	for t in selected:
		if t != combatant and combatant_sprites.has(t):
			combatant_sprites[t].set_selected(true)
	
	CombatController.player_cast_ability(pending_ability, selected)
	_exit_targeting()
	selected_ability = null

## Called when Pass Turn button pressed
func _on_pass_turn_pressed():
	if current_player_combatant:
		_log_message("%s passes their turn" % _safe_combatant_name(current_player_combatant))
		CombatController.player_end_turn()

## Called when Flee button pressed
func _on_flee_pressed():
	if current_player_combatant:
		_log_message("%s attempts to flee..." % _safe_combatant_name(current_player_combatant))
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

## Enter targeting mode: show valid targets, enable only their buttons
func _enter_targeting(ability: Ability, targets: Array):
	is_targeting = true
	pending_ability = ability
	valid_targets = targets
	for c in combatant_sprites:
		var sprite_node: CombatCharacterSprite = combatant_sprites[c]
		var valid: bool = c in valid_targets
		if sprite_node:
			sprite_node.set_valid_target(valid)
			sprite_node.set_selected(false)
	for c in combatant_clickable_areas:
		var btn: Button = combatant_clickable_areas[c]
		if btn:
			btn.disabled = (c not in valid_targets)

## Exit targeting mode: clear visuals and re-enable all living combatant buttons
func _exit_targeting():
	if not is_targeting:
		return
	is_targeting = false
	pending_ability = null
	valid_targets.clear()
	for c in combatant_sprites:
		var sprite_node: CombatCharacterSprite = combatant_sprites[c]
		if sprite_node:
			sprite_node.clear_targeting_state()
	for c in combatant_clickable_areas:
		var btn: Button = combatant_clickable_areas[c]
		if btn:
			# Re-enable only if combatant is still targetable (e.g. not dead)
			btn.disabled = false

func _unhandled_input(event: InputEvent):
	if is_targeting and event.is_action_pressed("ui_cancel"):
		_exit_targeting()
		_log_message("Targeting cancelled.")
		selected_ability = null
		get_viewport().set_input_as_handled()

## Log a message to combat log. Set centered=true for section headers (combat start, turns, victory/defeat).
func _log_message(message: String, centered: bool = false):
	print("[Combat] " + message)
	if centered:
		combat_log.text += "[center]" + message + "[/center]\n"
	else:
		combat_log.text += message + "\n"
