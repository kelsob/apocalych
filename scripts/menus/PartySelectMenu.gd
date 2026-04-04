extends Control
class_name PartySelectMenu

## Party select: three `OptionButton`s → `HeroDatabase.populate_starter_option_button` (default starters + meta-unlocked heroes) → `HeroDatabase.instantiate_for_run`.
## Wire `hero_option_slot_*` in the Inspector, or leave unset to use fallbacks `VBoxContainer/OptionButton*`.
## Adjust `$StartGameButton`, `$RaceDetailsContainer/...`, etc. if your node paths differ.

signal start_game_pressed(party_members: Array[HeroCharacter], world_name: String)
signal back_to_main_menu_pressed

@onready var hero_option_slot_1: OptionButton = $VBoxContainer/OptionButton
@onready var hero_option_slot_2: OptionButton = $VBoxContainer/OptionButton2
@onready var hero_option_slot_3: OptionButton = $VBoxContainer/OptionButton3

@onready var start_game_button: Button = $StartGameButton
@onready var back_button: Button = $BackButton
@onready var world_name_input: LineEdit = $HBoxContainer2/WorldNameInput
@onready var randomize_world_name_button: Button = $HBoxContainer2/RandomizeWorldNameButton

@onready var race_name_label: Label = $RaceDetailsContainer/RaceNameLabel
@onready var race_description_label: Label = $RaceDetailsContainer/RaceDescriptionLabel
@onready var class_name_label: Label = $ClassDetailsContainer/ClassNameLabel
@onready var class_description_label: Label = $ClassDetailsContainer/ClassDescriptionLabel

var world_name_generator: WorldNameGenerator = WorldNameGenerator.new()
var world_name: String = ""

var _last_hero_option_changed: OptionButton = null


