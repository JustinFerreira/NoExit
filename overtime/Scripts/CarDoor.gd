extends Interactable

var open = false
var player 
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
	print("Animation Finished: ", anim_name)
	
	if anim_name == "GettinginCar":
		player.Incar = true
		player.TbobON = false
		player.head = $"../../Head"
		player.camera = car_camera
		player.interact_ray = interact_ray
		animation_player.play_backwards("NoExitProps")
		open = false
		prompt_message = "Exit Car"


func _on_interacted(body: Variant) -> void:
	if PlayerManager.RemoveItemByName("DoorKey"):
		if open == false:
			animation_player.play("NoExitProps")
			if player.Incar == false:
				prompt_message = "Get In Car"
				open = true
	elif open == true:
		car_camera.current = true
		animation_player.play("GettinginCar")	
	elif player.Incar == true:
		player.Incar = false
		player.TbobON = true
		player.head = player.HEAD
		player.camera = player.CAMERA
		player.interact_ray = player.INTERACT_RAY
		player.CAMERA.current = true
		prompt_message = "Open Door"
