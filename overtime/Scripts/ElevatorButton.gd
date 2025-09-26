extends Interactable

@onready var animation_player
@onready var door_collision = $"../ElevatorCollisions/DoorCollision"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#animation_player.connect("animation_finished", _on_animation_finished)
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_animation_finished(anim_name: String):
	print("Animation", anim_name)
	
	if anim_name == "DoorClosed":
		door_collision.translate(Vector3(0,3,0))

func _on_interacted(body: Variant) -> void:
	print("Elevator Activated")
	door_collision.translate(Vector3(0,3,0))
	$".".queue_free()
