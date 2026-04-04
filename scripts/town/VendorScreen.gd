extends Control

signal vendor_closed()
signal party_gold_changed(new_gold: int)

const VENDOR_ITEM_BUTTON_SCENE := preload("res://scenes/2d/VendorItemButton.tscn")

var _party_members: Array[HeroCharacter] = []
var _party_gold: int = 0
## item_id -> quantity. Default 1 per item; decremented on purchase. Future: items_to_sell can pass {item_id, qty}.
var _vendor_stock: Dictionary = {}
## item_id -> sale_price. Set when vendor opens; two random items on sale (25% off). If both land on same item, 50% off (super sale).
var _sale_prices: Dictionary = {}
## When buying a non-resource item: await recipient selection. item_id and price stored until user clicks a character inventory.
var _pending_buy_item_id: String = ""
var _pending_buy_price: int = 0
## Custom drag (no Godot drag - we control cursor)
var _custom_drag_item_id: String = ""
var _custom_drag_member_index: int = -1
var _custom_drag_preview: TextureRect = null

@onready var _resource_inventory_container: VBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/ResourceInventoryContainer
@onready var character_name_label_1: Label = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer3/CharacterInventoriesVBox/CharacterNameLabel1
@onready var character_name_label_2: Label = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer3/CharacterInventoriesVBox/CharacterNameLabel2
@onready var character_name_label_3: Label = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer3/CharacterInventoriesVBox/CharacterNameLabel3
@onready var character_inventory_container_1: GridContainer = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer3/CharacterInventoriesVBox/CharacterInventoryContainer
@onready var character_inventory_container_2: GridContainer = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer3/CharacterInventoriesVBox/CharacterInventoryContainer2
@onready var character_inventory_container_3: GridContainer = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer3/CharacterInventoriesVBox/CharacterInventoryContainer3

@onready var _gold_label: Label = $MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/HBoxContainer/PartyGoldLabel
@onready var _close_button: Button = $MarginContainer/VBoxContainer/CloseButton
@onready var _buy_tab: VBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/TabContainer/Buy
## Drop zone for selling - drag items from character inventories here. Add as child of CharacterInventoriesVBox.
var _sell_box: Control = null

func _ready() -> void:
	visible = false
	_close_button.pressed.connect(_on_close_pressed)
	_sell_box = get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/MarginContainer3/CharacterInventoriesVBox/SellBox")
	if _sell_box:
		_connect_inventory_hover()
	if character_inventory_container_1:
		character_inventory_container_1.clicked.connect(_on_recipient_selected.bind(0))
	if character_inventory_container_2:
		character_inventory_container_2.clicked.connect(_on_recipient_selected.bind(1))
	if character_inventory_container_3:
		character_inventory_container_3.clicked.connect(_on_recipient_selected.bind(2))
	for c in [character_inventory_container_1, character_inventory_container_2, character_inventory_container_3]:
		if c and c.has_signal("slot_drag_started"):
			c.slot_drag_started.connect(_on_slot_drag_started)

func _connect_inventory_hover() -> void:
	if not _sell_box or not _sell_box.has_method("set_hovered_item"):
		return
	for c in [character_inventory_container_1, character_inventory_container_2, character_inventory_container_3]:
		if c and c.has_signal("item_hovered"):
			c.item_hovered.connect(_sell_box.set_hovered_item)
		if c and c.has_signal("item_unhovered"):
			c.item_unhovered.connect(_on_inventory_unhovered)

func _on_inventory_unhovered() -> void:
	if _sell_box:
		_sell_box.set_hovered_item("")

