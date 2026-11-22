## No Exit
## Overtime Studios
## Killer Behind Event (COMMON - comes back after kind_cooldown, see GarageEvent)
## - One of the enemies in the level (picked at random - the killer, or any
##   other) is moved, unseen, to a spot behind the player, out of sight in the
##   fog, much closer than it was. One soft footstep where it now stands is
##   the only clue. Turn round and it's there.
## - Only when it can happen unseen: the enemy must be off the player's screen
##   where it is now, and the new spot behind them out of view too.
## - Put on some of the ceiling lights at load (EventDirector).

extends "res://Scripts/Events/GarageEvent.gd"

const EventSounds = preload("res://Scripts/Events/EventSounds.gd")
const STEP := preload("res://Assets/Audio/SFX/Footsteps/LeftStep2.wav")

## How far behind the player it turns up (metres, random in this range).
const BEHIND := Vector2(9.0, 14.0)

func _init() -> void:
	tier = Tier.COMMON
	kind = "killer_behind"
	kind_cooldown = 180.0
	weight = 0.6

## Enemies that could do it: switched on, further off than they'd end up,
## and not on the player's screen.
func _candidates() -> Array:
	var out := []
	var p = PlayerManager.player
	if PlayerManager.no_enemy or PlayerManager.dying or PlayerManager.hiding or not is_instance_valid(p):
		return out
	for k in get_tree().get_nodes_in_group("enemy"):
		if not (k is Node3D) or not k.is_inside_tree() or not k.is_visible_in_tree():
			continue
		if k.global_position.distance_to(p.global_position) <= BEHIND.y + 2.0:
			continue
		if k.has_method("on_player_screen") and k.on_player_screen(k.body_points()):
			continue
		out.append(k)
	return out

func can_fire() -> bool:
	return not _candidates().is_empty() and _spot_behind() != Vector3.INF

## A spot on the nav mesh behind the player that they can't see.
func _spot_behind() -> Vector3:
	var p = PlayerManager.player
	if not is_instance_valid(p):
		return Vector3.INF
	var cam: Camera3D = p.CAMERA
	var back: Vector3 = cam.global_basis.z
	back.y = 0.0
	if back.length() < 0.01:
		return Vector3.INF
	back = back.normalized()
	var map_rid: RID = p.get_world_3d().navigation_map
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	for i in 12:
		var dir := back.rotated(Vector3.UP, randf_range(-0.6, 0.6))
		var want: Vector3 = p.global_position + dir * randf_range(BEHIND.x, BEHIND.y)
		var at: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, want)
		if at.distance_to(want) > 3.0 or absf(at.y - p.global_position.y) > 1.5:
			continue   # off the deck / through a wall
		var head := at + Vector3.UP * 1.6
		if not cam.is_position_behind(head):
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(cam.global_position, head, 0xFFFFFFFF, [p.get_rid()]))
			if hit.is_empty():
				continue   # they'd see it appear
		return at
	return Vector3.INF

func _fire() -> void:
	var list := _candidates()
	if list.is_empty():
		return
	var k: Node3D = list.pick_random()
	var at := _spot_behind()
	if at == Vector3.INF:
		return
	k.global_position = at
	if "velocity" in k:
		k.velocity = Vector3.ZERO
	if k.has_method("face_point"):
		k.face_point(PlayerManager.player.global_position)
	# one soft step, right where it now stands
	await get_tree().create_timer(randf_range(0.4, 0.9)).timeout
	EventSounds.play_at(get_tree(), STEP, at + Vector3.UP * 0.2, -10.0, 25.0, 0.9)
