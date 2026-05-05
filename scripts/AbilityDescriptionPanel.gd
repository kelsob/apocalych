extends PanelContainer
@onready var description_label: RichTextLabel = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var ap_cost_label: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer2/ApCostLabel
@onready var targeting_type_label: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer2/TargetingTypeLabel
@onready var range_label: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer/RangeLabel
@onready var type_label: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer/TypeLabel
@onready var mechanics_label: RichTextLabel = $MarginContainer/VBoxContainer/MechanicsLabel
@onready var once_per_turn_label: RichTextLabel = $MarginContainer/VBoxContainer/OncePerTurnLabel


func _ready() -> void:
	clear_display()


func clear_display() -> void:
	description_label.text = ""
	ap_cost_label.text = ""
	targeting_type_label.text = ""
	range_label.text = ""
	type_label.text = ""
	mechanics_label.text = ""
	once_per_turn_label.text = ""


func show_ability(ability: Ability) -> void:
	if ability == null:
		clear_display()
		return
	var flavor_text := ability.description.strip_edges()
	if flavor_text.is_empty():
		flavor_text = ability.get_player_facing_description()
	description_label.text = flavor_text
	ap_cost_label.text = "%d AP" % ability.get_modified_ap_cost()
	targeting_type_label.text = _targeting_to_text(ability.targeting_type)
	range_label.text = _range_to_text(ability.attack_range)
	type_label.text = _damage_kind_to_text(ability.get_resolved_primary_damage_kind())
	mechanics_label.text = ability.get_player_facing_description()
	if ability.is_basic_attack:
		once_per_turn_label.text = "Usable once per turn."
	else:
		once_per_turn_label.text = "Usable multiple times per turn."


func _targeting_to_text(targeting: int) -> String:
	match targeting:
		Ability.TargetingType.SELF:
			return "Self"
		Ability.TargetingType.SINGLE_ALLY:
			return "Single Ally"
		Ability.TargetingType.SINGLE_ENEMY:
			return "Single Enemy"
		Ability.TargetingType.ALL_ALLIES:
			return "All Allies"
		Ability.TargetingType.ALL_ENEMIES:
			return "All Enemies"
		Ability.TargetingType.ALL_COMBATANTS:
			return "All Combatants"
		Ability.TargetingType.RANDOM_ENEMY:
			return "Random Enemy"
		Ability.TargetingType.RANDOM_ALLY:
			return "Random Ally"
	return "Target"


func _range_to_text(profile: int) -> String:
	match profile:
		Ability.AttackRangeProfile.MELEE:
			return "Melee"
		Ability.AttackRangeProfile.RANGED:
			return "Ranged"
	return "Range"


func _damage_kind_to_text(kind: int) -> String:
	match kind:
		CombatDamageKind.Kind.PHYSICAL:
			return "Physical"
		CombatDamageKind.Kind.MAGICAL:
			return "Magical"
		CombatDamageKind.Kind.TRUE:
			return "True"
	return "Utility"