## items_to_sell: Array of item_id strings (or {item_id, qty}). Empty = all items. Default qty 1 per item.
## Resource items (health potion, camping supplies, sharpening stone, magical dust) go in the left resource panel; others in Buy tab.
## Vendors always have at least 3 of the 4 resource types.
func open_vendor(party_members: Array, party_gold: int, items_to_sell: Array = []) -> void:
	_party_members = party_members
	_party_gold = party_gold
	_cancel_pending_buy()
	_vendor_stock.clear()
	if items_to_sell.is_empty():
		for id in ItemDatabase.get_all_ids():
			if ItemDatabase.is_bulk_loot(id):
				_vendor_stock[id] = randi_range(ItemDatabase.BULK_LOOT_QTY_MIN, ItemDatabase.BULK_LOOT_QTY_MAX)
			else:
				_vendor_stock[id] = 1
	else:
		for x in items_to_sell:
			if x is Dictionary:
				var id_key: String = str(x.get("item_id", ""))
				if not id_key.is_empty():
					_vendor_stock[id_key] = _vendor_stock.get(id_key, 0) + int(x.get("qty", 1))
			else:
				var id_key: String = str(x)
				if not id_key.is_empty():
					_vendor_stock[id_key] = _vendor_stock.get(id_key, 0) + 1
		_ensure_minimum_resource_stock(3)
	_pick_sale_items()
	_populate_resource_inventory_container()
	_populate_buy_tab()
	_populate_character_inventories()
	_update_gold_label()
	visible = true

func close_vendor() -> void:
	_cancel_custom_drag()
	_cancel_pending_buy()
	visible = false
	vendor_closed.emit()

func _clear_tab(tab: VBoxContainer) -> void:
	for c in tab.get_children():
		c.queue_free()

func _ensure_minimum_resource_stock(min_count: int) -> void:
	var resource_ids: Array[String] = []
	for id in ItemDatabase.BULK_LOOT_IDS:
		if ItemDatabase.has_item(id):
			resource_ids.append(id)
	if resource_ids.is_empty():
		return
	var stock_with_qty: int = 0
	for id in resource_ids:
		if _vendor_stock.get(id, 0) > 0:
			stock_with_qty += 1
	var ids_without_stock: Array[String] = []
	for id in resource_ids:
		if _vendor_stock.get(id, 0) <= 0:
			ids_without_stock.append(id)
	var to_add: int = mini(min_count - stock_with_qty, ids_without_stock.size())
	ids_without_stock.shuffle()
	for i in range(to_add):
		if i >= ids_without_stock.size():
			break
		var add_id: String = ids_without_stock[i]
		_vendor_stock[add_id] = randi_range(ItemDatabase.BULK_LOOT_QTY_MIN, ItemDatabase.BULK_LOOT_QTY_MAX)

func _populate_resource_inventory_container() -> void:
	if not _resource_inventory_container:
		return
	_clear_tab(_resource_inventory_container)
	for item_id in ItemDatabase.BULK_LOOT_IDS:
		if _vendor_stock.get(item_id, 0) <= 0:
			continue
		var item := ItemDatabase.get_item(item_id)
		if not item:
			continue
		var price: int = _sale_prices.get(item_id, item.value)
		var sale_label_text: String = ""
		if _sale_prices.has(item_id):
			sale_label_text = "SUPER SALE!" if price <= item.value / 2 else "SALE!"
		var at_capacity: bool = item.capacity > 0 and _get_party_item_count(item_id) >= item.capacity
		var btn: MarginContainer = VENDOR_ITEM_BUTTON_SCENE.instantiate()
		_resource_inventory_container.add_child(btn)
		btn.setup_buy(item_id, item.name, price, _vendor_stock[item_id], item.icon_path, sale_label_text, at_capacity)
		btn.buy_clicked.connect(_on_buy_clicked)

