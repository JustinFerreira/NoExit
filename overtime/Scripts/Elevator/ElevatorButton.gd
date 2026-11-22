## No Exit
## Overtime Studios
## Last updated 1/20/26 by Justin Ferreira
## ElevatorButton Script
## - This script is for the button outside of the elevator
## it opens the doors for the elevator and during Loop1
## give a hint for tutorial

extends Interactable

const ElevatorRide = preload("res://Scripts/Elevator/ElevatorRide.gd")

@onready var door_collision: CSGBox3D = $"../ElevatorCollisions/DoorCollision"

var DoorOpen: bool = false;
var messageplayed: bool = false
var clickedrecent: bool = false

func _ready() -> void:
	# The button is part of the elevator model: outline it with the box that
	# sits over it (never drawn itself). Our own box is just the click area.
	$MeshInstance3D.visible = false
	visible = true
	use_outline_stand_in($"../ElevatorOutsideButtonFlash")
	super._ready()   # Interactable setup (click hookup, outline)
	AnimationManager.ElevatorDoorButtonAnimationPlayer = $"../ElevatorDoorButtonAnimationPlayer"
	AnimationManager.ActivateElevatorButtonAnimationPlayer()

func _on_interacted(_body: Variant) -> void:
	# Pressing the elevator button is done with the janitor too: from now on
	# he's only outlined while aimed at (the hover flash), not when close by.
	if is_instance_valid(PlayerManager.janitor):
		PlayerManager.janitor.mark_used()
	if EventManager.ElevatorDoorOpen:
		return
	if PlayerManager.has_item("Car Keys") and not clickedrecent:
		if not PlayerManager.talkToJanitor && PlayerManager.deaths < 2:
			PlayerManager.janitor.talkToPlayer()
			UiManager.set_cursor_visible(false)
			return
		clickedrecent = true
		EventManager.ElevatorDoorOpen = true
		door_collision.translate(Vector3(0,3,0))
		AudioManager.play_sound(AudioManager.ElevatorDing)
		AudioManager.play_sound(AudioManager.ElevatorOpenDoor)
		if PlayerManager.Loop0 and not EventManager.CameFromGarage and not messageplayed:
			if PlayerManager.Hold_Shift:
				PlayerManager.Hint(EventManager.elevator_hint_1)
				messageplayed = true
			else:
				PlayerManager.Hint(EventManager.elevator_hint_2)
				messageplayed = true
		AnimationManager.ElevatorDoorButtonAnimationPlayer.play("Take 001")
		_ride_cutscene()
	elif not PlayerManager.has_item("Car Keys"):
		PlayerManager.CharacterDialog(EventManager.elevator_no_keys)


## The ride down, as a cutscene (see ElevatorRide): the player walks in, presses
## the panel and rides down. The garage elevator they arrive in ends it.
func _ride_cutscene() -> void:
	var spawn := get_tree().current_scene.get_node_or_null("ElevatorSpawn") as Node3D
	var panel := get_node_or_null("../InsideButtons")
	if spawn == null or panel == null:
		return   # no marker to walk to: the player walks in and clicks themselves
	await ElevatorRide.ride_in(self, spawn.global_transform, $"../ElevatorCollisions/DoorCollision",
		AnimationManager.ElevatorDoorButtonAnimationPlayer, panel, panel.start_ride)
