## No Exit
## Overtime Studios
## Elevator Ghost Event (RARE - once per run, see GarageEvent)
## - An elevator the player is walking past dings and opens - empty - waits a
##   moment and closes again. Put on every garage elevator at load
##   (EventDirector); only when its doors are shut and nobody is in it.

extends "res://Scripts/Events/GarageEvent.gd"

const EventSounds = preload("res://Scripts/Events/EventSounds.gd")

func _init() -> void:
	tier = Tier.RARE
	kind = "elevator_ghost"
	min_killer_distance = 35.0

func can_fire() -> bool:
	var el = get_parent()
	return is_instance_valid(el) and not el.up and not el.inside and not el.get_node("AnimationPlayer").is_playing()

func _fire() -> void:
	var el = get_parent()
	var anim: AnimationPlayer = el.get_node("AnimationPlayer")
	var door: Node3D = el.get_node("ElevatorCollisions/DoorCollision")
	EventSounds.play_at(get_tree(), AudioManager.ElevatorDing, door.global_position, 0.0, 40.0)
	EventSounds.play_at(get_tree(), AudioManager.ElevatorOpenDoor, door.global_position, 0.0, 40.0)
	anim.play("Take 001")
	await anim.animation_finished
	await get_tree().create_timer(3.0).timeout
	# if the player walked in meanwhile, leave it open for them
	if not is_instance_valid(el) or el.inside or el.up:
		return
	EventSounds.play_at(get_tree(), AudioManager.ElevatorCloseDoor, door.global_position, 0.0, 40.0)
	anim.play_backwards("Take 001")
