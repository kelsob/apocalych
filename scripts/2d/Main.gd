extends Control

## Main game manager - handles overall game state, menus, and coordination
## Central script for game-wide logic

@onready var map_generator: MapGenerator2D = $MapGenerator

# Game state
var game_started: bool = false

func _ready():
	# Connect to map generator signals
	if map_generator:
		map_generator.map_generation_complete.connect(_on_map_generation_complete)

## Called when map generation is complete
func _on_map_generation_complete():
	print("Main: Map generation complete, starting game...")
	start_game()

## Start the game - enables player interaction and begins gameplay loop
func start_game():
	if game_started:
		print("Main: Game already started")
		return
	
	game_started = true
	print("=== Game Started ===")
	print("Party can now navigate the map by clicking on connected nodes")
