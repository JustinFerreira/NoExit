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
var entering = true
@onready var animation_player = $"../../AnimationPlayer"
@onready var car_camera = $"../../Head/Car_Cam"
@onready var interact_ray = $"../../Head/Car_Cam/InteractRay"
@onready var DoorFlash = $MeshInstance3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	## connects animation player to animation finished 
	animation_player.connect("animation_finished", _on_animation_finished)
	animation_player.play("DoorFlash")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

## _on_animation_finished
## this function is called anytime an
## animation is fished so it can process
## what happens after the animation
func _on_animation_finished(anim_name: String):
	player = PlayerManager.player
	#print("Animation Finished: ", anim_name)
	
	
	
	## Car Door opening and Closing animation
	if anim_name == "NoExitProps":
		## checks if this is the first frame of animation to play sound at correct time  
		if animation_player.current_animation_position == 0.0:
			AudioManager.play_sound(AudioManager.CarDoorClose)
		## checks to see if the player is trying to enter the car
		if player.Incar == false && entering == true:
			PlayerManager.InAnimation = false
			player.head = $"../../Head"
			player.camera = car_camera
			player.interact_ray = interact_ray
			player.interact_ray.enabled = false
			player.TbobON = false
			car_camera.current = true
			animation_player.play("GettinginCar")
		## checks to see if player is trying to exit car
		if player.Incar == true && entering == false:
			animation_player.play_backwards("GettinginCar")
	## Animation of player getting in the Car
	if anim_name == "GettinginCar" && player.Incar == false && entering == true:
		player.Incar = true
		animation_player.play_backwards("NoExitProps")
		player.interact_ray.enabled = true
		prompt_message = "Exit Car"
		if !PlayerManager.minigameOnePassed:
			PlayerManager.CharacterDialog("I better hot wire my own car like I always do right under the steering wheel.")
	
	## Exiting car animations
	if anim_name == "GettinginCar" && player.Incar == true && entering == false:
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
		animation_player.play_backwards("NoExitProps")
		player.interact_ray.enabled = true
		prompt_message = "Get in Car"
		DoorFlash.visible = true
		animation_player.play("DoorFlash")
		
		
		# Teleport player 5 meters next to the car
		player.global_position = self.global_position + Vector3(5, 0, 0)
		
	## Door Flash
	if anim_name == "DoorFlash":
		if player.Incar == false:
			animation_player.play("DoorFlash")
			


func _on_interacted(body: Variant) -> void:
	DoorFlash.visible = false
	player = PlayerManager.player
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
			entering = true
			unlocked = true
			# Open door animation
			animation_player.play("NoExitProps")
			PlayerManager.InAnimation = true
			PlayerManager.teleportEnemy = true
		else:
			# Play Car locked noise
			AudioManager.play_sound(AudioManager.CarDoorLocked)
			PlayerManager.CharacterDialog("Where did I leave my keys?")
			pass
	##Exiting car
	elif player.Incar == true:
		entering = false
		player.interact_ray.enabled = false
		animation_player.play("NoExitProps")
		AudioManager.play_sound(AudioManager.CarDoorOpen)
	##Entering Car after Unlocked
	elif player.Incar == false && unlocked == true:
		AudioManager.play_sound(AudioManager.CarDoorOpen)
		PlayerManager.InAnimation = true
		entering = true
		animation_player.play("NoExitProps")
		PlayerManager.teleportEnemy = true
