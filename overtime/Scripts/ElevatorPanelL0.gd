## OverTime Production
## Last upadated 11/30/25 by Justin Ferreira
## ElevatorButtonPanel Script
## - This is the Inside button of the elevator which
## closes the elevator doors and moves the elevator down.
## this also teleports the player to the parking garage
## this is for Loop 0

extends Interactable

@onready var animation_player = $"../AnimationPlayer"
@onready var door_collision = $"../ElevatorCollisions/DoorCollision"

var fall = false
var fall_speed = 2.0
var DoorClosed = false
var InElevator = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AnimationManager.ElevatorPanelAnimationPlayer = $"../ElevatorPanelAnimationPlayer"
	AnimationManager.ElevatorPanelFlash = $"../ElevatorPanelFlash"
	AnimationManager.ActivateElevatorPanelAnimationPlayer()
	AnimationManager.ElevatorPanelAnimationPlayer.play("ElevatorPanelFlash")
	animation_player.connect("animation_finished", _on_animation_finished)
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if fall == true:
		$"..".position.y -= fall_speed * delta
		
	
	if $"..".position.y <= -10:
		PlayerManager.SavePlayerRotation()
		AudioManager.cancel_music()
		AudioManager.cancel_loop_sfx()
		get_tree().change_scene_to_file("res://Scenes/Levels/ParkingGarageL0.tscn")

func _on_animation_finished(anim_name: String):
	#print("Animation", anim_name)
	
	if anim_name == "Take 001" && DoorClosed:
		fall = true
		AudioManager.play_sound(AudioManager.elevator_whitenoise)
		DoorClosed = false

func _on_interacted(body: Variant) -> void:
	if InElevator:
		AnimationManager.ElevatorPanelFlash.visible = false
		AudioManager.play_sound(AudioManager.ElevatorCloseDoor)
		door_collision.translate(Vector3(0,-3,0))
		DoorClosed = true
		is_interactable = false
		prompt_message = ""
		animation_player.play_backwards("Take 001")
	else:
		PlayerManager.Hint("Get in the elevator bro")


func _on_area_3d_area_entered(area: Area3D) -> void:
	InElevator = true



func _on_area_3d_area_exited(area: Area3D) -> void:
	InElevator = false
