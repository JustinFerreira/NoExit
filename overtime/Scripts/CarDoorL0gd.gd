extends Interactable

var unlocked = false
var player 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#Event or Loop Manager???
	PlayerManager.Loop0 = true
	SettingsManager.KillerDisabled = true
	######
	
	AnimationManager.GetInCarAnimationPlayer = $"../../GetInCarAnimationPlayer"
	AnimationManager.DoorFlashAnimationPlayer = $"../../DoorFlashAnimationPlayer"
	
	AnimationManager.DoorFlash = $CarDoorVisual
	AnimationManager.CarInteractRay = $"../../Head/Car_Cam/InteractRay"
	AnimationManager.CarHead = $"../../Head"
	CameraManager.CarCamera = $"../../Head/Car_Cam"
	
	AnimationManager.ActivateGetInCarAnimationPlayer()
	AnimationManager.ActivateDoorFlashAnimationPlayer()
	
	AnimationManager.DoorFlashAnimationPlayer.play("DoorFlash")
	AnimationManager.DoorFlash.visible = true

func _on_interacted(body: Variant) -> void:
	player = PlayerManager.player
	AnimationManager.DoorFlash.visible = false
	AnimationManager.SteeringWheelFlash.visible = false
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
			AnimationManager.GetInCarAnimationPlayer.play("NoExitProps")
			PlayerManager.InAnimation = true
		else:
			# Play Car locked noise
			AudioManager.play_sound(AudioManager.CarDoorLocked)
			PlayerManager.CharacterDialog(EventManager.forgot_keys)
			pass
	##Exiting car
	elif player.Incar == true:
		AnimationManager.CarEntering = false
		player.interact_ray.enabled = false
		AnimationManager.GetInCarAnimationPlayer.play("NoExitProps")
		AudioManager.play_sound(AudioManager.CarDoorOpen)
	##Entering Car after Unlocked
	elif player.Incar == false && unlocked == true:
		AudioManager.play_sound(AudioManager.CarDoorOpen)
		PlayerManager.InAnimation = true
		AnimationManager.CarEntering = true
		AnimationManager.GetInCarAnimationPlayer.play("NoExitProps")