func _ready() -> void:
	_resolve_hero_slots()
	if not _hero_slots_ok():
		push_error("PartySelectMenu: set hero_option_slot_1..3 in Inspector (three OptionButtons).")
		return

	if start_game_button:
		start_game_button.pressed.connect(_on_start_game_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if randomize_world_name_button:
		randomize_world_name_button.pressed.connect(_on_randomize_world_name_pressed)
	if world_name_input:
		world_name_input.text_changed.connect(_on_world_name_changed)

	for ob in _hero_slots_array():
		HeroDatabase.populate_starter_option_button(ob)
		ob.item_selected.connect(_on_hero_option_changed.bind(ob))
		var popup: PopupMenu = ob.get_popup()
		if popup:
			popup.about_to_popup.connect(_sync_unique_hero_filters)

	hero_option_slot_1.selected = 0
	hero_option_slot_2.selected = 1
	hero_option_slot_3.selected = 2
	_last_hero_option_changed = hero_option_slot_1
	_sync_unique_hero_filters()

	randomize_world_name()
	call_deferred("_update_description_labels")


## Rebuild hero dropdowns from HeroDatabase (e.g. after MetaProgression.reset_all_meta). Preserves selection by template path when still available.
func refresh_starter_hero_options() -> void:
	if not _hero_slots_ok():
		return
	var slots: Array[OptionButton] = _hero_slots_array()
	var prev_paths: Array[String] = []
	for ob in slots:
		prev_paths.append(str(ob.get_item_metadata(ob.selected)))
	for ob in slots:
		HeroDatabase.populate_starter_option_button(ob)
	for slot_idx in range(slots.size()):
		var ob: OptionButton = slots[slot_idx]
		var want: String = prev_paths[slot_idx]
		var idx := -1
		for j in range(ob.item_count):
			if str(ob.get_item_metadata(j)) == want:
				idx = j
				break
		ob.set_block_signals(true)
		if idx >= 0:
			ob.select(idx)
		else:
			ob.select(0)
		ob.set_block_signals(false)
	_fix_duplicate_selections_if_any()
	_sync_unique_hero_filters()
	_update_description_labels()


func _resolve_hero_slots() -> void:
	if hero_option_slot_1 == null:
		hero_option_slot_1 = get_node_or_null("VBoxContainer/OptionButton") as OptionButton
	if hero_option_slot_2 == null:
		hero_option_slot_2 = get_node_or_null("VBoxContainer/OptionButton2") as OptionButton
	if hero_option_slot_3 == null:
		hero_option_slot_3 = get_node_or_null("VBoxContainer/OptionButton3") as OptionButton


func _hero_slots_ok() -> bool:
	return hero_option_slot_1 != null and hero_option_slot_2 != null and hero_option_slot_3 != null


func _hero_slots_array() -> Array[OptionButton]:
	return [hero_option_slot_1, hero_option_slot_2, hero_option_slot_3]


## Disables each menu item whose template path is already chosen in another slot (same path stays enabled on that slot).
func _sync_unique_hero_filters() -> void:
	if not _hero_slots_ok():
		return
	var slots: Array[OptionButton] = _hero_slots_array()
	var paths: Array[String] = []
	for ob in slots:
		paths.append(str(ob.get_item_metadata(ob.selected)))

	for slot_idx in range(slots.size()):
		var ob: OptionButton = slots[slot_idx]
		var my_path: String = paths[slot_idx]
		for i in range(ob.item_count):
			var p: String = str(ob.get_item_metadata(i))
			if p.is_empty():
				continue
			var taken_elsewhere := false
			for j in range(slots.size()):
				if j == slot_idx:
					continue
				if paths[j] == p:
					taken_elsewhere = true
					break
			if p == my_path:
				ob.set_item_disabled(i, false)
			else:
				ob.set_item_disabled(i, taken_elsewhere)


func _on_hero_option_changed(ob: OptionButton, _index: int) -> void:
	_last_hero_option_changed = ob
	_sync_unique_hero_filters()
	_fix_duplicate_selections_if_any()
	_sync_unique_hero_filters()
	_update_description_labels()


## Belt-and-suspenders if state ever desyncs: bump a conflicting slot to the first free template path.
func _fix_duplicate_selections_if_any() -> void:
	if not _hero_slots_ok():
		return
	for _i in range(3):
		var slots: Array[OptionButton] = _hero_slots_array()
		var paths: Array[String] = []
		for ob in slots:
			paths.append(str(ob.get_item_metadata(ob.selected)))
		var seen: Dictionary = {}
		var fixed := false
		for slot_idx in range(slots.size()):
			var p: String = paths[slot_idx]
			if p.is_empty():
				continue
			if seen.has(p):
				var ob: OptionButton = slots[slot_idx]
				var picked := _first_free_item_index(ob, paths, slot_idx)
				if picked >= 0:
					ob.set_block_signals(true)
					ob.select(picked)
					ob.set_block_signals(false)
					fixed = true
					break
			else:
				seen[p] = slot_idx
		if not fixed:
			break


func _first_free_item_index(ob: OptionButton, paths: Array[String], slot_idx: int) -> int:
	for i in range(ob.item_count):
		var p: String = str(ob.get_item_metadata(i))
		if p.is_empty():
			continue
		var used_elsewhere := false
		for j in range(paths.size()):
			if j == slot_idx:
				continue
			if paths[j] == p:
				used_elsewhere = true
				break
		if not used_elsewhere:
			return i
	return -1


func get_party_members() -> Array[HeroCharacter]:
	var members: Array[HeroCharacter] = []
	if not _hero_slots_ok():
		return members
	for ob in [hero_option_slot_1, hero_option_slot_2, hero_option_slot_3]:
		var path: String = str(ob.get_item_metadata(ob.selected))
		if path.is_empty():
			return []
		var hero: HeroCharacter = HeroDatabase.instantiate_for_run(path)
		if hero:
			members.append(hero)
	return members


func _on_start_game_pressed() -> void:
	var party: Array[HeroCharacter] = get_party_members()
	if party.size() != 3:
		return
	var current_world_name: String = world_name
	if world_name_input and not world_name_input.text.is_empty():
		current_world_name = world_name_input.text
	start_game_pressed.emit(party, current_world_name)


func _on_back_pressed() -> void:
	back_to_main_menu_pressed.emit()


func _on_randomize_world_name_pressed() -> void:
	randomize_world_name()


func _on_world_name_changed(new_text: String) -> void:
	world_name = new_text


func randomize_world_name() -> void:
	world_name = world_name_generator.generate_name()
	if world_name_input:
		world_name_input.text = world_name


func _update_description_labels() -> void:
	if not _hero_slots_ok():
		return
	var ob: OptionButton = _last_hero_option_changed if _last_hero_option_changed else hero_option_slot_1
	var path: String = str(ob.get_item_metadata(ob.selected))
	var t: HeroCharacter = HeroDatabase.load_template(path)
	if t and t.race:
		race_description_label.text = t.race.description
		race_name_label.text = t.race.race_name
	else:
		race_description_label.text = ""
	if t and t.class_resource:
		class_description_label.text = t.class_resource.description
		class_name_label.text = t.class_resource.name
	else:
		class_description_label.text = ""
