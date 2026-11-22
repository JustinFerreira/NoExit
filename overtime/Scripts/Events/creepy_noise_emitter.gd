## No Exit
## Overtime Studios
## Creepy Noise Emitter Event (COMMON - see GarageEvent)
## - When the director allows it, a creepy 3D sound plays as the player walks
##   by. Two kinds:
##     placed (in the scene, with its own AudioStreamPlayer3D) - plays from
##       its spot, as it always did
##     anywhere (put on every ceiling light by EventDirector, no player of
##       its own) - one of the placed ones' sounds, at random, from a spot
##       8-16 m away to the side or behind the player
##   All share the "creepy_noise" cooldown.

extends "res://Scripts/Events/GarageEvent.gd"

const EventSounds = preload("res://Scripts/Events/EventSounds.gd")

## Sound to play (replaces the AudioStreamPlayer3D's stream if set).
@export var sound: AudioStream

## How far from the player an "anywhere" one plays (metres).
const AWAY := Vector2(8.0, 16.0)

func _init() -> void:
	tier = Tier.COMMON
	kind = "creepy_noise"
	kind_cooldown = 90.0
	repeatable = true

func _ready() -> void:
	if sound != null and has_node("AudioStreamPlayer3D"):
		$AudioStreamPlayer3D.stream = sound

func _fire() -> void:
	if has_node("AudioStreamPlayer3D"):
		$AudioStreamPlayer3D.play()
		return
	var pool := _sounds()
	var p = PlayerManager.player
	if pool.is_empty() or not is_instance_valid(p):
		return
	EventSounds.play_at(get_tree(), pool.pick_random(), _spot_near(p), 0.0, 40.0, randf_range(0.9, 1.05))

## Every sound the placed emitters in this level use.
func _sounds() -> Array:
	var out := []
	for n in get_tree().current_scene.find_children("*", "AudioStreamPlayer3D", true, false):
		var owner_ev = n.get_parent()
		if owner_ev and owner_ev.get_script() == get_script() and n.stream and not out.has(n.stream):
			out.append(n.stream)
	return out

## Off to the side or behind the player (never straight ahead), on the nav
## mesh if it can find it there.
func _spot_near(p: Node3D) -> Vector3:
	var back: Vector3 = p.CAMERA.global_basis.z if "CAMERA" in p else Vector3.BACK
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var dir := back.rotated(Vector3.UP, randf_range(-1.9, 1.9))
	var want: Vector3 = p.global_position + dir * randf_range(AWAY.x, AWAY.y)
	var at: Vector3 = NavigationServer3D.map_get_closest_point(p.get_world_3d().navigation_map, want)
	if at.distance_to(want) > 4.0:
		at = want
	return at + Vector3.UP * 1.0
