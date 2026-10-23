## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Parking Garage Elevator Inside Button
## - This button will close elevator doors and bring player
## to the Office

extends Interactable

var fall_speed: float = 2.0
var rising: bool = false

var huh: float = 0


# Called every frame. 'delta' is the elapsed time since the previous frame.
# How long the ride up lasts (it used to count 200 frames, which is
# 3.3 s at 60 FPS but much shorter on faster PCs).
const RIDE_SECONDS := 200.0 / 60.0

func _process(delta: float) -> void:
	if  rising == true:
		huh += delta
		
	
	if huh >= RIDE_SECONDS:
		rising = false
		huh = 0
		AudioManager.cancel_music()
		AudioManager.cancel_loop_sfx()
		# Arrive in the office elevator facing the same way relative to the
		# elevator as the player is now.
		GameState.change_level("res://Levels/Office.tscn", "ElevatorSpawn",
			get_tree().current_scene.get_node_or_null("ElevatorSpawn"))

func _on_interacted(_body: Variant) -> void:
	if not $"../..".inside || $"../..".outside:
		PlayerManager.Hint("Get in the Elevator")
		return
	_on_interaction_complete()
	$"../..".up = false
	$"../../ElevatorCollisions/DoorCollision".translate(Vector3(0,-3,0))
	
	EventManager.Comingfromelevator = true
	$"../../AnimationPlayer".play_backwards("Take 001")
	AudioManager.play_sound(AudioManager.ElevatorCloseDoor)
		
		
