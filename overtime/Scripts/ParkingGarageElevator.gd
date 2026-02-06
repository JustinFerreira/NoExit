## No Exit
## Overtime Studios

extends Node3D

@onready var animation_player = $AnimationPlayer

var backwards = false
var hintsaid = false
var inside = true
var animationplayed = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AudioManager.stop_loop("step")
	PlayerManager.player = $"../Player"
	if PlayerManager.testing == false:
		PlayerManager.ApplyPlayerRotation()
	#Play Open Animation and on Animation finish Move door Collision
	animation_player.connect("animation_finished", _on_animation_finished)
	AudioManager.play_sound(AudioManager.ElevatorDing)
	AudioManager.play_sound(AudioManager.ElevatorOpenDoor)
	$AnimationPlayer.play("Take 001")
	if !PlayerManager.Loop1 && !PlayerManager.has_item("Car Keys"):
		PlayerManager.AddToInventory("Car Keys", 0.5, true)
	#if PlayerManager.gotGas_Canister:
		#PlayerManager.AddToInventory("Gas Canister", 1.5)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_animation_finished(anim_name: String):
	#print("Animation", anim_name)
	
	if anim_name == "Take 001":
		animationplayed = true
		if inside and EventManager.Comingfromelevator == true:
			$InsideButton/InsideButton.rising = true
		elif backwards == true:
			if $OutsideButton/OutsideButton.clickedafterexit == true:
				$ElevatorCollisions/DoorCollision.translate(Vector3(0,3,0))
				backwards = false
		elif not EventManager.Comingfromelevator == true:
			$ElevatorCollisions/DoorCollision.translate(Vector3(0,3,0))
			if PlayerManager.Loop0 && not hintsaid:
				hintsaid = true
				PlayerManager.Hint("Equip your keys and Press F to make your car sound off")


func _on_area_3d_area_exited(area: Area3D) -> void:
	inside = false
	if backwards == false:
		$OutsideButton/OutsideButton.is_interactable = true
		$OutsideButton/OutsideButton.clickedafterexit = false
		$ElevatorCollisions/DoorCollision.translate(Vector3(0,-3,0))
		backwards = true
		AudioManager.play_sound(AudioManager.ElevatorCloseDoor)
		$AnimationPlayer.play_backwards("Take 001")
	


func _on_area_3d_area_entered(area: Area3D) -> void:
	inside = true
