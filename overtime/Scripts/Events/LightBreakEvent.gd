## No Exit
## Overtime Studios
## Light Break Event (COMMON - see GarageEvent)
## - When the director allows it, a ceiling light (group "Lights") shatters
##   as the player walks under it: glass breaking from the light, it goes
##   out for good (marked "broken" so a blackout doesn't relight it).
## - Every light in the garage gets one of these at load (EventDirector);
##   placed ones break the nearest working light above them.

extends "res://Scripts/Events/GarageEvent.gd"

## Only lights at most this far away sideways count (placed events).
@export var max_search_radius: float = 10.0
## The light this breaks (set for the per-light triggers; else the nearest).
var light: Node3D

func _init() -> void:
	tier = Tier.COMMON
	kind = "light_break"
	kind_cooldown = 60.0
	weight = 0.6

func can_fire() -> bool:
	return _target() != null

func _fire() -> void:
	var l := _target()
	if l == null:
		return
	l.set_meta("broken", true)
	HelperManager.set_light_panel_lit(l, false)
	# the glass breaks up there, not in the player's ears
	var snd := AudioStreamPlayer3D.new()
	snd.stream = AudioManager.GetGlassBreak()
	snd.bus = "SFX"
	snd.max_distance = 40.0
	l.add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)

## The light to break: ours, or the nearest unbroken one above (placed events).
func _target() -> Node3D:
	if light != null:
		return light if is_instance_valid(light) and not light.has_meta("broken") else null
	return get_closest_light_above()

func get_closest_light_above() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for l in get_tree().get_nodes_in_group("Lights"):
		if not (l is Node3D) or not is_instance_valid(l) or l.has_meta("broken"):
			continue
		var offset: Vector3 = l.global_position - global_position
		if offset.y <= 0.0:
			continue
		if Vector2(offset.x, offset.z).length() > max_search_radius:
			continue
		if offset.length() < best_dist:
			best_dist = offset.length()
			best = l
	return best
