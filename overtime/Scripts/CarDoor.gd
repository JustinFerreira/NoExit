extends Interactable

var initial_camera_transform: Transform3D

var open = false
var unlocked = false
var player 
var backwards = false
@onready var animation_player = $"../../AnimationPlayer"
@onready var car_camera = $"../../Head/Car_Cam"
@onready var interact_ray = $"../../Head/Car_Cam/InteractRay"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	initial_camera_transform = car_camera.global_transform
	animation_player.connect("animation_finished", _on_animation_finished)
	player = get_tree().current_scene.get_node("Player")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_animation_finished(anim_name: String):
	print("Animation Finished: ", anim_name)
	
	if anim_name == "GettinginCar" && backwards == false:
		player.Incar = true
		player.TbobON = false
		player.head = $"../../Head"
		player.camera = car_camera
		player.interact_ray = interact_ray
		animation_player.play_backwards("NoExitProps")
		open = false
		prompt_message = "Exit Car"
		backwards = true
	elif anim_name == "GettinginCar" && backwards == true:
		car_camera.global_transform = initial_camera_transform
		player.head = player.HEAD
		player.camera = player.CAMERA
		player.interact_ray = player.INTERACT_RAY
		player.CAMERA.current = true
		backwards = false


func _on_interacted(body: Variant) -> void:
	if unlocked == false:
		if PlayerManager.RemoveItemByName("DoorKey"):
			if open == false:
				animation_player.play("NoExitProps")
				if player.Incar == false:
					prompt_message = "Get In Car"
					open = true
					unlocked = true
	elif open == true:
		car_camera.current = true
		animation_player.play("GettinginCar")	
	elif player.Incar == true:
		animation_player.play_backwards("GettinginCar")
		player.Incar = false
		player.TbobON = true
		prompt_message = "Open Door"
	elif unlocked == true && open == false && player.Incar == false:
		animation_player.play("NoExitProps")
		prompt_message = "Get In Car"
		open = true
