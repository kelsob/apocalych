extends Control
class_name ItemReward

## ItemReward - Inline event-log widget that lets the player choose which party member
## receives a non-bulk item reward.

signal member_chosen(member: PartyMember)

@onready var item_label: Label = $HBoxContainer/HBoxContainer/ItemNameLabel
@onready var item_icon: TextureRect = $HBoxContainer/HBoxContainer/ItemIcon
@onready var char_button_1: Button = $HBoxContainer/HBoxContainer2/Button
@onready var char_button_2: Button = $HBoxContainer/HBoxContainer2/Button2
@onready var char_button_3: Button = $HBoxContainer/HBoxContainer2/Button3

var _members: Array = []
var _resolved: bool = false

func setup(item: Item, count: int, members: Array) -> void:
	_members = members

	if count > 1:
		item_label.text = "%s  ×%d" % [item.name, count]
	else:
		item_label.text = item.name

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

func _on_member_button_pressed(member: PartyMember) -> void:
	if _resolved:
		return
	_resolved = true

	for btn in [char_button_1, char_button_2, char_button_3]:
		btn.disabled = true

	item_label.text = item_label.text + "  →  " + member.member_name

	member_chosen.emit(member)
