extends Interactable



func _on_interacted(body: Variant) -> void:
	if $"../../OutsideButton/OutsideButton".clickedafterexit == true and $"../..".inside == true:
		$"../../ElevatorCollisions/DoorCollision".translate(Vector3(0,-3,0))
		$"../../AnimationPlayer".play_backwards("Take 001")
		AudioManager.play_sound(AudioManager.ElevatorCloseDoor)
		EventManager.Comingfromelevator = true
		
