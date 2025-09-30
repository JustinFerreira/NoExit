extends Interactable

@onready var animation_player = $"../AnimationPlayer"
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
	
	if anim_name == "Take 001":
		door_collision.translate(Vector3(0,3,0))
		$".".is_interactable = false

func _on_interacted(body: Variant) -> void:
	animation_player.play("Take 001")
	
