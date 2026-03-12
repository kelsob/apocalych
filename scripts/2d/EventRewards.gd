extends MarginContainer
class_name EventRewards

## EventRewards - Displays XP and gold earned after combat in the EventLog.
## Scene expects:
##   $XPLabel   (Label) - shows earned XP, hidden when xp == 0
##   $GoldLabel (Label) - shows earned gold, hidden when gold == 0

@onready var xp_label: Label = $HBoxContainer/XPLabel
@onready var gold_label: Label = $HBoxContainer/GoldLabel

var _pending_xp: int = 0
var _pending_gold: int = 0

func _ready():
	_apply_values()

## Set the rewards to display. Safe to call before or after the node is in the scene tree.
func set_rewards(rewards: Dictionary):
	_pending_xp = rewards.get("xp", 0)
	_pending_gold = rewards.get("gold", 0)
	if is_inside_tree():
		_apply_values()

func _apply_values():
	if xp_label:
		xp_label.text = "+%d XP" % _pending_xp
		xp_label.visible = _pending_xp > 0
	if gold_label:
		gold_label.text = "+%d Gold" % _pending_gold
		gold_label.visible = _pending_gold > 0
