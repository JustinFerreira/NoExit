## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Parking Garage Elevator Outside Button 
## - This button will open up the elevator
## for the player to get in

extends Interactable


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	is_interactable = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_interacted(body: Variant) -> void:
		AudioManager.play_sound(AudioManager.ElevatorDing)
		AudioManager.play_sound(AudioManager.ElevatorOpenDoor)
		is_interactable = false
		$"../../AnimationPlayer".play("Take 001")
		$"../../ElevatorCollisions/DoorCollision".translate(Vector3(0,3,0))
		$"../..".up = true
