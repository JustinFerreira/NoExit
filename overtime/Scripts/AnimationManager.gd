## No Exit
## Overtime Studios
## Last upadated 1/15/26 by Justin Ferreira
## AnimationManager Script
## - This is a manager script which allows for all
## animations to be held in the same place so they have
## easier access in other scripts and to themselves

extends Node

## Animation Players

# The Animation Player attached to the opening cutscne
var OpeningCutSceneAnimationPlayer 

# The Animation Player attached to the car
var GetInCarAnimationPlayer

# The Animation Player for clicking the mouse player helper
var MouseClickingAnimationPlayer

## Flashing Animation Players

var DoorFlashAnimationPlayer
var HoodFlashAnimationPlayer
var SteeringWheelFlashAnimationPlayer
var GasIntakeFlashAnimationPlayer
var WirePositiveFlashAnimationPlayer
var WireNegativeFlashAnimationPlayer
var PositiveBatteryFlashAnimationPlayer
var NegativeBatteryFlashAnimationPlayer
var ElevatorDoorButtonAnimationPlayer
var ElevatorPanelAnimationPlayer
var BoxFlashAnimationPlayer
var PictureFrame1FlashAnimationPlayer
var StaplerFlashAnimationPlayer
var StickyNotesFlashAnimationPlayer
var Mug1AFlashAnimationPlayer
var Mug2AFlashAnimationPlayer
var CarKeysFlashAnimationPlayer
var BatteryFlashAnimationPlayer
var GasCanisterFlashAnimationPlayer
var CubicleFlashAnimationPlayer

## Meshes to toggle visiblity

# Car
var SteeringWheelFlash
var DoorFlash
var HoodFlash
var GasIntakeFlash
var WirePositiveFlash
var WireNegativeFlash
var PositiveBatteryFlash
var NegativeBatteryFlash

## Office
var ElevatorButtonFlash
var ElevatorPanelFlash
var BoxFlash


## Car player nodes

var CarInteractRay
var CarHead

## variables for pocesssing

var CarEntering = true


## Reset Zones

var ResetZones: Array = []

var NegativeBatteryResetZone

var PositiveBatteryResetZone

## Elevator

var DoorOpen = false
var DoorClosed = false
var ElevatorFall = false




# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
	
	
## Reset Zone Functions

## RevealResetZones
## This takes in a parameter which represents the wire that the player is currently holding
## according to the wire the player is holding this function will show the reset zones related to this wire
func RevealResetZones(wire):
	if wire == PlayerManager.PositiveWire:
		for RestZone in ResetZones:
			RestZone.visible = true
		NegativeBatteryResetZone.visible = true
	if wire == PlayerManager.NegativeWire:
		for RestZone in ResetZones:
			RestZone.visible = true
		PositiveBatteryResetZone.visible = true

## HideResetZones
## Hides all reset zones
func HideResetZones():
	for RestZone in ResetZones:
		RestZone.visible = false
	NegativeBatteryResetZone.visible = false
	PositiveBatteryResetZone.visible = false




## Activation functions

## ExaminItemActivation
## This function takes in a string which tells the fucntion the next function to call
## There are mutiple examin items that use this function to activate their flash animation 
func ExaminItemActivation(anim_string: String):
	if anim_string == "PictureFrame1Flash":
		ActivatePictureFrame1AnimationPlayer()
	if anim_string == "StaplerFlash":
		ActivateStaplerFlashAnimationPlayer()
	if anim_string == "StickyNotesFlash":
		ActivateStickyNotesFlashAnimationPlayer()
	if anim_string == "Mug1AFlash":
		ActivateMug1AFlashAnimationPlayer()
	if anim_string == "Mug2AFlash":
		ActivateMug2AFlashAnimationPlayer()

## ActivateCubicleFlashAnimationPlayer
## This function connections the animation player for the player cubicle flash  
## to the animation finished function for this specific animation
func ActivateCubicleFlashAnimationPlayer():
	CubicleFlashAnimationPlayer.connect("animation_finished", _on_CubicleFlash_animation_finished)

