extends GridContainer

## CharacterInventoryContainer - Displays a party member's inventory in a grid of ItemSlotDisplay slots.
## Used by CharacterDetailsScreen and VendorScreen.
## Attach this script to the root of CharacterInventoryContainer.tscn.

signal clicked()
signal item_hovered(item_id: String)
signal item_unhovered()
signal slot_drag_started(item_id: String, member_index: int, icon: Texture2D)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for c in get_children():
		if c.has_signal("slot_hovered"):
			c.slot_hovered.connect(_on_slot_hovered)
		if c.has_signal("slot_unhovered"):
			c.slot_unhovered.connect(_on_slot_unhovered)
		if c.has_signal("custom_drag_started"):
			c.custom_drag_started.connect(_on_slot_custom_drag_started)

func _on_slot_hovered(item_id: String) -> void:
	item_hovered.emit(item_id)

func _on_slot_unhovered() -> void:
	item_unhovered.emit()

func _on_slot_custom_drag_started(item_id: String, member_index: int, icon: Texture2D) -> void:
	slot_drag_started.emit(item_id, member_index, icon)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			clicked.emit()
			accept_event()

## Highlight when awaiting recipient selection (e.g. vendor buy flow).
func set_awaiting_recipient(awaiting: bool) -> void:
	modulate = Color(1.2, 1.2, 0.9) if awaiting else Color.WHITE

## Populate slots from a PartyMember's inventory. Call when member changes.
## member_index: when >= 0 (vendor context), slots become draggable with {item_id, member_index}.
func populate_from_member(member: PartyMember, member_index: int = -1) -> void:
	if not member:
		_clear_all_slots()
		_clear_all_slot_drag_data()
		return
	var ids: Array[String] = member.get_inventory_ids()
	var slots: Array[Node] = []
	for c in get_children():
		slots.append(c)
	for i in range(slots.size()):
		var slot: Node = slots[i]
		var item_texture: TextureRect = slot.get_node_or_null("ItemTextureRect") as TextureRect
		if slot.has_method("set"):
			slot.set("drag_data", null)
		if i < ids.size():
			var item_id: String = ids[i]
			var item: Item = ItemDatabase.get_item(item_id) if ItemDatabase else null
			if item_texture and item and not item.icon_path.is_empty():
				var tex: Texture2D = load(item.icon_path) as Texture2D
				item_texture.texture = tex
			elif item_texture:
				item_texture.texture = null
			if member_index >= 0 and slot.has_method("set"):
				slot.set("drag_data", {"item_id": item_id, "member_index": member_index})
		elif item_texture:
			item_texture.texture = null

## Clear all slots (e.g. when no member selected).
func _clear_all_slots() -> void:
	for c in get_children():
		var item_texture: TextureRect = c.get_node_or_null("ItemTextureRect") as TextureRect
		if item_texture:
			item_texture.texture = null

func _clear_all_slot_drag_data() -> void:
	for c in get_children():
		if c.has_method("set"):
			c.set("drag_data", null)
