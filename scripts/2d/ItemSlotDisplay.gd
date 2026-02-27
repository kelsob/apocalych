extends TextureRect

## ItemSlotDisplay - a single inventory slot. When drag_data is set (vendor context), custom drag-to-sell.

signal slot_hovered(item_id: String)
signal slot_unhovered()
signal custom_drag_started(item_id: String, member_index: int, icon: Texture2D)

var drag_data: Variant = null  ## Set by parent when slot has draggable item. Dict: {item_id, member_index}.

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	var child := get_node_or_null("ItemTextureRect") as Control
	if child:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_mouse_entered() -> void:
	if drag_data is Dictionary and not str(drag_data.get("item_id", "")).is_empty():
		slot_hovered.emit(str(drag_data.get("item_id", "")))
	else:
		slot_hovered.emit("")

func _on_mouse_exited() -> void:
	slot_unhovered.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			if drag_data is Dictionary and not str(drag_data.get("item_id", "")).is_empty():
				var item := ItemDatabase.get_item(str(drag_data.get("item_id", "")))
				if item and item.sellable:
					var icon_node := get_node_or_null("ItemTextureRect") as TextureRect
					var icon_tex: Texture2D = icon_node.texture if icon_node else texture
					custom_drag_started.emit(str(drag_data.get("item_id", "")), int(drag_data.get("member_index", -1)), icon_tex)
					accept_event()
