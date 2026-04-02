extends Control
class_name EventChoice

## EventChoice - A single selectable choice entry in the EventLog.
## Root is a Label. $Button handles clicks. Supports three visual states.
## States: AVAILABLE (default), SELECTED (green - chosen), REJECTED (gray - not chosen)
@onready var button: Button = $Button
@onready var choice_text: Label = $HBoxContainer/Label
@onready var choice_icon: TextureRect = $HBoxContainer/TextureRect

var choice_data: Dictionary = {}
var _pending_choice: Dictionary = {}

## For `stat_challenge` choices: -1 = auto (best stat), else `Main.current_party_members` index.
var _stat_actor_slot_override: int = -1
## True while cursor is over this choice's button (used for stat actor cycling input).
var _mouse_over_button: bool = false

enum State { AVAILABLE, SELECTED, REJECTED }
var _state: State = State.AVAILABLE

var _hover_tween: Tween = null
var _intro_tween: Tween = null
var _bob_tween: Tween = null

signal choice_selected(choice: Dictionary)

func _ready():
	modulate.a = 0.0
	if button:
		button.pressed.connect(_on_button_pressed)
		button.mouse_entered.connect(_on_mouse_entered)
		button.mouse_exited.connect(_on_mouse_exited)
		button.gui_input.connect(_on_button_gui_input)
	else:
		push_error("EventChoiceButton: Button node not found")
	if not _pending_choice.is_empty():
		_apply_choice_data(_pending_choice)


func _input(_event: InputEvent) -> void:
	if _state != State.AVAILABLE:
		return
	if not _choice_has_stat_challenge() or not _mouse_over_button:
		return
	if Input.is_action_just_pressed("ui_left"):
		_cycle_stat_actor(-1)
		get_viewport().set_input_as_handled()
	elif Input.is_action_just_pressed("ui_right"):
		_cycle_stat_actor(1)
		get_viewport().set_input_as_handled()


