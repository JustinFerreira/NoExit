extends Interactable

@onready var animation_player = $"../AnimationPlayer"
@onready var door_collision = $"../ElevatorCollisions/DoorCollision"

var DoorOpen = false;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.connect("animation_finished", _on_animation_finished)
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_animation_finished(anim_name: String):
	#print("Animation", anim_name)
	
	if anim_name == "Take 001" && DoorOpen:
		DoorOpen = false;

func _on_interacted(body: Variant) -> void:
	door_collision.translate(Vector3(0,3,0))
	PlayerManager.Dialog("To run hold shift, to see what you have in your inventory press E or Tab")
	DoorOpen = true;
	$".".is_interactable = false
	prompt_message = ""
	animation_player.play("Take 001")
	
