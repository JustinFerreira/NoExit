extends Interactable

var unlocked = false
var player 
var entering = true
@onready var animation_player = $"../../AnimationPlayer"
@onready var car_camera = $"../../Head/Car_Cam"
@onready var interact_ray = $"../../Head/Car_Cam/InteractRay"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.connect("animation_finished", _on_animation_finished)
	player = get_tree().current_scene.get_node("Player")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_animation_finished(anim_name: String):
	#print("Animation Finished: ", anim_name)
	
	## Entering car animations
	if anim_name == "NoExitProps" && player.Incar == false && entering == true:
		PlayerManager.InAnimation = false
		player.head = $"../../Head"
		player.camera = car_camera
		player.interact_ray = interact_ray
		player.interact_ray.enabled = false
		player.TbobON = false
		car_camera.current = true
		animation_player.play("GettinginCar")
	if anim_name == "GettinginCar" && player.Incar == false && entering == true:
		player.Incar = true
		animation_player.play_backwards("NoExitProps")
		player.interact_ray.enabled = true
		prompt_message = "Exit Car"
		PlayerManager.CharacterDialog("I better hot wire my own car like I always do right under the steering wheel.")
	
	## Exiting car animations
	if anim_name == "NoExitProps" && player.Incar == true && entering == false:
		animation_player.play_backwards("GettinginCar")
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
		
		# Teleport player 5 meters next to the car
		player.global_position = self.global_position + Vector3(5, 0, 0)
		


func _on_interacted(body: Variant) -> void:
	##Entering car if locked
	if unlocked == false:
		if PlayerManager.RemoveItemByName("Car Keys"):
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
			# Play audio of player saying "Where did I leave my keys?"
			pass
	##Exiting car
	elif player.Incar == true:
		entering = false
		player.interact_ray.enabled = false
		animation_player.play("NoExitProps")
	##Entering Car after Unlocked
	elif player.Incar == false && unlocked == true:
		PlayerManager.InAnimation = true
		entering = true
		animation_player.play("NoExitProps")
		PlayerManager.teleportEnemy = true
