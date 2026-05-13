extends Control
class_name CombatCharacterSprite

## CombatCharacterSprite - Character sprite, status effect icons, combat text, and targeting indicators

var combat_text_scene: PackedScene = preload("res://scenes/combat/CombatText.tscn")
var status_effect_icon_scene: PackedScene = preload("res://scenes/combat/StatusEffectCombatIcon.tscn")
const PLACEHOLDER_TEXTURE: Texture2D = preload("res://assets/party-characters/placeholder.png")

@onready var character_sprite: TextureRect = $VBoxContainer/CharacterSprite
@onready var status_effects_container : HBoxContainer = $VBoxContainer/StatusEffectsContainer
@onready var selection_circle: TextureRect = $VBoxContainer/CharacterSprite/SelectionCircle



# Hover highlight when turn order entry (or this sprite) is hovered - distinct from selection
var _hover_highlight: ColorRect = null

# Combatant reference (set by CombatScene)
var combatant: CombatantData = null

# How many combat texts are currently active (for vertical stacking)
var _combat_text_active_count: int = 0

func _ready():
	if selection_circle:
		selection_circle.visible = false
	
	# Hover highlight when this character is highlighted via turn order / sprite hover (not selection)
	_hover_highlight = ColorRect.new()
	_hover_highlight.color = Color(0.4, 0.7, 1.0, 0.2)
	_hover_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_highlight.visible = false
	add_child(_hover_highlight)
	
	call_deferred("_resize_hover_overlay")

func _resize_hover_overlay():
	var sz = size
	if _hover_highlight:
		_hover_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
		_hover_highlight.set_offsets_preset(Control.PRESET_FULL_RECT)
		_hover_highlight.size = sz

func _notification(what: int):
	if what == NOTIFICATION_RESIZED:
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
	if combatant and combatant.combatant_stats:
		combatant.combatant_stats.status_applied.connect(_refresh_status_effects_display)
		combatant.combatant_stats.status_removed.connect(_refresh_status_effects_display)
	_refresh_status_effects_display()

## Set sprite modulation (for death, highlighting, etc.)
func set_sprite_modulation(color: Color):
	if character_sprite:
		character_sprite.modulate = color

## Show or hide "selected as target" highlight
func set_selected(selected: bool):
	if selection_circle:
		selection_circle.visible = selected

## Targeting validity no longer has a separate visual.
func set_valid_target(_valid: bool):
	pass

## Show or hide hover highlight (when turn order entry or this sprite is hovered)
func set_hover_highlight(visible: bool):
	if _hover_highlight:
		_hover_highlight.visible = visible

## Clear targeting visuals
func clear_targeting_state():
	set_selected(false)

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