## ActivateMouseClickingAnimationPlayer
## This function connections the animation player for the mouse clicking 
## to the animation finished function for this specific animation
func ActivateMouseClickingAnimationPlayer():
	MouseClickingAnimationPlayer.connect("animation_finished", _on_MouseClicking_animation_finished)

## ActivateGasCanisterFlashAnimationPlayer
## This function connections the animation player for the pick up canister flash  
## to the animation finished function for this specific animation
func ActivateGasCanisterFlashAnimationPlayer():
	GasCanisterFlashAnimationPlayer.connect("animation_finished", _on_GasCanisterFlash_animation_finished)

## ActivateBatteryFlashAnimationPlayer
## This function connections the animation player for the pick up battery flash  
## to the animation finished function for this specific animation
func ActivateBatteryFlashAnimationPlayer():
	BatteryFlashAnimationPlayer.connect("animation_finished", _on_BatteryFlash_animation_finished)

## ActivateCarKeysFlashAnimationPlayer
## This function connections the animation player for the pikc up car keys flash  
## to the animation finished function for this specific animation
func ActivateCarKeysFlashAnimationPlayer():
	CarKeysFlashAnimationPlayer.connect("animation_finished", _on_CarKeysFlash_animation_finished)

## ActivateMug2AFlashAnimationPlayer
## This function connections the animation player for the Mug2A flash  
## to the animation finished function for this specific animation
func ActivateMug2AFlashAnimationPlayer():
	Mug2AFlashAnimationPlayer.connect("animation_finished", _on_Mug2AFlash_animation_finished)

## ActivateMug1AFlashAnimationPlayer
## This function connections the animation player for the Mug1A flash  
## to the animation finished function for this specific animation
func ActivateMug1AFlashAnimationPlayer():
	Mug1AFlashAnimationPlayer.connect("animation_finished", _on_Mug1AFlash_animation_finished)
	
## ActivateStickyNotesFlashAnimationPlayer
## This function connections the animation player for the sticky notes flash  
## to the animation finished function for this specific animation
func ActivateStickyNotesFlashAnimationPlayer():
	StickyNotesFlashAnimationPlayer.connect("animation_finished", _on_StickyNotesFlash_animation_finished)
	
## ActivateStaplerFlashAnimationPlayer
## This function connections the animation player for the stapler flash  
## to the animation finished function for this specific animation
func ActivateStaplerFlashAnimationPlayer():
	StaplerFlashAnimationPlayer.connect("animation_finished", _on_StaplerFlash_animation_finished)

## ActivatePictureFrame1AnimationPlayer
## This function connections the animation player for the picture frame 1 flash  
## to the animation finished function for this specific animation
func ActivatePictureFrame1AnimationPlayer():
	PictureFrame1FlashAnimationPlayer.connect("animation_finished", _on_PictureFrame1Flash_animation_finished)

## ActivateBoxFlashAnimationPlayer
## This function connections the animation player for the box flash  
## to the animation finished function for this specific animation
func ActivateBoxFlashAnimationPlayer():
	BoxFlashAnimationPlayer.connect("animation_finished", _on_BoxFlash_animation_finished)


## ActivateElevatorPanelFlashAnimationPlayer
## This function connections the animation player for the elevator panel flash  
## to the animation finished function for this specific animation
func ActivateElevatorPanelFlashAnimationPlayer():
	ElevatorPanelAnimationPlayer.connect("animation_finished", _on_ElevatorPanelFlash_animation_finished)
	
## ActivateElevatorButtonAnimationPlayer
## This function connections the animation player for the elevator button flash
## to the animation finished function for this specific animation
func ActivateElevatorButtonAnimationPlayer():
	ElevatorDoorButtonAnimationPlayer.connect("animation_finished", _on_ElevatorButtonFlash_animation_finished)

