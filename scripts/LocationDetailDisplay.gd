extends Control


@onready var biome_label:Label = $MarginContainer/MarginContainer/VBoxContainer/BiomeLabel
@onready var distance_label:Label = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer/DistanceLabel
@onready var visited_label:Label = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer2/VisitedLabel

func _ready():
	visible = false

func location_hovered(location):
	# Display biome name with "town" suffix if applicable
	var biome_text = location.biome
	if location.get("is_town", false):
		biome_text += " Town"
	biome_label.text = biome_text
	
	distance_label.text = str(location.steps)
	visited_label.text = str(location.visited)
	
	visible = true