func _pick_sale_items() -> void:
	_sale_prices.clear()
	var stock_ids: Array[String] = []
	for id_key in _vendor_stock.keys():
		if _vendor_stock[id_key] > 0:
			stock_ids.append(id_key)
	if stock_ids.size() < 1:
		return
	var idx1: int = randi() % stock_ids.size()
	var idx2: int = randi() % stock_ids.size()
	var sale1_id: String = stock_ids[idx1]
	var sale2_id: String = stock_ids[idx2]
	var discount: float = 0.25
	if sale1_id == sale2_id:
		discount = 0.50
	var item1 := ItemDatabase.get_item(sale1_id)
	if item1:
		_sale_prices[sale1_id] = max(1, int(item1.value * (1.0 - discount)))
	if sale1_id != sale2_id:
		var item2 := ItemDatabase.get_item(sale2_id)
		if item2:
			_sale_prices[sale2_id] = max(1, int(item2.value * 0.75))

func _populate_buy_tab() -> void:
	_clear_tab(_buy_tab)
	for item_id in _vendor_stock.keys():
		if _vendor_stock[item_id] <= 0:
			continue
		if ItemDatabase.is_bulk_loot(item_id):
			continue
		var item := ItemDatabase.get_item(item_id)
		if not item:
			continue
		var price: int = _sale_prices.get(item_id, item.value)
		var sale_label_text: String = ""
		if _sale_prices.has(item_id):
			sale_label_text = "SUPER SALE!" if price <= item.value / 2 else "SALE!"
		var at_capacity: bool = item.capacity > 0 and _get_party_item_count(item_id) >= item.capacity
		var btn: MarginContainer = VENDOR_ITEM_BUTTON_SCENE.instantiate()
		_buy_tab.add_child(btn)
		btn.setup_buy(item_id, item.name, price, _vendor_stock[item_id], item.icon_path, sale_label_text, at_capacity)
		btn.buy_clicked.connect(_on_buy_clicked)

func _populate_character_inventories() -> void:
	if character_inventory_container_1:
		character_inventory_container_1.populate_from_member(_party_members[0] if _party_members.size() > 0 else null, 0)
	if character_inventory_container_2:
		character_inventory_container_2.populate_from_member(_party_members[1] if _party_members.size() > 1 else null, 1)
	if character_inventory_container_3:
		character_inventory_container_3.populate_from_member(_party_members[2] if _party_members.size() > 2 else null, 2)

func _get_party_item_count(item_id: String) -> int:
	if ItemDatabase.is_bulk_loot(item_id):
		var main = _get_main_node()
		return main.get_party_resource_count(item_id) if main else 0
	var total := 0
	for m in _party_members:
		total += m.get_item_count(item_id)
	return total

func _update_gold_label() -> void:
	_gold_label.text = str(_party_gold)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT and not e.pressed and _custom_drag_item_id != "":
			_on_custom_drag_released()
			get_viewport().set_input_as_handled()
	if _pending_buy_item_id != "" and event.is_action_pressed("ui_cancel"):
		_cancel_pending_buy()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _custom_drag_preview:
		_custom_drag_preview.global_position = get_global_mouse_position() + Vector2(-16, -16)

func _on_close_pressed() -> void:
	close_vendor()

func _on_buy_clicked(item_id: String) -> void:
	var item := ItemDatabase.get_item(item_id)
	if not item:
		return
	var price: int = _sale_prices.get(item_id, item.value)
	if _party_gold < price:
		return
	if _vendor_stock.get(item_id, 0) <= 0:
		return
	if item.capacity > 0 and _get_party_item_count(item_id) >= item.capacity:
		return
	if ItemDatabase.is_bulk_loot(item_id):
		var main = _get_main_node()
		if not main or not main.add_party_resource(item_id, 1):
			return
		_complete_buy(item_id, price)
	else:
		_pending_buy_item_id = item_id
		_pending_buy_price = price
		_set_awaiting_recipient(true)

func _on_recipient_selected(member_index: int) -> void:
	if _pending_buy_item_id == "":
		return
	if member_index < 0 or member_index >= _party_members.size():
		_cancel_pending_buy()
		return
	var member: HeroCharacter = _party_members[member_index]
	if not member.add_item(_pending_buy_item_id, 1):
		_cancel_pending_buy()
		return
	_complete_buy(_pending_buy_item_id, _pending_buy_price)
	_pending_buy_item_id = ""
	_pending_buy_price = 0
	_set_awaiting_recipient(false)

