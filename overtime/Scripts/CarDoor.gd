## OverTime Production
## Last upadated 11/16/25 by Justin Ferreira
## CarDoor Script
## - The CarDoor script controls the interaction
## between the player and the door controling
## its anmations and sounds. 
## Also controling if the player is in the car or not 

extends Interactable

var unlocked = false
var player 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AnimationManager.CarAnimationPlayer = $"../../AnimationPlayer"
	AnimationManager.DoorFlashAnimationPlayer = $"../../DoorFlashAnimationPlayer"
	
	AnimationManager.DoorFlash = $CarDoorVisual
	AnimationManager.CarInteractRay = $"../../Head/Car_Cam/InteractRay"
	AnimationManager.CarHead = $"../../Head"
	CameraManager.CarCamera = $"../../Head/Car_Cam"
	
	AnimationManager.ActivateCarAnimationPlayer()
	AnimationManager.ActivateDoorFlashAnimationPlayer()
	
	AnimationManager.DoorFlashAnimationPlayer.play("DoorFlash")
	AnimationManager.DoorFlash.visible = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

## _on_animation_finished
## this function is called anytime an
## animation is fished so it can process
## what happens after the animation
func _on_animation_finished(anim_name: String):
	pass
	
	


func _on_interacted(body: Variant) -> void:
	player = PlayerManager.player
	AnimationManager.HoodFlash.visible = false
	AnimationManager.DoorFlash.visible = false
	AnimationManager.SteeringWheelFlash.visible = false
	##Entering car if locked
	if unlocked == false:
		if PlayerManager.has_item("Car Keys") && unlocked == false:
			AudioManager.play_sound(AudioManager.CarDoorOpen)
			player.interact_ray.enabled = false
			player.AREA3D.monitoring = false
			player.AREA3D.monitorable = false
			player.COLLISIONSHAPE3D.disabled = true
			player.gravity = false
			# First time opening car
			AnimationManager.CarEntering = true
			unlocked = true
			# Open door animation
			AnimationManager.CarAnimationPlayer.play("NoExitProps")
			PlayerManager.InAnimation = true
			PlayerManager.teleportEnemy = true
		else:
			# Play Car locked noise
			AudioManager.play_sound(AudioManager.CarDoorLocked)
			PlayerManager.CharacterDialog("Where did I leave my keys?")
			pass
	##Exiting car
	elif player.Incar == true:
		AnimationManager.CarEntering = false
		player.interact_ray.enabled = false
		AnimationManager.CarAnimationPlayer.play("NoExitProps")
		AudioManager.play_sound(AudioManager.CarDoorOpen)
	##Entering Car after Unlocked
	elif player.Incar == false && unlocked == true:
		AudioManager.play_sound(AudioManager.CarDoorOpen)
		PlayerManager.InAnimation = true
		AnimationManager.CarEntering = true
		AnimationManager.CarAnimationPlayer.play("NoExitProps")
		PlayerManager.teleportEnemy = true
