## No Exit
## Overtime Studios
## Illusion (rogue mode, from RogueRun.ILLUSION_ROUND - RogueRun.illusions)
## - While a killer is coming for the player from behind (out of their view),
##   now and then a copy of it appears at the very edge of their view,
##   standing still and WAVING at them - to pull their eyes the wrong way
##   while the real one closes in.
## - It fades away and is gone if the player gets close to it, turns away
##   (it leaves the screen - say, to look behind them), or after a while.
## - Only something to look at: no AI, no collision, no sound, can't kill.
## - Made in the garage by RogueRun._setup_enemies when the round has them.

extends Node

const WaveModifier = preload("res://Scripts/Enemies/WaveModifier.gd")

## Seconds between illusions (random in this range).
const COOLDOWN := Vector2(35.0, 55.0)
## How far from the player it appears (garage units), just inside the edge
## of the view (degrees in from it).
const DISTANCE := Vector2(18.0, 26.0)
const EDGE_IN := 7.0
## A chasing killer this close (and out of view) can bring one on.
const CHASE_RANGE := 35.0
## It fades when the player is this close, or off screen this long, or after
## LIFETIME; fading takes FADE_TIME.
const TOO_CLOSE := 9.0
const OFF_SCREEN_FOR := 0.4
const LIFETIME := 10.0
const FADE_TIME := 0.8

var _cooldown := 20.0
var _check := 0.0
var _body: Node3D
var _alive := 0.0
var _off_screen := 0.0
var _fading := false

func _process(delta: float) -> void:
	if is_instance_valid(_body):
		_watch(delta)
		return
	_cooldown -= delta
	_check -= delta
	if _cooldown > 0.0 or _check > 0.0:
		return
	_check = 0.5
	var killer := _chasing_killer()
	if killer:
		_spawn(killer)

## A killer coming for the player from out of their view, or null.
func _chasing_killer() -> Node3D:
	var p = PlayerManager.player
	if not is_instance_valid(p) or PlayerManager.hiding or PlayerManager.dying or PlayerManager.MinigameMode:
		return null
	for e in get_tree().get_nodes_in_group("enemy"):
		if not ("behavior" in e) or e.killing or e.holding:
			continue
		var chasing: bool = e._locked_on if e.behavior == e.Behavior.HUNT else (not e._hanging_back and not e._lost_player())
		if not chasing or e.global_position.distance_to(p.global_position) > CHASE_RANGE:
			continue
		if e.on_player_screen(e.body_points()):
			continue
		return e
	return null

## A copy of `killer` - only to look at - at the edge of the player's view.
func _spawn(killer: Node3D) -> void:
	var p = PlayerManager.player
	var cam := get_viewport().get_camera_3d()
	if cam == null or killer.scene_file_path == "":
		return
	var at := _edge_spot(cam, p)
	if at == Vector3.INF:
		return
	_body = (load(killer.scene_file_path) as PackedScene).instantiate()
	_body.set_script(null)   # no AI: just the body
	for n in ["CollisionShape3D", "NavigationAgent3D", "Killer3DAudio", "VisibilityTimer", "StabbingAnimation", "FadeAnimation", "WalkingAnimation"]:
		var c := _body.get_node_or_null(n)
		if c:
			_body.remove_child(c)
			c.free()
	if _body is CollisionObject3D:
		_body.collision_layer = 0
		_body.collision_mask = 0
	get_tree().current_scene.add_child(_body)
	# the same size as the real one, facing the player
	var s: Vector3 = killer.global_basis.get_scale()
	var to_p: Vector3 = p.global_position - at
	to_p.y = 0.0
	var yaw := atan2(to_p.x, to_p.z)   # the killer model faces its +Z
	_body.global_transform = Transform3D(Basis(Vector3.UP, yaw).scaled(s), at)
	var anim := _body.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim and anim.has_animation("Idle"):
		anim.play("Idle")
	var sk := _body.get_node_or_null("Armature/Skeleton3D") as Skeleton3D
	if sk:
		var wave := WaveModifier.new()
		sk.add_child(wave)
	_alive = 0.0
	_off_screen = 0.0
	_fading = false

## Just inside the left or right edge of the view, on the player's floor,
## somewhere it can be seen.
func _edge_spot(cam: Camera3D, p: Node3D) -> Vector3:
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return Vector3.INF
	fwd = fwd.normalized()
	var aspect := cam.get_viewport().get_visible_rect().size.aspect()
	var half_h := rad_to_deg(atan(tan(deg_to_rad(cam.fov * 0.5)) * aspect))
	var map := p.get_world_3d().navigation_map
	var space := p.get_world_3d().direct_space_state
	for side in ([1.0, -1.0] if randf() < 0.5 else [-1.0, 1.0]):
		for k in 4:
			var dir := fwd.rotated(Vector3.UP, deg_to_rad((half_h - EDGE_IN) * side))
			var want: Vector3 = p.global_position + dir * randf_range(DISTANCE.x, DISTANCE.y)
			var at := NavigationServer3D.map_get_closest_point(map, want)
			if absf(at.y - p.global_position.y) > 1.2 or at.distance_to(want) > 4.0:
				continue
			at = HelperManager.floor_at(p.get_world_3d(), at, [p.get_rid()])
			var head := at + Vector3.UP * 3.0
			if cam.is_position_behind(head):
				continue
			var q := PhysicsRayQueryParameters3D.create(cam.global_position, head, 0xFFFFFFFF, [p.get_rid()])
			if not space.intersect_ray(q).is_empty():
				continue
			return at
	return Vector3.INF

## While it's there: fades when the player comes close, looks away, or after
## a while.
func _watch(delta: float) -> void:
	_alive += delta
	var p = PlayerManager.player
	var cam := get_viewport().get_camera_3d()
	if _fading or not is_instance_valid(p) or cam == null:
		return
	var head := _body.global_position + Vector3.UP * 3.0
	var on_screen := not cam.is_position_behind(head) and cam.get_viewport().get_visible_rect().has_point(cam.unproject_position(head))
	_off_screen = 0.0 if on_screen else _off_screen + delta
	var near: bool = Vector2(p.global_position.x - _body.global_position.x, p.global_position.z - _body.global_position.z).length() < TOO_CLOSE
	if near or _off_screen > OFF_SCREEN_FOR or _alive > LIFETIME:
		_fade()

func _fade() -> void:
	_fading = true
	var tw := create_tween().set_parallel(true)
	for m in _body.find_children("*", "GeometryInstance3D", true, false):
		tw.tween_property(m, "transparency", 1.0, FADE_TIME)
	await tw.finished
	if is_instance_valid(_body):
		_body.queue_free()
	_body = null
	_cooldown = randf_range(COOLDOWN.x, COOLDOWN.y)
