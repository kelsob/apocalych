extends Control

signal vendor_closed()
signal party_gold_changed(new_gold: int)

const VENDOR_ITEM_BUTTON_SCENE := preload("res://scenes/2d/VendorItemButton.tscn")

var _party_members: Array[PartyMember] = []
var _party_gold: int = 0
## item_id -> quantity. Default 1 per item; decremented on purchase. Future: items_to_sell can pass {item_id, qty}.
var _vendor_stock: Dictionary = {}

@onready var _gold_label: Label = $MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/HBoxContainer/PartyGoldLabel
@onready var _close_button: Button = $MarginContainer/VBoxContainer/CloseButton
@onready var _buy_tab: VBoxContainer = $MarginContainer/VBoxContainer/TabContainer/Buy
@onready var _sell_tab: VBoxContainer = $MarginContainer/VBoxContainer/TabContainer/Sell

func _ready() -> void:
	visible = false
	_close_button.pressed.connect(_on_close_pressed)

## items_to_sell: Array of item_id strings (or {item_id, qty}). Empty = all items. Default qty 1 per item.
func open_vendor(party_members: Array, party_gold: int, items_to_sell: Array = []) -> void:
	_party_members = party_members
	_party_gold = party_gold
	_vendor_stock.clear()
	if items_to_sell.is_empty():
		for id in ItemDatabase.get_all_ids():
			if id == "health_potion":
				_vendor_stock[id] = randi_range(3, 5)
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
	_populate_buy_tab()
	_populate_sell_tab()
	_update_gold_label()
	visible = true

func close_vendor() -> void:
	visible = false
	vendor_closed.emit()

func _clear_tab(tab: VBoxContainer) -> void:
	for c in tab.get_children():
		c.queue_free()

func _populate_buy_tab() -> void:
	_clear_tab(_buy_tab)
	for item_id in _vendor_stock.keys():
		if _vendor_stock[item_id] <= 0:
			continue
		var item := ItemDatabase.get_item(item_id)
		if not item:
			continue
		var btn: MarginContainer = VENDOR_ITEM_BUTTON_SCENE.instantiate()
		_buy_tab.add_child(btn)
		btn.setup_buy(item_id, item.name, item.value, _vendor_stock[item_id], item.icon_path)
		btn.buy_clicked.connect(_on_buy_clicked)

func _populate_sell_tab() -> void:
	_clear_tab(_sell_tab)
	for member_idx in _party_members.size():
		var member: PartyMember = _party_members[member_idx]
		for item_id in member.get_inventory_ids():
			var count := member.get_item_count(item_id)
			if count <= 0:
				continue
			var item := ItemDatabase.get_item(item_id)
			if not item:
				continue
			var sell_price := item.value / 2
			var btn: MarginContainer = VENDOR_ITEM_BUTTON_SCENE.instantiate()
			_sell_tab.add_child(btn)
			btn.setup_sell(item_id, item.name, count, sell_price, member_idx, item.icon_path)
			btn.sell_clicked.connect(_on_sell_clicked)

func _update_gold_label() -> void:
	_gold_label.text = "Gold: %d" % _party_gold

func _on_close_pressed() -> void:
	close_vendor()

func _on_buy_clicked(item_id: String) -> void:
	var item := ItemDatabase.get_item(item_id)
	if not item or _party_gold < item.value:
		return
	if _vendor_stock.get(item_id, 0) <= 0:
		return
	if _party_members.is_empty():
		return
	if not _party_members[0].add_item(item_id, 1):
		return
	_vendor_stock[item_id] = _vendor_stock[item_id] - 1
	_party_gold -= item.value
	_update_gold_label()
	_populate_buy_tab()
	_populate_sell_tab()
	party_gold_changed.emit(_party_gold)

func _on_sell_clicked(item_id: String, member_index: int) -> void:
	if member_index < 0 or member_index >= _party_members.size():
		return
	var item := ItemDatabase.get_item(item_id)
	if not item:
		return
	var member: PartyMember = _party_members[member_index]
	if not member.remove_item(item_id, 1):
		return
	var sell_price := item.value / 2
	_party_gold += sell_price
	_update_gold_label()
	_populate_sell_tab()
	party_gold_changed.emit(_party_gold)
