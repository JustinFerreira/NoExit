## No Exit
## Overtime Studios

extends Node3D

@export var playerelevator: bool

@onready var animation_player = $AnimationPlayer

var up = true

var inside = false
var outside = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if animation_player:
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)
	
	if playerelevator:
		AudioManager.stop_loop("step")
		PlayerManager.player = $"../Player"
		if PlayerManager.testing == false:
			PlayerManager.ApplyPlayerRotation()
		#Play Open Animation and on Animation finish Move door Collision
		
		AudioManager.play_sound(AudioManager.ElevatorDing)
		AudioManager.play_sound(AudioManager.ElevatorOpenDoor)
		$AnimationPlayer.play("Take 001")
		$ElevatorCollisions/DoorCollision.translate(Vector3(0,3,0))
		if !PlayerManager.Loop1 && !PlayerManager.has_item("Car Keys"):
			PlayerManager.AddToInventory("Car Keys", 0.5, true)
	else:
		$OutsideButton/OutsideButton.is_interactable = true
		up = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_animation_finished(anim_name: String):
	if anim_name == "Take 001":
		if up == false and inside:
			$InsideButton/InsideButton.rising = true
		elif up == false:
			$OutsideButton/OutsideButton.is_interactable = true


func _on_area_3d_area_exited(area: Area3D) -> void:
	inside = false


func _on_area_3d_area_entered(area: Area3D) -> void:
	inside = true
	
	
func _on_out_side_elevator_area_entered(area: Area3D) -> void:
	outside = true


func _on_out_side_elevator_area_exited(area: Area3D) -> void:
	outside = false
	if up and not inside:
		$AnimationPlayer.play_backwards("Take 001")
		$ElevatorCollisions/DoorCollision.translate(Vector3(0,-3,0))
		up = false
	pass
