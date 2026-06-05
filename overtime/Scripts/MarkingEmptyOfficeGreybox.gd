extends Node3D

@export var lights: Array[Node]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerManager.OfficeLights = lights
