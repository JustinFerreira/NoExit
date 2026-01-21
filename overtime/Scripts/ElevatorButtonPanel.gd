## OverTime Studios
## Last upadated 1/20/26 by Justin Ferreira
## ElevatorButtonPanel Script
## - This is the Inside button of the elevator which
## closes the elevator doors and moves the elevator down.
## this also teleports the player to the parking garage

extends Interactable

@onready var door_collision = $"../ElevatorCollisions/DoorCollision"

var fall_speed = 2.0
var InElevator = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#set up animations for 
	AnimationManager.ElevatorPanelAnimationPlayer = $"../ElevatorPanelAnimationPlayer"
	AnimationManager.ElevatorPanelFlash = $"../ElevatorPanelFlash"
	AnimationManager.ActivateElevatorPanelFlashAnimationPlayer()
	AnimationManager.ElevatorPanelAnimationPlayer.play("ElevatorPanelFlash")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if AnimationManager.ElevatorFall == true:
		$"..".position.y -= fall_speed * delta
		
	
	if $"..".position.y <= -10:
		AnimationManager.ElevatorFall = false
		PlayerManager.SavePlayerRotation()
		AudioManager.cancel_music()
		AudioManager.cancel_loop_sfx()
		if PlayerManager.Loop0:
			get_tree().change_scene_to_file("res://Levels/ParkingGarageL0.tscn")
		elif PlayerManager.Loop1:
			get_tree().change_scene_to_file("res://Levels/ParkingGarageL1.tscn")

func _on_interacted(body: Variant) -> void:
	if InElevator:
		AnimationManager.ElevatorPanelFlash.visible = false
		AudioManager.play_sound(AudioManager.ElevatorCloseDoor)
		door_collision.translate(Vector3(0,-3,0))
		is_interactable = false
		prompt_message = ""
		AnimationManager.ElevatorDoorButtonAnimationPlayer.play_backwards("Take 001")
		AnimationManager.DoorClosed = true
	else:
		PlayerManager.Hint("Get in the elevator bro")


func _on_area_3d_area_entered(area: Area3D) -> void:
	InElevator = true



func _on_area_3d_area_exited(area: Area3D) -> void:
	InElevator = false
