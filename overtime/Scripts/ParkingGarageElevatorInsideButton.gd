extends Interactable

var fall_speed = 2.0
var rising = false
var ButtonCanBePress = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if  rising == true:
		$"../..".position.y += fall_speed * delta
		
	
	if $"../..".position.y >= 20:
		rising = false
		PlayerManager.SavePlayerRotation()
		AudioManager.cancel_music()
		AudioManager.cancel_loop_sfx()
		get_tree().change_scene_to_file("res://Levels/Office.tscn")

func _on_interacted(body: Variant) -> void:
	if not $"../..".inside or not ButtonCanBePress:
		PlayerManager.Hint("Get in the Elevator")
		return
	_on_interaction_complete()
	$"../..".backwards = false
	if $"../..".animationplayed == true:
		$"../../ElevatorCollisions/DoorCollision".translate(Vector3(0,-3,0))
	EventManager.Comingfromelevator = true
	$"../../AnimationPlayer".play_backwards("Take 001")
	AudioManager.play_sound(AudioManager.ElevatorCloseDoor)
		
		


func _on_out_side_elevator_area_exited(area: Area3D) -> void:
	ButtonCanBePress = true


func _on_out_side_elevator_area_entered(area: Area3D) -> void:
	ButtonCanBePress = false