## ActivatePositiveBatteryFlashAnimationPlayer
## This function connections the animation player for the positive battery flash  
## to the animation finished function for this specific animation
func ActivatePositiveBatteryFlashAnimationPlayer():
	PositiveBatteryFlashAnimationPlayer.connect("animation_finished", _on_PositiveBatteryFlash_animation_finished)
	
## ActivateNegativeBatteryFlashAnimationPlayer
## This function connections the animation player for the negative battery flash  
## to the animation finished function for this specific animation
func ActivateNegativeBatteryFlashAnimationPlayer():
	NegativeBatteryFlashAnimationPlayer.connect("animation_finished", _on_NegativeBatteryFlash_animation_finished)

## ActivateWireNegativeFlashAnimationPlayer
## This function connections the animation player for the wire negative flash  
## to the animation finished function for this specific animation
func ActivateWireNegativeFlashAnimationPlayer():
	WireNegativeFlashAnimationPlayer.connect("animation_finished", _on_WireNegativeFlash_animation_finished)

## ActivateWirePositiveFlashAnimationPlayer
## This function connections the animation player for the wire positive flash  
## to the animation finished function for this specific animation
func ActivateWirePositiveFlashAnimationPlayer():
	WirePositiveFlashAnimationPlayer.connect("animation_finished", _on_WirePositiveFlash_animation_finished)

## ActivateGasIntakeFlashAnimationPlayer
## This function connections the animation player for the gas intake flash  
## to the animation finished function for this specific animation
func ActivateGasIntakeFlashAnimationPlayer():
	GasIntakeFlashAnimationPlayer.connect("animation_finished", _on_GasIntakeFlash_animation_finished)

## ActivateSteeringWheelFlashAnimationPlayer
## This function connections the animation player for the steering wheel flash  
## to the animation finished function for this specific animation
func ActivateSteeringWheelFlashAnimationPlayer():
	SteeringWheelFlashAnimationPlayer.connect("animation_finished", _on_SteeringWheelFlash_animation_finished)

## ActivateHoodFlashAnimationPlayer
## This function connections the animation player for the Hood flash  
## to the animation finished function for this specific animation
func ActivateHoodFlashAnimationPlayer():
	HoodFlashAnimationPlayer.connect("animation_finished", _on_HoodFlash_animation_finished)

## ActivateDoorFlashAnimationPlayer
## This function connections the animation player for the car door flash  
## to the animation finished function for this specific animation
func ActivateDoorFlashAnimationPlayer():
	DoorFlashAnimationPlayer.connect("animation_finished", _on_DoorFlash_animation_finished)

## ActivateCarAnimationPlayer
## This function connections the animation player for the car flash  
## to the animation finished function for this specific animation
func ActivateGetInCarAnimationPlayer():
	GetInCarAnimationPlayer.connect("animation_finished", _on_GetInCar_animation_finished)


## On Animation Finished Functions

