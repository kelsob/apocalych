extends MarginContainer

## VendorItemButton - one row for buy or sell. Configure via setup_buy() or setup_sell().

signal buy_clicked(item_id: String)
signal sell_clicked(item_id: String, member_index: int)

var _item_id: String = ""
var _member_index: int = -1  # For sell: which party member owns this

@onready var item_texture_rect: TextureRect = $HBoxContainer/ItemTextureRect
@onready var _name_label: Label = $HBoxContainer/ItemNameLabel
@onready var _price_label: Label = $HBoxContainer/PriceLabel
@onready var _action_button: Button = $HBoxContainer/Button
@onready var _item_quantity_label: Label = $HBoxContainer/ItemQuantityLabel
@onready var _sale_label: Label = $HBoxContainer/SaleLabel

func _ready() -> void:
	_action_button.pressed.connect(_on_action_pressed)

func setup_buy(item_id: String, item_name: String, price: int, qty: int = 1, icon_path: String = "", sale_label_text: String = "", at_capacity: bool = false) -> void:
	_item_id = item_id
	_member_index = -1
	_name_label.text = item_name
	_price_label.text = str(price)
	_item_quantity_label.text = "x%d" % qty
	_item_quantity_label.visible = qty > 1
	if _sale_label:
		_sale_label.text = sale_label_text
		_sale_label.visible = not sale_label_text.is_empty()
	_set_icon(icon_path)
	_action_button.text = "Buy"
	_action_button.visible = true
	_action_button.disabled = at_capacity

func setup_sell(item_id: String, item_name: String, count: int, sell_price: int, member_index: int, icon_path: String = "") -> void:
	_item_id = item_id
	_member_index = member_index
	_name_label.text = item_name
	_price_label.text = str(sell_price)
	if _sale_label:
		_sale_label.visible = false
	_item_quantity_label.text = "x%d" % count
	_item_quantity_label.visible = count > 1
	_set_icon(icon_path)
	_action_button.text = "Sell"
	_action_button.visible = true

func _set_icon(icon_path: String) -> void:
	if icon_path.is_empty():
		item_texture_rect.texture = null
		item_texture_rect.visible = false
		return
	var tex: Texture2D = load(icon_path) as Texture2D
	if tex:
		item_texture_rect.texture = tex
		item_texture_rect.visible = true
	else:
		item_texture_rect.texture = null
		item_texture_rect.visible = false

func _on_action_pressed() -> void:
	if _member_index >= 0:
		sell_clicked.emit(_item_id, _member_index)
	else:
		buy_clicked.emit(_item_id)
