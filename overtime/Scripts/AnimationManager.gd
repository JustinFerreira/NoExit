## OverTime Production
## Last upadated 11/19/25 by Justin Ferreira
## AnimationManager Script
## - 

extends Node

## Animation Players

var CarAnimationPlayer

## Flashing Animation Players

var DoorFlashAnimationPlayer
var HoodFlashAnimationPlayer
var SteeringWheelFlashAnimationPlayer
var GasIntakeFlashAnimationPlayer
var WirePositiveFlashAnimationPlayer
var WireNegativeFlashAnimationPlayer

## Meshes to toggle visiblity

# Car
var SteeringWheelFlash
var DoorFlash
var HoodFlash
var GasIntakeFlash
var WirePositiveFlash
var WireNegativeFlash

## random stuff needed

var CarInteractRay
var CarHead

## variables for pocesssing

var CarEntering = true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func ActivateWireNegativeFlashAnimationPlayer():
	WireNegativeFlashAnimationPlayer.connect("animation_finished", _on_WireNegativeFlash_animation_finished)
	
func ActivateWirePositiveFlashAnimationPlayer():
	WirePositiveFlashAnimationPlayer.connect("animation_finished", _on_WirePositiveFlash_animation_finished)

func ActivateGasIntakeFlashAnimationPlayer():
	GasIntakeFlashAnimationPlayer.connect("animation_finished", _on_GasIntakeFlash_animation_finished)

func ActivateSteeringWheelFlashAnimationPlayer():
	SteeringWheelFlashAnimationPlayer.connect("animation_finished", _on_SteeringWheelFlash_animation_finished)
	
func ActivateHoodFlashAnimationPlayer():
	HoodFlashAnimationPlayer.connect("animation_finished", _on_HoodFlash_animation_finished)

func ActivateDoorFlashAnimationPlayer():
	DoorFlashAnimationPlayer.connect("animation_finished", _on_DoorFlash_animation_finished)

func ActivateCarAnimationPlayer():
	CarAnimationPlayer.connect("animation_finished", _on_animation_finished)

func _on_animation_finished(anim_name: String):
	var player = PlayerManager.player
	#print("Animation Finished: ", anim_name)
	
	
	
	## Car Door opening and Closing animation
	if anim_name == "NoExitProps":
		## checks if this is the first frame of animation to play sound at correct time  
		if CarAnimationPlayer.current_animation_position == 0.0:
			AudioManager.play_sound(AudioManager.CarDoorClose)
		## checks to see if the player is trying to enter the car
		if not player.Incar && CarEntering:
			PlayerManager.InAnimation = false
			player.head = CarHead
			player.camera = CameraManager.CarCamera
			player.interact_ray = CarInteractRay
			player.interact_ray.enabled = false
			player.TbobON = false
			CameraManager.CarCamera.current = true
			CarAnimationPlayer.play("GettinginCar")
		## checks to see if player is trying to exit car
		if player.Incar == true && not CarEntering:
			CarAnimationPlayer.play_backwards("GettinginCar")
	## Animation of player getting in the Car
	if anim_name == "GettinginCar" && not player.Incar && CarEntering:
		player.Incar = true
		CarAnimationPlayer.play_backwards("NoExitProps")
		player.interact_ray.enabled = true
		if PlayerManager.minigameOnePassed && PlayerManager.minigameTwoPassed && PlayerManager.minigameThreePassed:
			SteeringWheelFlash.visible = true
			CarAnimationPlayer.play("HotWireFlash")
		if !PlayerManager.minigameOnePassed:
			SteeringWheelFlash.visible = true
			CarAnimationPlayer.play("HotWireFlash")
			PlayerManager.CharacterDialog("I better hot wire my own car like I always do right under the steering wheel.")
	
	## Exiting car animations
	if anim_name == "GettinginCar" && player.Incar && not CarEntering:
		player.Incar = false
		player.TbobON = true
		player.head = player.HEAD
		player.camera = player.CAMERA
		player.interact_ray = player.INTERACT_RAY
		player.interact_ray.enabled = false
		player.CAMERA.current = true
		player.AREA3D.monitoring = true
		player.AREA3D.monitorable = true
		player.COLLISIONSHAPE3D.disabled = false
		player.gravity = true
		CarAnimationPlayer.play_backwards("NoExitProps")
		player.interact_ray.enabled = true
		SteeringWheelFlash.visible = false
		if not PlayerManager.minigameOnePassed or (PlayerManager.minigameOnePassed and PlayerManager.minigameTwoPassed and PlayerManager.minigameThreePassed):
			DoorFlash.visible = true
		if not PlayerManager.minigameThreePassed && PlayerManager.has_item("Battery"):
			AnimationManager.HoodFlash.visible = true
		if not PlayerManager.minigameTwoPassed && PlayerManager.has_item("Gas Canister"):
			AnimationManager.GasIntakeFlash.visible = true
		
		
		# Teleport player 5 meters next to the car
		player.global_position = DoorFlash.global_position + Vector3(5, 0, 0)

func _on_DoorFlash_animation_finished(anim_name: String):
	if anim_name == "DoorFlash":
		DoorFlashAnimationPlayer.play("DoorFlash")

func _on_HoodFlash_animation_finished(anim_name: String):
	if anim_name == "HoodFlash":
		HoodFlashAnimationPlayer.play("HoodFlash")
		
		
func _on_SteeringWheelFlash_animation_finished(anim_name: String):
	if anim_name == "SteeringWheelFlash":
		SteeringWheelFlashAnimationPlayer.play("SteeringWheelFlash")
		

func _on_GasIntakeFlash_animation_finished(anim_name: String):
	if anim_name == "GasIntakeFlash":
		GasIntakeFlashAnimationPlayer.play("GasIntakeFlash")
		
func _on_WirePositiveFlash_animation_finished(anim_name: String):
	if anim_name == "WirePositiveFlash":
		WirePositiveFlashAnimationPlayer.play("WirePositiveFlash")
		
func _on_WireNegativeFlash_animation_finished(anim_name: String):
	if anim_name == "WireNegativeFlash":
		WireNegativeFlashAnimationPlayer.play("WireNegativeFlash")
	