## _on_GetInCar_animation_finished
## This aniamtion player takes in a string which is the animation that just happened
## depending on the animation that finsihed and its state there are different 
## things that follow that animation
func _on_GetInCar_animation_finished(anim_name: String):
	#print("Animation Finished: ", anim_name)
	## Car Door opening and Closing animation
	if anim_name == "NoExitProps":
		## checks if this is the first frame of animation to play sound at correct time  
		if GetInCarAnimationPlayer.current_animation_position == 0.0:
			AudioManager.play_sound(AudioManager.CarDoorClose)
		## checks to see if the player is trying to enter the car
		if not PlayerManager.player.Incar && CarEntering:
			PlayerManager.InAnimation = false
			PlayerManager.player.head = CarHead
			PlayerManager.player.camera = CameraManager.CarCamera
			PlayerManager.player.interact_ray = CarInteractRay
			PlayerManager.player.interact_ray.enabled = false
			PlayerManager.player.TbobON = false
			CameraManager.CarCamera.current = true
			GetInCarAnimationPlayer.play("GettinginCar")
		## checks to see if player is trying to exit car
		if PlayerManager.player.Incar == true && not CarEntering:
			GetInCarAnimationPlayer.play_backwards("GettinginCar")
	## Animation of player getting in the Car
	if anim_name == "GettinginCar" && not PlayerManager.player.Incar && CarEntering:
		PlayerManager.player.Incar = true
		GetInCarAnimationPlayer.play_backwards("NoExitProps")
		PlayerManager.player.interact_ray.enabled = true
		DoorFlash.visible = true
		if PlayerManager.minigameOnePassed && PlayerManager.minigameTwoPassed && PlayerManager.minigameThreePassed:
			SteeringWheelFlash.visible = true
			DoorFlash.visible = false
			GetInCarAnimationPlayer.play("HotWireFlash")
		if !PlayerManager.minigameOnePassed && !PlayerManager.Loop0:
			SteeringWheelFlash.visible = true
			DoorFlash.visible = false
			GetInCarAnimationPlayer.play("HotWireFlash")
			PlayerManager.CharacterDialog(EventManager.hotwire_reminder)
		if PlayerManager.Loop0:
			SteeringWheelFlash.visible = true
			DoorFlash.visible = false
			GetInCarAnimationPlayer.play("HotWireFlash")
			PlayerManager.CharacterDialog(EventManager.loop0_get_in_car)
	## Exiting car animations
	if anim_name == "GettinginCar" && PlayerManager.player.Incar && not CarEntering:
		PlayerManager.player.Incar = false
		PlayerManager.player.TbobON = true
		PlayerManager.player.head = PlayerManager.player.HEAD
		PlayerManager.player.camera = PlayerManager.player.CAMERA
		PlayerManager.player.interact_ray = PlayerManager.player.INTERACT_RAY
		PlayerManager.player.interact_ray.enabled = false
		PlayerManager.player.CAMERA.current = true
		PlayerManager.player.AREA3D.monitoring = true
		PlayerManager.player.AREA3D.monitorable = true
		PlayerManager.player.COLLISIONSHAPE3D.disabled = false
		PlayerManager.player.gravity = true
		GetInCarAnimationPlayer.play_backwards("NoExitProps")
		PlayerManager.player.interact_ray.enabled = true
		SteeringWheelFlash.visible = false
		if not PlayerManager.Loop0 and not PlayerManager.minigameOnePassed or (PlayerManager.minigameOnePassed and PlayerManager.minigameTwoPassed and PlayerManager.minigameThreePassed):
			DoorFlash.visible = true
		if not PlayerManager.minigameThreePassed && PlayerManager.has_item("Battery"):
			AnimationManager.HoodFlash.visible = true
		if not PlayerManager.minigameTwoPassed && PlayerManager.has_item("Gas Canister"):
			GasIntakeFlash.visible = true
		if PlayerManager.Loop0:
			HoodFlash.visible = true
		
		
		# Teleport player 5 meters next to the car
		PlayerManager.player.global_position = DoorFlash.global_position + Vector3(5, 0, 0)


## _on_DoorFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_DoorFlash_animation_finished(anim_name: String):
	if anim_name == "DoorFlash":
		DoorFlashAnimationPlayer.play("DoorFlash")

## _on_HoodFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_HoodFlash_animation_finished(anim_name: String):
	if anim_name == "HoodFlash":
		HoodFlashAnimationPlayer.play("HoodFlash")

## _on_SteeringWheelFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_SteeringWheelFlash_animation_finished(anim_name: String):
	if anim_name == "SteeringWheelFlash":
		SteeringWheelFlashAnimationPlayer.play("SteeringWheelFlash")

##  _on_GasIntakeFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_GasIntakeFlash_animation_finished(anim_name: String):
	if anim_name == "GasIntakeFlash":
		GasIntakeFlashAnimationPlayer.play("GasIntakeFlash")

