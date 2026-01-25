extends Control
class_name CharacterSelect

## Character Select - handles individual character creation (name, race, class)

signal character_data_changed(changed_select: CharacterSelect)

# Character data
var character_name: String = ""
var selected_race: Race = null
var selected_class: Class = null

# UI references (you'll connect these in the scene)
@onready var name_input: LineEdit = $VBoxContainer/NameInput
@onready var race_option_button: OptionButton = $VBoxContainer/RaceSelectButton
@onready var class_option_button: OptionButton = $VBoxContainer/ClassSelectButton

# Available options (will be populated from resources)
var available_races: Array[Race] = []
var available_classes: Array[Class] = []

# Race-based name lists
var race_names: Dictionary = {
	"human": [
		"Aldric", "Brenna", "Cedric", "Dara", "Eamon", "Fiona", "Gareth", "Helena",
		"Ivor", "Jenna", "Kieran", "Lydia", "Marcus", "Nora", "Owen", "Petra",
		"Quinn", "Rhian", "Sebastian", "Tara", "Ulric", "Vera", "Wesley", "Yara",
		"Zane", "Aria", "Benedict", "Cora", "Dorian", "Elara", "Finn", "Gwen",
		"Harold", "Iris", "Jasper", "Kara", "Lucas", "Maya", "Nathan", "Ophelia",
		"Percival", "Quinn", "Rowan", "Sage", "Tristan", "Ursula", "Victor", "Willow",
		"Xander", "Yvette", "Zara", "Arthur", "Beatrice", "Caspian", "Delilah", "Ethan",
		"Freya", "Gideon", "Hazel", "Ivan", "Jade", "Kai", "Luna", "Morgan", "Nova",
		"Orion", "Phoebe", "Quincy", "Raven", "Silas", "Thea", "Violet", "Wyatt"
	],
	"dwarf": [
		"Thorin", "Dwalin", "Balin", "Gimli", "Durin", "Fili", "Kili", "Bofur",
		"Bombur", "Dori", "Nori", "Ori", "Oin", "Gloin", "Thrain", "Thror",
		"Fundin", "Gror", "Frerin", "Dis", "Dain", "Bifur", "Bombur", "Dwalin",
		"Gimli", "Gloin", "Nori", "Oin", "Ori", "Thorin", "Balin", "Bofur",
		"Bombur", "Dori", "Fili", "Kili", "Oin", "Ori", "Thorin", "Dwalin",
		"Gundar", "Hakon", "Ivar", "Jorik", "Krag", "Lokir", "Magnar", "Njal",
		"Orik", "Pjodolf", "Ragnar", "Skuli", "Thorgrim", "Ulfar", "Viggo", "Wulfgar",
		"Yngvar", "Zoltan", "Borin", "Dagmar", "Erik", "Fjord", "Grimnir", "Haldor",
		"Ingvar", "Jorund", "Kjell", "Loki", "Magnus", "Nils", "Olaf", "Rurik"
	],
	"hobbit": [
		"Bilbo", "Frodo", "Samwise", "Merry", "Pippin", "Hamfast", "Drogo", "Primula",
		"Belladonna", "Bungo", "Lobelia", "Otho", "Rosie", "Ted", "Daisy", "Hamson",
		"Halfred", "May", "Marigold", "Tom", "Jolly", "Nibs", "Nim", "Daisy",
		"Bungo", "Bell", "Dora", "Dudo", "Fosco", "Gerontius", "Hildigrim", "Isengrim",
		"Lalia", "Mungo", "Peregrin", "Rosa", "Seredic", "Tobold", "Wilcome", "Adalgrim",
		"Bandobras", "Cottar", "Doderic", "Eglantine", "Ferdibrand", "Goldilocks", "Hildifons",
		"Isembold", "Lavender", "Marmadas", "Nob", "Otho", "Pansy", "Reginard", "Sapphira",
		"Tobias", "Wilcome", "Adelard", "Basso", "Celandine", "Diamond", "Everard", "Faramir"
	],
	"elf": [
		"Legolas", "Arwen", "Elrond", "Galadriel", "Celeborn", "Thranduil", "Elrohir",
		"Elladan", "Glorfindel", "Erestor", "Lindir", "Haldir", "Rumil", "Orophin",
		"Celebrimbor", "Gil-galad", "Cirdan", "Ecthelion", "Fingolfin", "Finrod",
		"Luthien", "Maedhros", "Maglor", "Turgon", "Idril", "Tuor", "Earendil",
		"Elwing", "Elros", "Elrond", "Arwen", "Legolas", "Thranduil", "Galadriel",
		"Celeborn", "Elrohir", "Elladan", "Glorfindel", "Erestor", "Lindir",
		"Aerandir", "Beleg", "Caranthir", "Daeron", "Eol", "Feanor", "Gwindor", "Haldir",
		"Ingwe", "Jarlaxle", "Kili", "Luthien", "Maeglin", "Nimrodel", "Orodreth", "Pengolodh",
		"Quendi", "Rumil", "Saeros", "Thingol", "Uinen", "Vaire", "Wen", "Xenophanes",
		"Yavanna", "Zephyr", "Aredhel", "Belegund", "Curufin", "Dior", "Elenwe", "Finduilas"
	],
	"orc": [
		"Gundabad", "Grishnak", "Ugluk", "Lurtz", "Gothmog", "Shagrat", "Gorbag",
		"Grishnakh", "Azog", "Bolg", "Gorbag", "Grishnak", "Ugluk", "Lurtz",
		"Gothmog", "Shagrat", "Gorbag", "Grishnakh", "Ugluk", "Lurtz", "Gothmog",
		"Shagrat", "Gorbag", "Grishnak", "Azog", "Bolg", "Gundabad", "Grishnak",
		"Ugluk", "Lurtz", "Gothmog", "Shagrat", "Gorbag", "Grishnakh", "Ugluk",
		"Bolg", "Azog", "Gundabad", "Grishnak", "Ugluk", "Lurtz", "Gothmog",
		"Shagrat", "Gorbag", "Grishnakh", "Ugluk", "Bolg", "Azog", "Gundabad",
		"Grishnak", "Ugluk", "Lurtz", "Gothmog", "Shagrat", "Gorbag", "Grishnakh",
		"Ugluk", "Bolg", "Azog", "Gundabad", "Grishnak", "Ugluk", "Lurtz", "Gothmog",
		"Shagrat", "Gorbag", "Grishnakh", "Ugluk", "Bolg", "Azog", "Gundabad", "Grishnak"
	]
}

