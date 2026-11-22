## No Exit
## Overtime Studios
## Animation Manager (autoload "AnimationManager")
## - Holds the animation players, clickable parts and hint meshes of the car, the
##   battery minigame and the elevators, so the scripts that set them up and
##   the ones that trigger them can find each other, plus the handlers that
##   run when those animations finish. loop_animation() keeps a hint
##   animation looping.

extends Node

## Animation Players

## The Animation Player attached to the opening cutscene
var OpeningCutSceneAnimationPlayer: AnimationPlayer

## The Animation Player attached to the car
var GetInCarAnimationPlayer: AnimationPlayer
## The office elevator's outside button (outline pulse + door animation).
var ElevatorDoorButtonAnimationPlayer: AnimationPlayer
## Car gas cap and hood.
var GasCapAnimationPlayer: AnimationPlayer
var HoodAnimationPlayer: AnimationPlayer

## Meshes to toggle visiblity

## The car's clickable parts (each registers itself). They outline like
## everything else - steady when close, flashing when aimed at - these are
## just so other scripts can switch them on and off.
var SteeringWheelFlash: Interactable
var DoorFlash: Interactable
var HoodFlash: Interactable
var GasIntakeFlash: Interactable
var WirePositiveFlash: MeshInstance3D
var WireNegativeFlash: MeshInstance3D
var PositiveBatteryFlash: MeshInstance3D
var NegativeBatteryFlash: MeshInstance3D

## Car Collisions
var HoodCollision: CollisionShape3D
var CarCollision: CollisionShape3D


## Car player nodes

var CarInteractRay: RayCast3D
var CarHead: Node3D

## variables for pocesssing

var CarEntering: bool = true


var PositiveConnection: MeshInstance3D
var NegativeConnection: MeshInstance3D

## Reset Zones

var ResetZones: Array = []

var NegativeBatteryResetZone: MeshInstance3D

var PositiveBatteryResetZone: MeshInstance3D

## Elevator

var DoorOpen: bool = false
var DoorClosed: bool = false
var ElevatorFall: bool = false


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

## Keeps an animation looping by playing it again every time it finishes
## (the flashing hint animations aren't set to loop in their files) and
## starts it. Safe to call again for the same player and animation.
func loop_animation(player: AnimationPlayer, anim: String) -> void:
	if player == null:
		return
	var key := "_loop_" + anim
	if not player.has_meta(key):
		player.set_meta(key, true)
		player.animation_finished.connect(func(finished: StringName) -> void:
			if finished == anim and is_instance_valid(player):
				player.play(anim))
	player.play(anim)

## ActivateElevatorButtonAnimationPlayer
## This function connections the animation player for the elevator button flash
## to the animation finished function for this specific animation
func ActivateElevatorButtonAnimationPlayer():
	ElevatorDoorButtonAnimationPlayer.connect("animation_finished", _on_ElevatorButtonFlash_animation_finished)

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

## The car door animation finished: getting in hands control to the car
## (and flashes whatever is next), getting out gives the player back their
## body and flashes the next car task.
func _on_GetInCar_animation_finished(anim_name: String):
	## Car Door opening and Closing animation
	## Animation of player getting in the Car
	if anim_name == "GettinginCar" && not PlayerManager.player.Incar && CarEntering:
		UiManager.set_cursor_visible(true)
		AudioManager.play_sound(AudioManager.CarDoorClose)
		PlayerManager.InAnimation = false

		PlayerManager.player.Incar = true
		PlayerManager.player.interact_ray.enabled = true
		var hotwire_next: bool = not PlayerManager.minigameOnePassed and not PlayerManager.Loop0
		if hotwire_next:
			PlayerManager.CharacterDialog(EventManager.hotwire_reminder)
		if PlayerManager.Loop0:
			PlayerManager.CharacterDialog(EventManager.loop0_get_in_car)
	## Exiting car animations
	if anim_name == "GettinginCar" && PlayerManager.player.Incar && not CarEntering:
		UiManager.set_cursor_visible(true)
		AudioManager.play_sound(AudioManager.CarDoorClose)
		PlayerManager.player.Incar = false
		PlayerManager.player.TbobON = true
		PlayerManager.player.head = PlayerManager.player.HEAD
		PlayerManager.player.camera = PlayerManager.player.CAMERA
		PlayerManager.player.interact_ray = PlayerManager.player.INTERACT_RAY
		PlayerManager.player.CAMERA.current = true
		PlayerManager.player.AREA3D.monitoring = true
		PlayerManager.player.AREA3D.monitorable = true
		PlayerManager.player.COLLISIONSHAPE3D.disabled = false
		PlayerManager.player.gravity = true
		PlayerManager.player.interact_ray.enabled = true



## The hood finished opening: show the battery and wires and zoom in on them
## (unless the battery is already done, or in Loop 0).
func _on_Hood_animation_finished(anim_name: String):
	if anim_name == "Hood":
		if not PlayerManager.minigameThreePassed and not PlayerManager.Loop0:
			PlayerManager.Battery.visible = true
			PlayerManager.NegativeWire.visible = true
			PlayerManager.PositiveWire.visible = true
			HoodAnimationPlayer.play("ZoomInbattery")

## Office elevator door animation: when the doors finish closing
## (DoorClosed) the elevator starts to fall.
func _on_ElevatorButtonFlash_animation_finished(anim_name: String):
	if anim_name == "Take 001" && !DoorOpen:
		DoorOpen = true
	if anim_name == "Take 001" && DoorClosed:
		ElevatorFall = true
		AudioManager.play_sound(AudioManager.elevator_whitenoise)


