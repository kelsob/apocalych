extends Control
class_name OptionsMenu

## Full-screen overlay under **UIController** (sibling of MainMenu). **Visible = false** by default.
## Expected hierarchy (adjust node names in this script if yours differ):
## ```
## OptionsMenu (anchors full rect, mouse_filter STOP)
## ├── ColorRect                    # dim background (optional)
## └── CenterContainer
##     └── VBoxContainer
##         ├── TitleLabel           # optional
##         ├── ResetMetaButton      # clears MetaProgression
##         └── BackButton           # closes overlay
## ```
## Place **OptionsMenu** **after** MainMenu in the UIController scene tree so it draws on top, or raise z_index.

signal closed


func _ready() -> void:
	visible = false
	var back: Button = get_node_or_null("CenterContainer/VBoxContainer/BackButton") as Button
	if back:
		back.pressed.connect(_on_back_pressed)
	else:
		push_warning("OptionsMenu: missing CenterContainer/VBoxContainer/BackButton — close will not work until paths match.")
	var reset_btn: Button = get_node_or_null("CenterContainer/VBoxContainer/ResetMetaButton") as Button
	if reset_btn:
		reset_btn.pressed.connect(_on_reset_meta_pressed)


func open_options() -> void:
	visible = true


func close_options() -> void:
	visible = false
	closed.emit()


func _on_back_pressed() -> void:
	close_options()


func _on_reset_meta_pressed() -> void:
	MetaProgression.reset_all_meta()
