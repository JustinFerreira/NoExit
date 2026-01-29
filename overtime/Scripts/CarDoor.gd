## No Exit
## Overtime Studios
## Last upadated 1/19/26 by Justin Ferreira
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
	super._ready()
	AnimationManager.DoorFlash = self
	#Should be fixed?
	if PlayerManager.Loop0:
		SettingsManager.KillerDisabled = true
	#animation players assocaited with car door
	AnimationManager.GetInCarAnimationPlayer = $"../../GetInCarAnimationPlayer"
	
	AnimationManager.ActivateGetInCarAnimationPlayer()
	
	AnimationManager.CarInteractRay = $"../../Head/Car_Cam/InteractRay"
	AnimationManager.CarHead = $"../../Head"
	CameraManager.CarCamera = $"../../Head/Car_Cam"
	
	if PlayerManager.OpeningCutscene:
		return
	else:
		start_flashing()

func _on_interacted(body: Variant) -> void:
	#(Event Manager function for car door interaction?)
	#turning off flash for car objects when car animation is about to start
	#AnimationManager.HoodFlash.visible = false
	#AnimationManager.DoorFlash.visible = false
	#AnimationManager.SteeringWheelFlash.visible = false
	#AnimationManager.GasIntakeFlash.visible = false
	
	
	#First time entering the car
	if unlocked == false:
		#check for keys? currently un-needed feature which is being talked about
		if PlayerManager.has_item("Car Keys") && unlocked == false:
			#car door open sound
			AudioManager.play_sound(AudioManager.CarDoorOpen)
			#switching off player interact ray, collision, and gravity
			
			#Event Manager?
			#Event Manager?
			# PlayerManager.turnoffplayer()
			PlayerManager.player.interact_ray.enabled = false
			PlayerManager.player.AREA3D.monitoring = false
			PlayerManager.player.AREA3D.monitorable = false
			PlayerManager.player.COLLISIONSHAPE3D.disabled = true
			PlayerManager.player.gravity = false
			#car entering turns on to show the direction of animation
			#unlocked is true for no real reason unless playyer can forget keys which is being talked about
			
			#Event Manager?
			#Event Manager?
			AnimationManager.CarEntering = true
			unlocked = true
			PlayerManager.player.head = $"../../Head"
			PlayerManager.player.camera = CameraManager.CarCamera
			PlayerManager.player.interact_ray = $"../../Head/Car_Cam/InteractRay"
			PlayerManager.player.interact_ray.enabled = false
			PlayerManager.player.TbobON = false
			CameraManager.CarCamera.current = true
			PlayerManager.InAnimation = true
			#open door animation
			AnimationManager.GetInCarAnimationPlayer.play("GettinginCar")
			
			#Event Manager?
			#Event Manager?
			#turn on teleport enemy to give player time in car so enemy isn't on their ass
			#Should be fixed?
			if not PlayerManager.Loop0:
				PlayerManager.teleportEnemy = true
		else:
			#doesnt happen ever
			#Play Car locked noise
			AudioManager.play_sound(AudioManager.CarDoorLocked)
			PlayerManager.CharacterDialog(EventManager.forgot_keys)
			pass
	#Exiting car
	elif PlayerManager.player.Incar == true:
		#car entering turns off to show the direction of animation
		AnimationManager.CarEntering = false
		#turn off player interact ray
		PlayerManager.player.interact_ray.enabled = false
		AnimationManager.GetInCarAnimationPlayer.play_backwards("GettinginCar")
		#car door open sound
		AudioManager.play_sound(AudioManager.CarDoorOpen)
	#Entering Car after Unlocked
	elif PlayerManager.player.Incar == false && unlocked == true:
		#car door open sound
		AudioManager.play_sound(AudioManager.CarDoorOpen)
		
		#Event Manager?
		#Event Manager?
		# PlayerManager.turnoffplayer()
		PlayerManager.player.interact_ray.enabled = false
		PlayerManager.player.AREA3D.monitoring = false
		PlayerManager.player.AREA3D.monitorable = false
		PlayerManager.player.COLLISIONSHAPE3D.disabled = true
		PlayerManager.player.gravity = false
		#car entering turns on to show the direction of animation
		#unlocked is true for no real reason unless playyer can forget keys which is being talked about
		
		#Event Manager?
		#Event Manager?
		AnimationManager.CarEntering = true
		unlocked = true
		PlayerManager.player.head = $"../../Head"
		PlayerManager.player.camera = CameraManager.CarCamera
		PlayerManager.player.interact_ray = $"../../Head/Car_Cam/InteractRay"
		PlayerManager.player.interact_ray.enabled = false
		PlayerManager.player.TbobON = false
		CameraManager.CarCamera.current = true
	
		PlayerManager.InAnimation = true
		#car entering turns on to show the direction of animation
		AnimationManager.CarEntering = true
		AnimationManager.GetInCarAnimationPlayer.play("GettinginCar")
		
		#Should be fixed?
		if not PlayerManager.Loop0:
			PlayerManager.teleportEnemy = true
			
# Example usage in a script attached to a MeshInstance
