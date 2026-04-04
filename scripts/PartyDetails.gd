extends VBoxContainer

@onready var character_details_1: Control = $CharacterDetails
@onready var character_details_2: Control = $CharacterDetails2
@onready var character_details_3: Control = $CharacterDetails3

func _ready() -> void:
	visible = false

func initialize_party(members: Array[HeroCharacter]) -> void:
	character_details_1.set_member(members[0] if members.size() > 0 else null)
	character_details_2.set_member(members[1] if members.size() > 1 else null)
	character_details_3.set_member(members[2] if members.size() > 2 else null)
	visible = true

func refresh_xp() -> void:
	for cd in [character_details_1, character_details_2, character_details_3]:
		if cd and cd.has_method("refresh_xp"):
			cd.refresh_xp()

func enter_potion_target_mode() -> void:
	for cd in [character_details_1, character_details_2, character_details_3]:
		if cd and cd.has_method("set_highlight") and cd.has_method("needs_healing") and cd.needs_healing():
			cd.set_highlight(true)
		elif cd and cd.has_method("set_highlight"):
			cd.set_highlight(false)

func exit_potion_target_mode() -> void:
	for cd in [character_details_1, character_details_2, character_details_3]:
		if cd and cd.has_method("set_highlight"):
			cd.set_highlight(false)