func _ready():
	_load_available_options()
	_populate_ui()
	_connect_ui_signals()

## Load all available races and classes from resources
func _load_available_options():
	# Load races
	available_races = [
		preload("res://resources/races/human.tres"),
		preload("res://resources/races/dwarf.tres"),
		preload("res://resources/races/hobbit.tres"),
		preload("res://resources/races/elf.tres"),
		preload("res://resources/races/orc.tres")
	]
	
	# Load classes
	available_classes = [
		preload("res://resources/classes/hunter.tres"),
		preload("res://resources/classes/champion.tres"),
		preload("res://resources/classes/rogue.tres"),
		preload("res://resources/classes/warden.tres"),
		preload("res://resources/classes/cleric.tres"),
		preload("res://resources/classes/zealot.tres"),
		preload("res://resources/classes/warlock.tres"),
		preload("res://resources/classes/wizard.tres"),
		preload("res://resources/classes/philosopher.tres")
	]

## Populate UI dropdowns with available options
func _populate_ui():
	if race_option_button:
		race_option_button.clear()
		race_option_button.add_item("Select Race...")
		for race in available_races:
			race_option_button.add_item(race.race_name)
	
	if class_option_button:
		class_option_button.clear()
		class_option_button.add_item("Select Class...")
		for class_resource in available_classes:
			class_option_button.add_item(class_resource.name)

## Connect UI signals to handlers
func _connect_ui_signals():
	if name_input:
		name_input.text_changed.connect(_on_name_changed)
	
	if race_option_button:
		race_option_button.item_selected.connect(_on_race_selected)
	
	if class_option_button:
		class_option_button.item_selected.connect(_on_class_selected)

## UI signal handlers
func _on_name_changed(new_text: String):
	character_name = new_text
	character_data_changed.emit(self)

func _on_race_selected(index: int):
	if index > 0 and index - 1 < available_races.size():
		selected_race = available_races[index - 1]
	else:
		selected_race = null
	character_data_changed.emit(self)

func _on_class_selected(index: int):
	if index > 0 and index - 1 < available_classes.size():
		selected_class = available_classes[index - 1]
	else:
		selected_class = null
	character_data_changed.emit(self)

## Create a PartyMember resource from this character's data
func create_party_member() -> PartyMember:
	if not selected_race or not selected_class or character_name.is_empty():
		return null
	
	var member = PartyMember.new()
	member.member_name = character_name
	member.race = selected_race
	member.class_resource = selected_class
	return member

## Check if this character is complete (has name, race, and class)
func is_complete() -> bool:
	return selected_race != null and selected_class != null and not character_name.is_empty()

## Randomize this character with random race, class, and name
func randomize_character():
	# Random race
	if available_races.size() > 0:
		selected_race = available_races[randi() % available_races.size()]
		if race_option_button:
			var race_index = available_races.find(selected_race) + 1  # +1 for "Select Race..." option
			race_option_button.selected = race_index
	
	# Random class
	if available_classes.size() > 0:
		selected_class = available_classes[randi() % available_classes.size()]
		if class_option_button:
			var class_index = available_classes.find(selected_class) + 1  # +1 for "Select Class..." option
			class_option_button.selected = class_index
	
	# Random name based on race
	if selected_race:
		var race_key = selected_race.race_name.to_lower()
		if race_names.has(race_key) and race_names[race_key].size() > 0:
			character_name = race_names[race_key][randi() % race_names[race_key].size()]
			if name_input:
				name_input.text = character_name
	
	character_data_changed.emit(self)
