extends Node3D

@onready var target = $Player


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	target.camera.current = true
	PlayerManager.Dialog("Damn what's wrong with this elevator? 
I guess I'll just walk down 2 floors.", 5)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	get_tree().call_group("enemy" , "target_position" , target.global_transform.origin)
