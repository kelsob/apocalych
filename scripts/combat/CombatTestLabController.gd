extends Control
class_name CombatTestLabController

## Combat test lab — node paths match [code]res://scenes/2d/CombatTestLab.tscn[/code].
## The scene must include a [CanvasLayer] child named [code]CombatHost[/code]: [CombatScene] is parented there
## so combat draws above the setup UI (layer ordering). Add it in the editor if you rename the node, update [member combat_host].

const COMBAT_SCENE_PATH: String = "res://scenes/combat/CombatScene.tscn"
const FULL_HEAL_BEFORE_REMATCH: bool = true
const COMBAT_END_DELAY_OVERRIDE: float = 0.5

@onready var setup_screen: Panel = $SetupScreen
@onready var character_select_1: OptionButton = $SetupScreen/VBoxContainer/HBoxContainer/PartySelectionContainer/CharacterSelect1
@onready var character_select_2: OptionButton = $SetupScreen/VBoxContainer/HBoxContainer/PartySelectionContainer/CharacterSelect2
@onready var character_select_3: OptionButton = $SetupScreen/VBoxContainer/HBoxContainer/PartySelectionContainer/CharacterSelect3
@onready var level_up_button_1: Button = $SetupScreen/VBoxContainer/HBoxContainer/PartyModificationContainer/LevelUpButton1
@onready var level_up_button_2: Button = $SetupScreen/VBoxContainer/HBoxContainer/PartyModificationContainer/LevelUpButton2
@onready var level_up_button_3: Button = $SetupScreen/VBoxContainer/HBoxContainer/PartyModificationContainer/LevelUpButton3
@onready var inventory_list_1: ItemList = $SetupScreen/VBoxContainer/HBoxContainer/PartyInventoryContainer/InventoryList1
@onready var inventory_list_2: ItemList = $SetupScreen/VBoxContainer/HBoxContainer/PartyInventoryContainer/InventoryList2
@onready var inventory_list_3: ItemList = $SetupScreen/VBoxContainer/HBoxContainer/PartyInventoryContainer/InventoryList3
@onready var encounter_options: OptionButton = $SetupScreen/VBoxContainer/HBoxContainer/EncounterContainer/EncounterOptions
@onready var combat_modifier_list: ItemList = $SetupScreen/VBoxContainer/HBoxContainer/CombatModifiersContainer/CombatModifierList
@onready var launch_button: Button = $SetupScreen/VBoxContainer/LaunchButton
@onready var combat_host: CanvasLayer = $CombatHost

var _encounter_rows: Array[Dictionary] = []
var _hero_rows: Array[Dictionary] = []
## Target level per slot (1–99) before building the party.
var _slot_levels: Array[int] = [1, 1, 1]
## Last party used in combat ([HeroCharacter] references; HP/XP carry over).
var _session_party: Array[HeroCharacter] = []
var _session_encounter_path: String = ""
var _use_stored_party_on_next_launch: bool = false
var _awaiting_test_result: bool = false
## Reserved for when combat modifiers are applied in [CombatController].
var _last_selected_modifier_ids: Array[String] = []


func _ready() -> void:
	_encounter_rows = CombatTestSupport.list_combat_encounters()
	_hero_rows = CombatTestSupport.list_hero_templates()
	_populate_encounter_options()
	_populate_character_options(character_select_1)
	_populate_character_options(character_select_2)
	_populate_character_options(character_select_3)
	_populate_inventory_list(inventory_list_1)
	_populate_inventory_list(inventory_list_2)
	_populate_inventory_list(inventory_list_3)
	_populate_combat_modifier_list()
	level_up_button_1.pressed.connect(_on_level_up_slot.bind(0))
	level_up_button_2.pressed.connect(_on_level_up_slot.bind(1))
	level_up_button_3.pressed.connect(_on_level_up_slot.bind(2))
	launch_button.pressed.connect(_on_launch_pressed)
	if not CombatController.combat_test_session_ended.is_connected(_on_combat_test_session_ended):
		CombatController.combat_test_session_ended.connect(_on_combat_test_session_ended)


func _exit_tree() -> void:
	if CombatController.combat_test_session_ended.is_connected(_on_combat_test_session_ended):
		CombatController.combat_test_session_ended.disconnect(_on_combat_test_session_ended)


func _populate_encounter_options() -> void:
	encounter_options.clear()
	for row in _encounter_rows:
		var label: String = str(row.get("name", "")) + "  (" + str(row.get("id", "")) + ")"
		encounter_options.add_item(label)
		encounter_options.set_item_metadata(encounter_options.item_count - 1, row["path"])


func _populate_character_options(btn: OptionButton) -> void:
	btn.clear()
	btn.add_item("-- Empty --")
	btn.set_item_metadata(0, "")
	for row in _hero_rows:
		var label: String = str(row.get("name", "")) + "  (" + str(row.get("id", "")) + ")"
		btn.add_item(label)
		btn.set_item_metadata(btn.item_count - 1, row["path"])


func _populate_inventory_list(list: ItemList) -> void:
	list.clear()
	list.select_mode = ItemList.SELECT_MULTI
	var ids: Array[String] = CombatTestSupport.list_carriable_item_ids()
	for item_id in ids:
		var it: Item = ItemDatabase.get_item(item_id)
		var label: String = item_id
		if it:
			label = it.name + "  (" + item_id + ")"
		list.add_item(label)
		list.set_item_metadata(list.item_count - 1, item_id)


