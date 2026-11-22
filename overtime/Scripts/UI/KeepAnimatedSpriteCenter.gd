## No Exit
## Overtime Studios
## Keep Sprite Centered
## - Keeps a Sprite2D in the middle of the screen, also after the window is
##   resized.

extends Sprite2D

func _ready() -> void:
	_center_sprite()
	get_tree().root.size_changed.connect(_center_sprite)

func _center_sprite() -> void:
	position = get_viewport().get_visible_rect().size / 2
