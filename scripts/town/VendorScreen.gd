extends Control

signal vendor_closed()
signal party_gold_changed(new_gold: int)

const VENDOR_ITEM_BUTTON_SCENE := preload("res://scenes/2d/VendorItemButton.tscn")

var _party_members: Array[PartyMember] = []
var _party_gold: int = 0
## item_id -> quantity. Default 1 per item; decremented on purchase. Future: items_to_sell can pass {item_id, qty}.
var _vendor_stock: Dictionary = {}
## item_id -> sale_price. Set when vendor opens; two random items on sale (25% off). If both land on same item, 50% off (super sale).
var _sale_prices: Dictionary = {}

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
	_pick_sale_items()
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

func _populate_sell_tab() -> void:
	_clear_tab(_sell_tab)
	for member_idx in _party_members.size():
		var member: PartyMember = _party_members[member_idx]
		for item_id in member.get_inventory_ids():
			var count := member.get_item_count(item_id)
			if count <= 0:
				continue
			var item := ItemDatabase.get_item(item_id)
			if not item or not item.sellable:
				continue
			var sell_price := item.value / 2
			var btn: MarginContainer = VENDOR_ITEM_BUTTON_SCENE.instantiate()
			_sell_tab.add_child(btn)
			btn.setup_sell(item_id, item.name, count, sell_price, member_idx, item.icon_path)
			btn.sell_clicked.connect(_on_sell_clicked)

func _get_party_item_count(item_id: String) -> int:
	var total := 0
	for m in _party_members:
		total += m.get_item_count(item_id)
	return total

func _update_gold_label() -> void:
	_gold_label.text = str(_party_gold)

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
	if _party_members.is_empty():
		return
	if item.capacity > 0 and _get_party_item_count(item_id) >= item.capacity:
		return
	if not _party_members[0].add_item(item_id, 1):
		return
	_vendor_stock[item_id] = _vendor_stock[item_id] - 1
	_party_gold -= price
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
