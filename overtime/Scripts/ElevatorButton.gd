## OverTime Production
## Last upadated 11/16/25 by Justin Ferreira
## ElevatorButton Script
## - This script is for the button outside of the elevator
## it opens the doors for the elevator and during Loop1
## give a hint for tutorial

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
	AudioManager.play_sound(AudioManager.ElevatorDing)
	AudioManager.play_sound(AudioManager.ElevatorOpenDoor)
	if PlayerManager.Loop1:
		PlayerManager.Hint("Use shift to toggle sprint, 
Hold E to access your Inventory")
	DoorOpen = true;
	$".".is_interactable = false
	prompt_message = ""
	animation_player.play("Take 001")
	
