## OverTime Studios
## Last upadated 1/20/26 by Justin Ferreira
## ElevatorButton Script
## - This script is for the button outside of the elevator
## it opens the doors for the elevator and during Loop1
## give a hint for tutorial

extends Interactable

@onready var door_collision = $"../ElevatorCollisions/DoorCollision"

var DoorOpen = false;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AnimationManager.ElevatorDoorButtonAnimationPlayer = $"../ElevatorDoorButtonAnimationPlayer"
	AnimationManager.ElevatorButtonFlash = $"../ElevatorOutsideButtonFlash"
	AnimationManager.ActivateElevatorButtonAnimationPlayer()
	AnimationManager.ElevatorDoorButtonAnimationPlayer.play("OutlinePulse")
	if not PlayerManager.Loop0:
		AnimationManager.ElevatorButtonFlash.visible = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_interacted(body: Variant) -> void:
	if PlayerManager.has_item("Car Keys"):
		if not PlayerManager.talkToJanitor:
			PlayerManager.janitor.talkToPlayer()
			return
		AnimationManager.ElevatorButtonFlash.visible = false
		door_collision.translate(Vector3(0,3,0))
		AudioManager.play_sound(AudioManager.ElevatorDing)
		AudioManager.play_sound(AudioManager.ElevatorOpenDoor)
		if PlayerManager.Loop1:
			if PlayerManager.Hold_Shift:
				PlayerManager.Hint("Hold shift, to sprint")
			else:
				PlayerManager.Hint("Use shift to toggle sprint")
		$".".is_interactable = false
		prompt_message = ""
		AnimationManager.ElevatorDoorButtonAnimationPlayer.play("Take 001")
	else:
		PlayerManager.CharacterDialog("Wait, I think I forgot my keys at my cubicle. Definitely need to grab those before leaving this hell hole")
	