## _on_WirePositiveFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_WirePositiveFlash_animation_finished(anim_name: String):
	if anim_name == "WirePositiveFlash":
		WirePositiveFlashAnimationPlayer.play("WirePositiveFlash")

## _on_WireNegativeFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_WireNegativeFlash_animation_finished(anim_name: String):
	if anim_name == "WireNegativeFlash":
		WireNegativeFlashAnimationPlayer.play("WireNegativeFlash")

## _on_PositiveBatteryFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_PositiveBatteryFlash_animation_finished(anim_name: String):
	if anim_name == "PositiveBatteryFlash":
		PositiveBatteryFlashAnimationPlayer.play("PositiveBatteryFlash")

## _on_NegativeBatteryFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_NegativeBatteryFlash_animation_finished(anim_name: String):
	if anim_name == "NegativeBatteryFlash":
		NegativeBatteryFlashAnimationPlayer.play("NegativeBatteryFlash")

## _on_ElevatorButtonFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_ElevatorButtonFlash_animation_finished(anim_name: String):
	if anim_name == "OutlinePulse":
		ElevatorDoorButtonAnimationPlayer.play("OutlinePulse")
	if anim_name == "Take 001" && !DoorOpen:
		DoorOpen = true
	if anim_name == "Take 001" && DoorClosed:
		ElevatorFall = true
		AudioManager.play_sound(AudioManager.elevator_whitenoise)

## _on_ElevatorPanelFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func  _on_ElevatorPanelFlash_animation_finished(anim_name: String):
	if anim_name == "ElevatorPanelFlash":
		ElevatorPanelAnimationPlayer.play("ElevatorPanelFlash")

## _on_BoxFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_BoxFlash_animation_finished(anim_name: String):
	if anim_name == "BoxFlash":
		BoxFlashAnimationPlayer.play("BoxFlash")

## _on_PictureFrame1Flash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_PictureFrame1Flash_animation_finished(anim_name: String):
	if anim_name == "PictureFrame1Flash":
		PictureFrame1FlashAnimationPlayer.play("PictureFrame1Flash")

## _on_StaplerFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_StaplerFlash_animation_finished(anim_name: String):
	if anim_name == "StaplerFlash":
		StaplerFlashAnimationPlayer.play("StaplerFlash")

## _on_StickyNotesFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_StickyNotesFlash_animation_finished(anim_name: String):
	if anim_name == "StickyNotesFlash":
		StickyNotesFlashAnimationPlayer.play("StickyNotesFlash")

## _on_Mug1AFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_Mug1AFlash_animation_finished(anim_name: String):
	if anim_name == "Mug1AFlash":
		Mug1AFlashAnimationPlayer.play("Mug1AFlash")

## _on_Mug2AFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_Mug2AFlash_animation_finished(anim_name: String):
	if anim_name == "Mug2AFlash":
		Mug2AFlashAnimationPlayer.play("Mug2AFlash")

## _on_CarKeysFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_CarKeysFlash_animation_finished(anim_name: String):
	if anim_name == "CarKeysFlash":
		CarKeysFlashAnimationPlayer.play("CarKeysFlash")

## _on_BatteryFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_BatteryFlash_animation_finished(anim_name: String):
	if anim_name == "BatteryFlash":
		BatteryFlashAnimationPlayer.play("BatteryFlash")

## _on_GasCanisterFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_GasCanisterFlash_animation_finished(anim_name: String):
	if anim_name == "GasCanisterFlash":
		GasCanisterFlashAnimationPlayer.play("GasCanisterFlash")

## _on_MouseClicking_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_MouseClicking_animation_finished(anim_name: String):
	if anim_name == "MouseClicking":
		MouseClickingAnimationPlayer.play("MouseClicking")

## _on_CubicleFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_CubicleFlash_animation_finished(anim_name: String):
	if anim_name == "CubicleFlash":
		CubicleFlashAnimationPlayer.play("CubicleFlash")
