extends Control

@onready var sprite: Sprite2D = $Sprite2D

## Set the sprite texture
func set_sprite_texture(texture: Texture2D):
	sprite.texture = texture

## Set sprite modulation (for death/status effects)
func set_sprite_modulation(color: Color):
	sprite.modulate = color
