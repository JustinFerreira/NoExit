## No Exit
## Overtime Studios
## Office Lights List
## - Put on the office level: hands its ceiling lights to PlayerManager
##   (OfficeLights) so the fire alarm and other events can switch them.

extends Node3D

## The office's light panels.
@export var lights: Array[Node]

func _ready() -> void:
	PlayerManager.OfficeLights = lights
