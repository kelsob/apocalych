extends Control

## VendorSellBox - Drop zone for selling items. Custom drag: drop on this to sell.
## No Godot drag/drop - VendorScreen handles custom drag and checks is_mouse_over_sell_box().

var sell_price_label: Label = null

var _hovered_item_id: String = ""
var _dragging_item_id: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	sell_price_label = get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/SellPriceLabel") as Label
	if not sell_price_label:
		sell_price_label = get_node_or_null("SellPriceLabel") as Label

func set_hovered_item(item_id: String) -> void:
	_hovered_item_id = item_id if item_id else ""
	_update_preview()

func set_dragging_item(item_id: String) -> void:
	_dragging_item_id = item_id if item_id else ""
	_update_preview()

func is_mouse_over_sell_box() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())

func _process(_delta: float) -> void:
	_update_preview()

func _update_preview() -> void:
	if not sell_price_label:
		return
	var item_id: String = _dragging_item_id if not _dragging_item_id.is_empty() else _hovered_item_id
	if item_id.is_empty():
		sell_price_label.text = ""
		return
	var item := ItemDatabase.get_item(item_id) if ItemDatabase else null
	if not item or not item.sellable:
		sell_price_label.text = ""
		return
	var sell_price := item.value / 2
	sell_price_label.text = str(sell_price) + " g"
