extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#Play Open Animation and on Animation finish Move door Collision
	$ElevatorCollisions/DoorCollision.translate(Vector3(0,3,0))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
