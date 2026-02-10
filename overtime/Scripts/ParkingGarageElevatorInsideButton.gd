extends Interactable

var fall_speed = 2.0
var rising = false

var huh = 0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if  rising == true:
		huh += 1
		
	
	if huh >= 200:
		rising = false
		PlayerManager.SavePlayerRotation()
		AudioManager.cancel_music()
		AudioManager.cancel_loop_sfx()
		get_tree().change_scene_to_file("res://Levels/Office.tscn")

func _on_interacted(body: Variant) -> void:
	if not $"../..".inside || $"../..".outside:
		PlayerManager.Hint("Get in the Elevator")
		return
	_on_interaction_complete()
	$"../..".up = false
	$"../../ElevatorCollisions/DoorCollision".translate(Vector3(0,-3,0))
	
	EventManager.Comingfromelevator = true
	$"../../AnimationPlayer".play_backwards("Take 001")
	AudioManager.play_sound(AudioManager.ElevatorCloseDoor)
		
		
