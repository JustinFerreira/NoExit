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

var GasIntakeFlashAnimationPlayer
var WirePositiveFlashAnimationPlayer
var WireNegativeFlashAnimationPlayer
var PositiveBatteryFlashAnimationPlayer
var NegativeBatteryFlashAnimationPlayer
var ElevatorDoorButtonAnimationPlayer
var ElevatorPanelAnimationPlayer
var BoxFlashAnimationPlayer
var PictureFrame1FlashAnimationPlayer
var StickyNotesFlashAnimationPlayer
var Mug1AFlashAnimationPlayer
var Mug2AFlashAnimationPlayer
var CarKeysFlashAnimationPlayer
var BatteryFlashAnimationPlayer
var GasCanisterFlashAnimationPlayer
var CubicleFlashAnimationPlayer


var GasCapAnimationPlayer
var HoodAnimationPlayer

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

# Car Collisions
var HoodCollision 
var CarCollision

## Office
var ElevatorButtonFlash
var ElevatorPanelFlash
var BoxFlash


## Car player nodes

var CarInteractRay
var CarHead

## variables for pocesssing

var CarEntering = true


var PositiveConnection
var NegativeConnection

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

## ActivateMouseClickingAnimationPlayer
## This function connections the animation player for the mouse clicking 
## to the animation finished function for this specific animation
func ActivateMouseClickingAnimationPlayer():
	MouseClickingAnimationPlayer.connect("animation_finished", _on_MouseClicking_animation_finished)


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

## ActivateHoodFlashAnimationPlayer
## This function connections the animation player for the Hood flash  
## to the animation finished function for this specific animation
func ActivateHoodAnimationPlayer():
	HoodAnimationPlayer.connect("animation_finished", _on_Hood_animation_finished)

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
	## Car Door opening and Closing animation
	## Animation of player getting in the Car
	if anim_name == "GettinginCar" && not PlayerManager.player.Incar && CarEntering:
		AudioManager.play_sound(AudioManager.CarDoorClose)
		PlayerManager.InAnimation = false
			
		PlayerManager.player.Incar = true
		#GetInCarAnimationPlayer.play_backwards("NoExitProps")
		PlayerManager.player.interact_ray.enabled = true
		DoorFlash.start_flashing()
		SteeringWheelFlash.start_flashing()
		if PlayerManager.minigameOnePassed && PlayerManager.minigameTwoPassed && PlayerManager.minigameThreePassed:
			SteeringWheelFlash.start_flashing()
			
			DoorFlash.stop_flashing()
			
			SteeringWheelFlash.start_flashing()
			
			pass
		if !PlayerManager.minigameOnePassed && !PlayerManager.Loop0:
			SteeringWheelFlash.start_flashing()
			
			DoorFlash.stop_flashing()
			
			SteeringWheelFlash.start_flashing()
			
			pass
			PlayerManager.CharacterDialog(EventManager.hotwire_reminder)
		if PlayerManager.Loop0:
			
			SteeringWheelFlash.start_flashing()
			
			DoorFlash.stop_flashing()
			
			SteeringWheelFlash.start_flashing()
			
			PlayerManager.CharacterDialog(EventManager.loop0_get_in_car)
	## Exiting car animations
	if anim_name == "GettinginCar" && PlayerManager.player.Incar && not CarEntering:
		AudioManager.play_sound(AudioManager.CarDoorClose)
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
		PlayerManager.player.interact_ray.enabled = true
		
		SteeringWheelFlash.stop_flashing()
		
		if not PlayerManager.Loop0 and not PlayerManager.minigameOnePassed or (PlayerManager.minigameOnePassed and PlayerManager.minigameTwoPassed and PlayerManager.minigameThreePassed):
			
			DoorFlash.start_flashing()
			
			pass
		if not PlayerManager.minigameThreePassed && PlayerManager.has_item("Battery"):
			
			HoodFlash.start_flashing()
			
			pass
		if not PlayerManager.minigameTwoPassed && PlayerManager.has_item("Gas Canister"):
			
			GasIntakeFlash.start_flashing()
			
			pass
		if PlayerManager.Loop0:
			
			HoodFlash.start_flashing()
			
			pass
		
		
		# Teleport player 5 meters next to the car
		#PlayerManager.player.global_position = DoorFlash.global_position + Vector3(5, 0, 0)

## _on_HoodFlash_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_Hood_animation_finished(anim_name: String):
	if anim_name == "Hood":
		if not PlayerManager.minigameThreePassed and not PlayerManager.Loop0:
			PlayerManager.Battery.visible = true
			PlayerManager.NegativeWire.visible = true
			PlayerManager.PositiveWire.visible = true
			HoodAnimationPlayer.play("ZoomInbattery")

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

## _on_MouseClicking_animation_finished
## This function takes in a parameter that is a string which is the name of the aniamtion
## when this function is called at the end of an animation it restarts that same animation
func _on_MouseClicking_animation_finished(anim_name: String):
	if anim_name == "MouseClicking":
		MouseClickingAnimationPlayer.play("MouseClicking")


		
