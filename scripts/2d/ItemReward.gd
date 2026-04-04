extends Control
class_name ItemReward

## ItemReward - Inline event-log widget that lets the player choose which party member
## receives a non-bulk item reward.
##
## Expected scene structure (ItemReward.tscn):
##   ItemReward (Control, root — attach this script)
##   └── HBoxContainer
##       ├── HBoxContainer
##       │   ├── ItemIcon    (TextureRect)
##       │   └── RewardLabel (RichTextLabel — bbcode_enabled ON, fit_content ON)
##       └── HBoxContainer2
##           ├── Button
##           ├── Button2
##           └── Button3

signal member_chosen(member: HeroCharacter)

@onready var reward_label: RichTextLabel = $HBoxContainer/HBoxContainer/RewardLabel
@onready var item_icon: TextureRect = $HBoxContainer/HBoxContainer/ItemIcon
@onready var char_button_1: Button = $HBoxContainer/HBoxContainer2/Button
@onready var char_button_2: Button = $HBoxContainer/HBoxContainer2/Button2
@onready var char_button_3: Button = $HBoxContainer/HBoxContainer2/Button3

var _item: Item = null
var _item_bbcode: String = ""
var _resolved: bool = false

func setup(item: Item, count: int, members: Array) -> void:
	_item = item

	var item_name: String = "%s ×%d" % [item.name, count] if count > 1 else item.name
	var rarity_hex: String = ProjectColors.RARITY_COLORS[item.rarity].to_html(false)
	_item_bbcode = "[color=#%s]%s[/color]" % [rarity_hex, item_name]

	reward_label.text = _item_bbcode

	_set_icon(item.icon_path)

	var buttons := [char_button_1, char_button_2, char_button_3]
	for i in buttons.size():
		var btn: Button = buttons[i]
		if i < members.size():
			btn.text = members[i].member_name
			btn.visible = true
			btn.pressed.connect(_on_member_button_pressed.bind(members[i]))
		else:
			btn.visible = false

func _set_icon(icon_path: String) -> void:
	if icon_path.is_empty():
		item_icon.texture = null
		item_icon.visible = false
		return
	var tex := load(icon_path) as Texture2D
	if tex:
		item_icon.texture = tex
		item_icon.visible = true
	else:
		item_icon.texture = null
		item_icon.visible = false

func _on_member_button_pressed(member: HeroCharacter) -> void:
	if _resolved:
		return
	_resolved = true

	reward_label.text = "%s acquired %s!" % [member.member_name, _item_bbcode]

	for btn in [char_button_1, char_button_2, char_button_3]:
		btn.queue_free()

	member_chosen.emit(member)
