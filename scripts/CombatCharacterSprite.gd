extends Control
class_name CombatCharacterSprite

## CombatCharacterSprite - Displays a combatant in combat with health, casting status, and targeting visuals

var combat_text_scene: PackedScene = preload("res://scenes/combat/CombatText.tscn")
var status_effect_icon_scene: PackedScene = preload("res://scenes/combat/StatusEffectCombatIcon.tscn")
const PLACEHOLDER_TEXTURE: Texture2D = preload("res://assets/party-characters/placeholder.png")

@onready var character_sprite: TextureRect = $MarginContainer/VBoxContainer/CharacterSprite
@onready var hp_progress_bar: ProgressBar = $MarginContainer/VBoxContainer/HPProgressBar
@onready var casting_label: Label = $MarginContainer/VBoxContainer/CastingLabel
@onready var status_effects_container : HBoxContainer = $MarginContainer/VBoxContainer/StatusEffectsContainer

# Targeting visuals (created in _ready so we don't require scene edits)
var _selection_highlight: ColorRect = null
var _valid_outline: ColorRect = null
# Hover highlight when turn order entry (or this sprite) is hovered - distinct from selection
var _hover_highlight: ColorRect = null

# Combatant reference (set by CombatScene)
var combatant: CombatantData = null

# How many combat texts are currently active (for vertical stacking)
var _combat_text_active_count: int = 0

func _ready():
	# Hide casting label by default
	if casting_label:
		casting_label.visible = false
		casting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Initialize HP bar
	if hp_progress_bar:
		hp_progress_bar.show_percentage = false
	
	# Selection indicator: full rect overlay when this combatant is selected as target
	_selection_highlight = ColorRect.new()
	_selection_highlight.color = Color(1.0, 0.9, 0.2, 0.35)
	_selection_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_highlight.visible = false
	add_child(_selection_highlight)
	
	# Valid target outline: subtle border when in targeting mode and this is a valid target
	_valid_outline = ColorRect.new()
	_valid_outline.color = Color(0.3, 0.9, 0.3, 0.25)
	_valid_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_valid_outline.visible = false
	add_child(_valid_outline)
	
	# Hover highlight when this character is highlighted via turn order / sprite hover (not selection)
	_hover_highlight = ColorRect.new()
	_hover_highlight.color = Color(0.4, 0.7, 1.0, 0.2)
	_hover_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_highlight.visible = false
	add_child(_hover_highlight)
	
	call_deferred("_resize_overlays")

func _resize_overlays():
	var sz = size
	_selection_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	_selection_highlight.set_offsets_preset(Control.PRESET_FULL_RECT)
	_selection_highlight.size = sz
	_valid_outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	_valid_outline.set_offsets_preset(Control.PRESET_FULL_RECT)
	_valid_outline.size = sz
	if _hover_highlight:
		_hover_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
		_hover_highlight.set_offsets_preset(Control.PRESET_FULL_RECT)
		_hover_highlight.size = sz

func _notification(what: int):
	if what == NOTIFICATION_RESIZED:
		if _selection_highlight:
			_selection_highlight.size = size
		if _valid_outline:
			_valid_outline.size = size
		if _hover_highlight:
			_hover_highlight.size = size

## Initialize with combatant data
func setup(combatant_data: CombatantData):
	# Placeholder sprite for all combatants; enemies face right (flip_h)
	if character_sprite and PLACEHOLDER_TEXTURE:
		character_sprite.texture = PLACEHOLDER_TEXTURE
		character_sprite.flip_h = not combatant_data.is_player
	if combatant and combatant.combatant_stats:
		if combatant.combatant_stats.status_applied.is_connected(_refresh_status_effects_display):
			combatant.combatant_stats.status_applied.disconnect(_refresh_status_effects_display)
		if combatant.combatant_stats.status_removed.is_connected(_refresh_status_effects_display):
			combatant.combatant_stats.status_removed.disconnect(_refresh_status_effects_display)
	combatant = combatant_data
	update_health_display()
	update_casting_display()
	if combatant and combatant.combatant_stats:
		combatant.combatant_stats.status_applied.connect(_refresh_status_effects_display)
		combatant.combatant_stats.status_removed.connect(_refresh_status_effects_display)
	_refresh_status_effects_display()

## Update health bar display
func update_health_display():
	if not combatant or not hp_progress_bar:
		return
	
	var stats = combatant.combatant_stats
	hp_progress_bar.max_value = stats.max_health
	hp_progress_bar.value = stats.current_health
	
	# Color code health bar
	var health_percent = float(stats.current_health) / float(stats.max_health)
	if health_percent > 0.6:
		hp_progress_bar.modulate = Color.GREEN
	elif health_percent > 0.3:
		hp_progress_bar.modulate = Color.YELLOW
	else:
		hp_progress_bar.modulate = Color.RED

## Update casting display
func update_casting_display():
	if not combatant or not casting_label:
		return
	
	# Check if combatant has an active cast
	if CombatController.combat_timeline:
		var active_cast = CombatController.combat_timeline.get_active_cast(combatant)
		if active_cast:
			casting_label.visible = true
			var remaining = active_cast.remaining_cast_time
			casting_label.text = "Casting: %s - %d turn%s" % [
				active_cast.ability.ability_name,
				remaining,
				"s" if remaining != 1 else ""
			]
		else:
			casting_label.visible = false
	else:
		casting_label.visible = false

## Set sprite modulation (for death, highlighting, etc.)
func set_sprite_modulation(color: Color):
	if character_sprite:
		character_sprite.modulate = color

## Show or hide "selected as target" highlight
func set_selected(selected: bool):
	if _selection_highlight:
		_selection_highlight.visible = selected

## Show or hide "valid target" outline (during targeting mode)
func set_valid_target(valid: bool):
	if _valid_outline:
		_valid_outline.visible = valid

## Show or hide hover highlight (when turn order entry or this sprite is hovered)
func set_hover_highlight(visible: bool):
	if _hover_highlight:
		_hover_highlight.visible = visible

## Clear targeting visuals
func clear_targeting_state():
	set_selected(false)
	set_valid_target(false)

## Spawn floating combat text (damage/heal/status) over this sprite. Stacks vertically if multiple at once.
func spawn_combat_text(p_text: String, p_color: Color) -> void:
	var inst = combat_text_scene.instantiate()
	var slot := _combat_text_active_count
	_combat_text_active_count += 1
	if inst.has_signal("finished"):
		inst.finished.connect(_on_combat_text_finished)
	add_child(inst)
	if inst.has_method("setup"):
		inst.setup(p_text, p_color, slot)

func _on_combat_text_finished() -> void:
	_combat_text_active_count = max(0, _combat_text_active_count - 1)

func _refresh_status_effects_display(_status: Variant = null) -> void:
	if not status_effects_container or not combatant or not combatant.combatant_stats:
		return
	for child in status_effects_container.get_children():
		child.queue_free()
	for status in combatant.combatant_stats.active_statuses:
		var icon = status_effect_icon_scene.instantiate()
		status_effects_container.add_child(icon)
		if icon.has_method("set_stack_count"):
			icon.set_stack_count(status.stack_count)
