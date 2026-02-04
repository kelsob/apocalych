extends VBoxContainer

@onready var character_details_1: Control = $CharacterDetails
@onready var character_details_2: Control = $CharacterDetails2
@onready var character_details_3: Control = $CharacterDetails3

func initialize_party(members: Array[PartyMember]) -> void:
	character_details_1.set_member(members[0] if members.size() > 0 else null)
	character_details_2.set_member(members[1] if members.size() > 1 else null)
	character_details_3.set_member(members[2] if members.size() > 2 else null)
