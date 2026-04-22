extends Node3D

@export var lights: Array[Node]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerManager.OfficeLights = lights


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
