## No Exit
## Overtime Studios
## Ambient Sound Event (COMMON - see GarageEvent)
## - A sound from somewhere you can't see, as the player walks along:
##     FOOTSTEPS  - a few footsteps somewhere behind the player, then nothing
##     DOOR_SLAM  - a car door slams somewhere far off on the same floor
## - Hung under the ceiling lights at load (EventDirector), so they're
##   everywhere and the director decides when.

extends "res://Scripts/Events/GarageEvent.gd"

const EventSounds = preload("res://Scripts/Events/EventSounds.gd")
const STEPS := [
	preload("res://Assets/Audio/SFX/Footsteps/LeftStep1.wav"), preload("res://Assets/Audio/SFX/Footsteps/RightStep1.wav"),
	preload("res://Assets/Audio/SFX/Footsteps/LeftStep2.wav"), preload("res://Assets/Audio/SFX/Footsteps/RightStep2.wav"),
	preload("res://Assets/Audio/SFX/Footsteps/LeftStep3.wav"), preload("res://Assets/Audio/SFX/Footsteps/RightStep3.wav"),
]

enum Mode { FOOTSTEPS, DOOR_SLAM }
var mode: Mode = Mode.FOOTSTEPS

func _init() -> void:
	tier = Tier.COMMON
	repeatable = true

## Picks the mode (and with it the kind and cooldown) - call before it's used.
func setup(m: Mode) -> void:
	mode = m
	kind = "footsteps_behind" if m == Mode.FOOTSTEPS else "door_slam"
	kind_cooldown = 140.0 if m == Mode.FOOTSTEPS else 100.0
	weight = 0.7
	# fake footsteps behind you only work if they can't be his real ones
	min_killer_distance = 30.0 if m == Mode.FOOTSTEPS else 0.0

func _fire() -> void:
	var p = PlayerManager.player
	if not is_instance_valid(p):
		return
	var back: Vector3 = p.HEAD.global_basis.z
	back.y = 0.0
	back = back.normalized()
	if mode == Mode.FOOTSTEPS:
		# 4-6 steps, 7-10 m behind, coming a little closer, then they stop
		var dist := randf_range(7.0, 10.0)
		var count := randi_range(4, 6)
		var side := back.cross(Vector3.UP) * randf_range(-2.0, 2.0)
		for i in count:
			if not is_instance_valid(p):
				return
			var at: Vector3 = p.global_position + back * (dist - i * 0.5) + side + Vector3.UP * 0.2
			EventSounds.play_at(get_tree(), STEPS[i % STEPS.size()], at, -6.0, 30.0, randf_range(0.9, 1.05))
			await get_tree().create_timer(0.52).timeout
	else:
		var dir := back.rotated(Vector3.UP, randf_range(-1.2, 1.2))
		var at: Vector3 = p.global_position + dir * randf_range(25.0, 40.0) + Vector3.UP * 1.0
		EventSounds.play_at(get_tree(), AudioManager.CarDoorClose, at, 2.0, 80.0, randf_range(0.85, 1.0))