func _populate_combat_modifier_list() -> void:
	combat_modifier_list.clear()
	combat_modifier_list.select_mode = ItemList.SELECT_MULTI
	for row in CombatTestSupport.list_combat_modifier_placeholders():
		combat_modifier_list.add_item(str(row.get("label", "")))
		combat_modifier_list.set_item_metadata(combat_modifier_list.item_count - 1, str(row.get("id", "")))


func _on_level_up_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_levels.size():
		return
	_slot_levels[slot_index] = mini(99, _slot_levels[slot_index] + 1)
	print("CombatTestLab: slot %d target level -> %d" % [slot_index + 1, _slot_levels[slot_index]])


func _get_selected_hero_path(btn: OptionButton) -> String:
	if btn.item_count <= 0:
		return ""
	var idx: int = btn.selected
	if idx < 0:
		idx = 0
	return str(btn.get_item_metadata(idx))


func _get_selected_encounter_path() -> String:
	if encounter_options.item_count <= 0:
		return ""
	var idx: int = encounter_options.selected
	if idx < 0:
		idx = 0
	return str(encounter_options.get_item_metadata(idx))


func _selected_item_ids_from_list(list: ItemList) -> Array[String]:
	var out: Array[String] = []
	for idx in list.get_selected_items():
		out.append(str(list.get_item_metadata(idx)))
	return out


func _capture_modifier_selection() -> void:
	_last_selected_modifier_ids.clear()
	for idx in combat_modifier_list.get_selected_items():
		var id: String = str(combat_modifier_list.get_item_metadata(idx))
		if not id.is_empty():
			_last_selected_modifier_ids.append(id)


func _build_party_from_ui() -> Array[HeroCharacter]:
	var paths: Array[String] = [
		_get_selected_hero_path(character_select_1),
		_get_selected_hero_path(character_select_2),
		_get_selected_hero_path(character_select_3),
	]
	var inv: Array[Array] = [
		_selected_item_ids_from_list(inventory_list_1),
		_selected_item_ids_from_list(inventory_list_2),
		_selected_item_ids_from_list(inventory_list_3),
	]
	_capture_modifier_selection()
	return CombatTestSupport.build_party_from_slots(paths, _slot_levels, inv)


func _on_launch_pressed() -> void:
	if CombatController.combat_active:
		push_warning("CombatTestLab: combat already running")
		return
	var enc_path := _get_selected_encounter_path()
	if enc_path.is_empty():
		push_warning("CombatTestLab: select an encounter")
		return
	var party: Array[HeroCharacter] = []
	if _use_stored_party_on_next_launch and not _session_party.is_empty():
		party = _session_party
		_use_stored_party_on_next_launch = false
	else:
		party = _build_party_from_ui()
	if party.is_empty():
		push_warning("CombatTestLab: choose at least one non-empty character slot")
		return
	_session_party = party
	_session_encounter_path = enc_path
	await _run_combat(enc_path, party)


func _run_combat(encounter_path: String, party: Array[HeroCharacter]) -> void:
	var encounter: CombatEncounter = CombatTestSupport.load_encounter(encounter_path)
	if encounter == null:
		push_error("CombatTestLab: could not load encounter: %s" % encounter_path)
		return
	if not ResourceLoader.exists(COMBAT_SCENE_PATH):
		push_error("CombatTestLab: missing %s" % COMBAT_SCENE_PATH)
		return
	var combat_scene: Control = load(COMBAT_SCENE_PATH).instantiate() as Control
	if COMBAT_END_DELAY_OVERRIDE >= 0.0:
		combat_scene.set("combat_end_delay", COMBAT_END_DELAY_OVERRIDE)
	combat_host.add_child(combat_scene)
	_awaiting_test_result = true
	await get_tree().process_frame
	if not _last_selected_modifier_ids.is_empty():
		print("CombatTestLab: combat modifiers selected (not applied yet): ", _last_selected_modifier_ids)
	CombatController.start_combat_from_encounter(encounter, party, true)
	if not CombatController.combat_active:
		_awaiting_test_result = false


func _on_combat_test_session_ended(_victory: bool, rewards: Dictionary) -> void:
	if not _awaiting_test_result:
		return
	_awaiting_test_result = false
	var summary: String = CombatTestSupport.rewards_summary(rewards) + "\n" + CombatTestSupport.party_status_summary(_session_party)
	print("CombatTestLab: ", summary)
	if FULL_HEAL_BEFORE_REMATCH:
		CombatTestSupport.full_heal_party(_session_party)
	setup_screen.visible = true


## Call from a future post-combat UI (e.g. “fight again”) if you add buttons later.
func fight_again_with_session() -> void:
	if CombatController.combat_active:
		return
	if _session_encounter_path.is_empty() or _session_party.is_empty():
		push_warning("CombatTestLab: no session to repeat")
		return
	await _run_combat(_session_encounter_path, _session_party)


## Call from a future button to return to setup but keep party references for next Launch.
func prepare_keep_party_for_next_launch() -> void:
	_use_stored_party_on_next_launch = true


## Call from a future button to discard session party so next Launch rebuilds from UI.
func clear_session_party() -> void:
	_session_party.clear()
	_use_stored_party_on_next_launch = false
