extends Node3D

@export var lights: Array[Node]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerManager.ParkingGarageLights = get_tree().get_nodes_in_group("Lights")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
