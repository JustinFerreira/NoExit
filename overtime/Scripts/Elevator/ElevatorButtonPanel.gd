## No Exit
## Overtime Studios
## Last updated  5/4/26 by Justin Ferreira
## ElevatorButtonPanel Script
## - This is the Inside button of the elevator which
## closes the elevator doors, waits out the "ride" (RIDE_SECONDS, the
## elevator itself never moves) and then takes the player to the parking
## garage. While the doors are shut only the elevator is heard.

extends Interactable

const ElevatorRide = preload("res://Scripts/Elevator/ElevatorRide.gd")

@onready var door_collision: CSGBox3D = $"../ElevatorCollisions/DoorCollision"

## How long the ride down lasts, from the doors finishing closing.
const RIDE_SECONDS := 5.0
var _ride_time: float = 0.0
var InElevator: bool = false
var _leaving: bool = false
## How bright the light on the elevator's outside front is (matches the
## office's ceiling lights; see HelperManager.light_elevator_on_its_own).
@export var front_light_energy: float = 8.0

func _ready() -> void:
	# The buttons are part of the elevator model: outline them with the box
	# that sits over them - just its face toward the inside of the elevator,
	# never drawn itself. Our own box is only the click area.
	$MeshInstance3D.visible = false
	visible = true
	use_outline_stand_in($"../ElevatorPanelFlash", $"../ElevatorCollisions/FloorCollision".global_position)
	super._ready()   # Interactable setup (click hookup, outline)
	HelperManager.light_elevator_on_its_own($"..", $"../OmniLight3D", front_light_energy)
	AnimationManager.DoorClosed = false

func _process(delta: float) -> void:
	# ElevatorFall: the doors have finished closing (AnimationManager)
	if AnimationManager.ElevatorFall:
		if _ride_time == 0.0:
			# the doors are shut: load the garage now, during the ride, so
			# arriving doesn't freeze
			GameState.preload_level(RogueRun.garage_scene("res://Levels/ParkingGarage.tscn"))
		_ride_time += delta

	if _ride_time >= RIDE_SECONDS and not _leaving:
		_leaving = true
		AnimationManager.ElevatorFall = false
		AudioManager.cancel_music()
		AudioManager.cancel_loop_sfx()
		# Arrive in the garage elevator facing the same way relative to the
		# elevator as the player is now.
		GameState.change_level(RogueRun.garage_scene("res://Levels/ParkingGarage.tscn"), "ElevatorSpawn",
			get_tree().current_scene.get_node_or_null("ElevatorSpawn"))


func _on_interacted(_body: Variant) -> void:
	if InElevator:
		if PlayerManager.cutscene:
			return
		# the ride cutscene from where they stand (see ElevatorRide)
		var spawn := get_tree().current_scene.get_node_or_null("ElevatorSpawn") as Node3D
		if spawn == null:
			start_ride()
			return
		ElevatorRide.ride_in(self, spawn.global_transform, door_collision, null, self, start_ride)
	else:
		PlayerManager.Hint("Get in the elevator bro")

## Closes the doors and starts the ride down (clicking the panel, or the ride
## cutscene from the outside button pressing it for the player).
func start_ride() -> void:
	if AnimationManager.DoorClosed:
		return
	AudioManager.play_sound(AudioManager.ElevatorCloseDoor)
	door_collision.translate(Vector3(0,-3,0))
	is_interactable = false
	AnimationManager.ElevatorDoorButtonAnimationPlayer.play_backwards("Take 001")
	AnimationManager.DoorClosed = true
	AudioManager.shut_out_world($"..")
	EventManager.CameFromGarage = false

func _on_area_3d_area_entered(_area: Area3D) -> void:
	InElevator = true


func _on_area_3d_area_exited(_area: Area3D) -> void:
	InElevator = false


## The player walked into or out of the area outside the elevator: if the
## doors were left open while they're not inside, close them.
func _on_outside_elevator_area_area_entered(_area: Area3D) -> void:
	_close_doors_if_left_open()

func _on_outside_elevator_area_area_exited(_area: Area3D) -> void:
	_close_doors_if_left_open()

func _close_doors_if_left_open() -> void:
	if PlayerManager.cutscene:
		return   # the ride cutscene is walking them in
	if EventManager.ElevatorDoorOpen and not InElevator:
		$"../OutsideButton".clickedrecent = false
		AnimationManager.ElevatorDoorButtonAnimationPlayer.play_backwards("Take 001")
		EventManager.ElevatorDoorOpen = false
		door_collision.translate(Vector3(0,-3,0))
