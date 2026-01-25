extends Resource
class_name Biome

## Biome resource - defines a biome type with visual and gameplay properties

@export var biome_name: String = ""
@export var display_name: String = ""  # Human-readable name for UI
@export var description: String = ""
@export var color: Color = Color.WHITE  # Visual color for map representation
@export var icon_name: String = ""  # Optional icon identifier for future use
