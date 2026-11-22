## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Parking Garage Elevator
## - this gives functionality to the elevators in the parking
## garage. opening for the player when arriving in the parking garage
## and sensing if the player is inside or not to close the doors


extends Node3D

const ElevatorRide = preload("res://Scripts/Elevator/ElevatorRide.gd")

## set to true for the elevator the player starts in the parking garage
@export var playerelevator: bool

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var up: bool = true
## The player is arriving in this elevator: its doors opening (the first time)
## ends the ride cutscene.
var _arriving: bool = false

var inside: bool = false
var outside: bool = false
## How bright the light on the elevator's outside front is (matches the
## garage lighting; see HelperManager.light_elevator_on_its_own).
@export var front_light_energy: float = 0.2

func _ready() -> void:
	HelperManager.light_elevator_on_its_own(self, $OmniLight3D, front_light_energy)
	if animation_player:
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)

	_arriving = playerelevator
	if playerelevator:
		AudioManager.stop_loop("step")
		PlayerManager.player = $"../Player"
		# Facing comes from the ElevatorSpawn marker (GameState.change_level).
		#Play Open Animation and on Animation finish Move door Collision

		AudioManager.play_sound(AudioManager.ElevatorDing)
		AudioManager.play_sound(AudioManager.ElevatorOpenDoor)
		$AnimationPlayer.play("Take 001")
		$ElevatorCollisions/DoorCollision.translate(Vector3(0,3,0))
		# the player can walk out once the doors are partly open
		if PlayerManager.cutscene:
			ElevatorRide.arrive_as_doors_open($AnimationPlayer, "Take 001")
		if !PlayerManager.Loop1 && !PlayerManager.has_item("Car Keys"):
			PlayerManager.AddToInventory("Car Keys", 0.5, true)
	else:
		$OutsideButton/OutsideButton.is_interactable = true
		up = false


func _on_animation_finished(anim_name: String):
	if anim_name == "Take 001":
		# arrived by the ride cutscene (control usually came back already, as
		# the doors opened - see ElevatorRide.arrive_as_doors_open) - hand
		# control back (and let the enemies move)
		if _arriving and up:
			_arriving = false
			ElevatorRide.arrived()
		if up == false and inside:
			$InsideButton/InsideButton.rising = true
		elif up == false:
			$OutsideButton/OutsideButton.is_interactable = true


func _on_area_3d_area_exited(_area: Area3D) -> void:
	inside = false


func _on_area_3d_area_entered(_area: Area3D) -> void:
	inside = true


func _on_out_side_elevator_area_entered(_area: Area3D) -> void:
	outside = true


func _on_out_side_elevator_area_exited(_area: Area3D) -> void:
	outside = false
	if PlayerManager.cutscene:
		return   # the ride cutscene is walking them in
	if up and not inside:
		$AnimationPlayer.play_backwards("Take 001")
		$ElevatorCollisions/DoorCollision.translate(Vector3(0,-3,0))
		up = false
	pass

## Where the player stands for the ride up (ElevatorRide): the level's
## ElevatorSpawn marker sits in the elevator the player arrives in, and all
## the elevators are alike - so it's that marker, carried over to this one.
func ride_marker() -> Transform3D:
	var spawn := get_tree().current_scene.get_node_or_null("ElevatorSpawn") as Node3D
	if spawn == null:
		return global_transform
	var home: Node3D = self
	for e in get_parent().get_children():
		if e.get_script() == get_script() and e.playerelevator:
			home = e
			break
	return global_transform * home.global_transform.affine_inverse() * spawn.global_transform

## ride_marker() as a node (for GameState.change_level's keep_facing_from).
func ride_marker_node() -> Node3D:
	var m := get_node_or_null("RideMarker") as Marker3D
	if m == null:
		m = Marker3D.new()
		m.name = "RideMarker"
		add_child(m)
	m.global_transform = ride_marker()
	return m