func _on_button_gui_input(event: InputEvent) -> void:
	if _state != State.AVAILABLE:
		return
	if not _choice_has_stat_challenge():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_stat_actor(-1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_stat_actor(1)
			get_viewport().set_input_as_handled()


func _choice_has_stat_challenge() -> bool:
	var sc: Variant = choice_data.get("stat_challenge", {})
	return sc is Dictionary and not sc.is_empty()


func _cycle_stat_actor(delta: int) -> void:
	var main: Node = get_tree().get_first_node_in_group("main") if get_tree() else null
	var members: Array = main.current_party_members if main and "current_party_members" in main else []
	var n: int = members.size()
	if n <= 0:
		return
	var cur: int = get_stat_actor_slot_for_resolution()
	var nxt: int = (cur + delta) % n
	if nxt < 0:
		nxt += n
	_stat_actor_slot_override = nxt
	_apply_choice_data(choice_data)

## Set the choice data and update display
func set_choice_data(choice: Dictionary):
	choice_data = choice
	_pending_choice = choice
	if choice_text:
		_apply_choice_data(choice)

func _apply_choice_data(choice: Dictionary):
	var display_text: String = str(choice.get("text", "Choice"))
	var sc: Variant = choice.get("stat_challenge", {})
	if sc is Dictionary and not sc.is_empty():
		display_text = _build_stat_challenge_label(display_text, sc)
	choice_text.text = display_text
	if choice.get("disabled", false):
		if button:
			button.disabled = true
		modulate = Color(1.0, 1.0, 1.0, 0.4)

const _SELECTED_ICON = preload("res://assets/icons/event-choice-selected.png")

## Transition to SELECTED state - the choice the player picked (manuscript green)
func select():
	_state = State.SELECTED
	_stop_bob()
	if button:
		button.disabled = true
	choice_text.add_theme_color_override("font_color", ProjectColors.EVENT_CHOICE_SELECTED)
	if choice_icon:
		choice_icon.texture = _SELECTED_ICON

## Transition to REJECTED state - a choice the player did not pick (ghosted)
func reject():
	_state = State.REJECTED
	_stop_bob()
	if button:
		button.disabled = true
	add_theme_color_override("font_color", ProjectColors.EVENT_CHOICE_REJECTED)
	modulate.a = 0.5

func _on_mouse_entered():
	if _state != State.AVAILABLE:
		return
	_mouse_over_button = true
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.tween_property(choice_text, "modulate", Color(1, 1.25, 1.0, 1.0), 0.10)
	_hover_tween.tween_property(choice_icon, "modulate", Color(1, 1.25, 1.0, 1.0), 0.10)
	_start_bob()

func _on_mouse_exited():
	if _state != State.AVAILABLE:
		return
	_mouse_over_button = false
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.tween_property(choice_text, "modulate", Color.WHITE, 0.15)
	_hover_tween.tween_property(choice_icon, "modulate", Color.WHITE, 0.15)
	_stop_bob()

var _bob_origin_x: float = 0.0

## Gently slide icon left/right while hovered.
## HBoxContainer only re-sorts on resize so position.x tweens hold during stable layout.
func _start_bob() -> void:
	if not choice_icon:
		return
	if _bob_tween:
		_bob_tween.kill()
	_bob_origin_x = choice_icon.position.x
	# origin → +4 → -4 → origin, looped
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(choice_icon, "position:x", _bob_origin_x + 4.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(choice_icon, "position:x", _bob_origin_x - 4.0, 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(choice_icon, "position:x", _bob_origin_x,       0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Kill the bob and slide icon back to its layout position.
func _stop_bob() -> void:
	if _bob_tween:
		_bob_tween.kill()
		_bob_tween = null
	if choice_icon:
		var snap_tween := create_tween()
		snap_tween.tween_property(choice_icon, "position:x", _bob_origin_x, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _build_stat_challenge_label(base_text: String, sc: Dictionary) -> String:
	var stat_key: String = str(sc.get("primary_stat", "strength"))
	var main: Node = get_tree().get_first_node_in_group("main") if get_tree() else null
	var members: Array = main.current_party_members if main and "current_party_members" in main else []
	var slot: int = _stat_actor_slot_override
	if slot < 0:
		slot = EventStatCheck.default_actor_index_for_stat(stat_key, members)
	return EventStatCheck.build_choice_label(base_text, stat_key, slot, members)


## Slot into `Main.current_party_members` used when this choice resolves. Override -1 = best primary stat.
func get_stat_actor_slot_for_resolution() -> int:
	var sc: Variant = choice_data.get("stat_challenge", {})
	if not sc is Dictionary or sc.is_empty():
		return 0
	var stat_key: String = str(sc.get("primary_stat", "strength"))
	var main: Node = get_tree().get_first_node_in_group("main") if get_tree() else null
	var members: Array = main.current_party_members if main and "current_party_members" in main else []
	if _stat_actor_slot_override >= 0 and _stat_actor_slot_override < members.size():
		return _stat_actor_slot_override
	return EventStatCheck.default_actor_index_for_stat(stat_key, members)


## Call from your override UI (cycle / dropdown). Clamped to party size.
func set_stat_actor_slot_override(slot: int) -> void:
	var main: Node = get_tree().get_first_node_in_group("main") if get_tree() else null
	var n: int = main.current_party_members.size() if main and "current_party_members" in main else 0
	if n <= 0:
		return
	_stat_actor_slot_override = clampi(slot, 0, n - 1)
	if choice_data.has("stat_challenge"):
		_apply_choice_data(choice_data)


func clear_stat_actor_slot_override() -> void:
	_stat_actor_slot_override = -1
	if choice_data.has("stat_challenge"):
		_apply_choice_data(choice_data)


func _on_button_pressed():
	if _state != State.AVAILABLE:
		return
	choice_selected.emit(choice_data)

## Fire-and-forget staggered fade in. delay staggers choices within a container.
func animate_in(delay: float = 0.0, fade_duration: float = 0.10) -> void:
	if _intro_tween:
		_intro_tween.kill()
	modulate.a = 0.0
	_intro_tween = create_tween()
	if delay > 0.0:
		_intro_tween.tween_interval(delay)
	_intro_tween.tween_property(self, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Snap to fully visible immediately.
func snap_visible() -> void:
	if _intro_tween:
		_intro_tween.kill()
		_intro_tween = null
	modulate.a = 1.0