func _complete_buy(item_id: String, price: int) -> void:
	_vendor_stock[item_id] = _vendor_stock[item_id] - 1
	_party_gold -= price
	_update_gold_label()
	_populate_resource_inventory_container()
	_populate_buy_tab()
	_populate_character_inventories()
	party_gold_changed.emit(_party_gold)

func _on_slot_drag_started(item_id: String, member_index: int, icon: Texture2D) -> void:
	if _custom_drag_item_id != "":
		_cancel_custom_drag()
	_custom_drag_item_id = item_id
	_custom_drag_member_index = member_index
	_custom_drag_preview = TextureRect.new()
	_custom_drag_preview.texture = icon
	_custom_drag_preview.custom_minimum_size = Vector2(32, 32)
	_custom_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("add_child", _custom_drag_preview)
	call_deferred("_defer_set_drag_preview_position")
	if _sell_box:
		_sell_box.set_dragging_item(item_id)

func _defer_set_drag_preview_position() -> void:
	if _custom_drag_preview:
		_custom_drag_preview.global_position = get_global_mouse_position() + Vector2(-16, -16)

func _on_custom_drag_released() -> void:
	if _custom_drag_item_id == "":
		return
	var item_id := _custom_drag_item_id
	var member_index := _custom_drag_member_index
	_cancel_custom_drag()
	if _sell_box and _sell_box.is_mouse_over_sell_box():
		_on_sell_box_item_dropped(item_id, member_index)
	else:
		_try_transfer_to_ally_inventory(item_id, member_index)

func _cancel_custom_drag() -> void:
	if _custom_drag_preview:
		_custom_drag_preview.queue_free()
		_custom_drag_preview = null
	_custom_drag_item_id = ""
	_custom_drag_member_index = -1
	if _sell_box:
		_sell_box.set_dragging_item("")

func _try_transfer_to_ally_inventory(item_id: String, from_member_index: int) -> void:
	if from_member_index < 0 or from_member_index >= _party_members.size():
		return
	var mouse := get_global_mouse_position()
	var containers := [character_inventory_container_1, character_inventory_container_2, character_inventory_container_3]
	for to_index in range(containers.size()):
		if to_index == from_member_index:
			continue
		if to_index >= _party_members.size():
			continue
		var container = containers[to_index]
		if container and container.get_global_rect().has_point(mouse):
			var from_member: HeroCharacter = _party_members[from_member_index]
			var to_member: HeroCharacter = _party_members[to_index]
			if to_member.add_item(item_id, 1):
				from_member.remove_item(item_id, 1)
				_populate_character_inventories()
			return

func _on_sell_box_item_dropped(item_id: String, member_index: int) -> void:
	if member_index < 0 or member_index >= _party_members.size():
		return
	var item := ItemDatabase.get_item(item_id)
	if not item:
		return
	var member: HeroCharacter = _party_members[member_index]
	if not member.remove_item(item_id, 1):
		return
	var sell_price := item.value / 2
	_party_gold += sell_price
	_update_gold_label()
	_populate_character_inventories()
	party_gold_changed.emit(_party_gold)

func _cancel_pending_buy() -> void:
	if _pending_buy_item_id != "":
		_pending_buy_item_id = ""
		_pending_buy_price = 0
		_set_awaiting_recipient(false)

func _set_awaiting_recipient(awaiting: bool) -> void:
	var containers: Array = [character_inventory_container_1, character_inventory_container_2, character_inventory_container_3]
	for i in range(containers.size()):
		var container = containers[i]
		if container:
			container.set_awaiting_recipient(awaiting and i < _party_members.size())

func _get_main_node() -> Node:
	var root := get_tree().root
	for child in root.get_children():
		if child.name == "Main" or child.is_in_group("main"):
			return child
	return null
