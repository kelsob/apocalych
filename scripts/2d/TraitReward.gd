extends MarginContainer
class_name TraitReward

## Read-only trait summary for the event log (icon + description only). No buttons or signals.
##
## Expected scene (TraitReward.tscn) — attach this script to the root MarginContainer:
##   TraitReward (MarginContainer)
##   └── HBoxContainer
##       ├── TraitIcon     (TextureRect)
##       └── TraitRichText (RichTextLabel — bbcode_enabled ON, fit_content ON, scroll_active OFF)

@onready var trait_icon: TextureRect = $HBoxContainer/TraitIcon
@onready var trait_richtext: RichTextLabel = $HBoxContainer/TraitRichText

func _ready() -> void:
	visible = false
	_fix_root_layout_for_vbox_parent()
	if trait_richtext:
		trait_richtext.bbcode_enabled = true
		trait_richtext.fit_content = true
		trait_richtext.scroll_active = false

## Scene presets with center anchors break minimum height inside EventLog's VBox — reset for normal layout.
func _fix_root_layout_for_vbox_parent() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN

## Fill labels from a Trait resource (from TraitDatabase).
func setup(t: Trait) -> void:
	if t == null:
		return
	_set_icon(t.icon_path)
	trait_richtext.text = t.description

func setup_from_id(trait_id: String) -> void:
	if trait_id.is_empty() or not TraitDatabase.has_trait(trait_id):
		push_warning("TraitReward.setup_from_id: unknown trait_id '%s'" % trait_id)
		return
	setup(TraitDatabase.get_trait(trait_id))

func _set_icon(icon_path: String) -> void:
	if icon_path.is_empty():
		trait_icon.texture = null
		trait_icon.visible = false
		return
	var tex := load(icon_path) as Texture2D
	if tex:
		trait_icon.texture = tex
		trait_icon.visible = true
	else:
		trait_icon.texture = null
		trait_icon.visible = false
