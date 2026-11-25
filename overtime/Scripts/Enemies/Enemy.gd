## No Exit
## Overtime Studios
## Last updated 10/19/26 by Justin Ferreira
## Enemy Script
## - parent class for every enemy (Killer, WanderingEnemy, WeepingAngel,
##   DisappearingEnemy). To make a new enemy: put a CharacterBody3D in a
##   scene (add a NavigationAgent3D child if it walks), attach a script that
##   starts with "extends Enemy", and override the hooks you need:
##     _enemy_ready()          - your setup (instead of _ready)
##     _enemy_physics(delta)   - your per-frame behaviour (instead of
##                               _physics_process); move_and_slide() is
##                               called for you afterwards
##     target_position(pos)    - levels call this with the player position
##     _before_kill_turn()     - runs when the enemy catches the player
##     _current_kill_distance()- how far in front of the player the kill
##                               happens (default: kill_distance)
##     _play_kill()            - the kill itself (default: a lunge at the
##                               player's face, then game over)
##     play_drag_out(time)     - pulling a hidden player out (default: stand)
##     _after_grab()           - the player broke free of a grab (rogue
##                               mode): undo what _before_kill_turn set up
## What you get for free:
##   player / camera           - found automatically (retried until found)
##   nav                       - the NavigationAgent3D child, if there is one
##   set_nav_target(pos)       - path-finding that only recalculates a few
##                               times a second, not every frame
##   move_along_nav(speed)     - walk along the path, facing where it goes
##   face_direction(dir)       - turn to face a direction (yaw only)
##   apply_gravity(delta)      - done for you while use_gravity is on
##   can_see_player()          - the enemy's own vision cone + line of sight
##   player_can_see_me(points) - is any of these points in the player's view cone
##   on_player_screen(points)  - stricter: on the actual screen (with a margin)
##   body_grid_points()        - points across the whole body, for those
##   kill()                    - the shared "caught the player" sequence
##   hiding spots              - HidingSpot tells it when the player hides
##                               (player_hid / player_unhid); if it saw them
##                               it walks to the spot, lines up square to the
##                               opening and drags them out

extends CharacterBody3D
class_name Enemy

@export_group("Movement")
## Default speed for move_along_nav().
@export var move_speed: float = 2.0
## Fall when off the floor (and stick to it when on it).
@export var use_gravity: bool = true
## How quickly velocity reaches its new value each physics tick (0-1, 1 = instant).
@export_range(0.0, 1.0) var acceleration: float = 0.25
## Seconds between path recalculations while the target keeps moving.
@export var repath_interval: float = 0.25
## Recalculate straight away if the target jumps farther than this.
@export var repath_distance: float = 2.0
## Ledges up to this high (curbs, the elevator's door lip) are stepped up
## onto instead of blocking it, like the player does.
@export var step_height: float = 0.6
## Which way the model faces: true = its +Z is the front (Mixamo/most of
## our models), false = Godot's usual -Z.
@export var model_faces_plus_z: bool = true

@export_group("Vision")
## How far the enemy can see the player (can_see_player).
@export var sight_range: float = 20.0
## Half-angle of the enemy's vision cone, in degrees.
@export var sight_fov_degrees: float = 60.0
## Height above the enemy's origin its eyes are (and the player's aim point).
@export var sight_height_offset: float = 1.0

@export_group("Kill")
## Touching the player kills them (Player calls kill()). Off = harmless.
@export var can_kill_player: bool = true
## Catches the player when this close (feet to feet, sideways) and at about
## the same height - bodies bump before the player's touch trigger overlaps.
## 0 = only the touch trigger.
@export var kill_reach: float = 1.6
## Height of the face the player is turned to look at when caught.
@export var face_height: float = 1.8
## The player's view tilts this far below the face while being caught.
@export var kill_look_down_degrees: float = 35.0
## When it catches the player it steps to this distance in front of them (closer only
## if a wall is in the way), so every death is seen from the same angle. 0 = stay put.
@export var kill_distance: float = 0.0
## Seconds the turn to face the killer (and the step to kill_distance) takes.
@export var kill_turn_time: float = 0.5
## Default kill only: seconds after the turn before the game over screen.
@export var game_over_delay: float = 2.0

@export_group("Hiding")
## If this enemy SEES the player get into a hiding spot: the chance (0-1)
## that it comes over, drags them out and kills them. Otherwise - or if the
## player hid without being seen - it loses track of them.
@export_range(0.0, 1.0) var catch_seen_hiding_chance: float = 0.75

var player: Node3D = null
var camera: Camera3D = null
var nav: NavigationAgent3D = null
## The HidingSpot it saw the player get into and is coming for (null = none).
var hunting_spot: Node = null
## Where it lost track of a hidden player (it goes there and searches).
var _last_known: Vector3 = Vector3.INF

## True from kill() on: the enemy stands still and keeps facing the player
## (its walking would otherwise turn it toward its nav target mid-stab).
var killing := false
## True while it drags a hidden player out (HidingSpot.drag_out): stands still
## facing the spot until kill() takes over.
var holding := false
## How close the navigation walks to a hiding spot's grab position.
const GRAB_NAV_STOP := 0.35
## Wedged on its way to a hiding spot (see _check_catch_hidden_player): no
## progress for this long, within this distance, and it reaches in from there.
const GRAB_STALL_TIME := 1.5
const GRAB_STALL_RANGE := 9.0
var _grab_best := INF
var _grab_stall := 0.0
var _nav_stop_distance := -1.0
var _nav_path_distance := 1.0
var _nav_hunting := false   # nav currently set up for walking to a grab spot
var _passthrough_timer := 0.0

var _nav_target: Vector3 = Vector3.INF
var _pending_target: Vector3
var _nav_target_pending := false
var _half_width := -1.0   # body half-width, measured once (body_grid_points)
var _repath_timer := 0.0

func _ready() -> void:
	add_to_group("enemy")
	for child in get_children():
		if child is NavigationAgent3D:
			nav = child
			break
	_find_player()
	_enemy_ready()

func _physics_process(delta: float) -> void:
	if player == null:
		_find_player()
	if use_gravity:
		apply_gravity(delta)
	_update_passthrough(delta)
	if _stun_left > 0.0:
		_stunned_physics(delta)
		return
	if killing or holding:
		velocity.x = 0.0
		velocity.z = 0.0
		if killing and PlayerManager.player:
			face_point(PlayerManager.player.global_position)
		move_and_slide()
		return
	# a cutscene (the elevator ride) has the player: everyone stands still
	if PlayerManager.cutscene:
		velocity.x = 0.0
		velocity.z = 0.0
		_cutscene_pose()
		move_and_slide()
		return
	_update_nav_target(delta)
	_enemy_physics(delta)
	_hold_off_if_no_kill()
	_check_reach_kill()
	var wish := Vector3(velocity.x, 0.0, velocity.z)
	var before := global_position
	move_and_slide()
	_step_up(wish, global_position - before, delta)
	_check_stuck(wish, global_position - before, delta)
	_check_catch_hidden_player()


## ---------------------------------------------------------------------
## Stunned (a shield saved the player - see kill())
## ---------------------------------------------------------------------
## Knocked back away from the player, then dazed on the spot: no moving, no
## catching anyone. Played on the model itself (any enemy, any rig): a jolt
## back on the hit, a stagger as it slides back, then a groggy sway with its
## walk frozen and a few sparks circling its head, then it straightens up.

## Seconds it's out of it (knock-back included): RogueRun.stun_time(), random
## each time - shorter in the harder rounds (2 to 30 seconds).
var _stun_total := 3.0
## Knock-back: how far (in its own heights) and how long it slides.
const STUN_PUSH := 1.3
const STUN_PUSH_TIME := 0.45
const STUN_RECOVER := 0.45   # straightening up at the end

var _stun_left := 0.0
var _stun_dir := Vector3.ZERO   # flat, away from the player
var _stun_speed := 0.0
var _stun_pose: Dictionary = {}   # visual child -> its transform before
var _stun_anims: Dictionary = {}  # AnimationPlayer -> its speed before
var _stun_fx: Node3D

func is_stunned() -> bool:
	return _stun_left > 0.0

## Stuns it, knocked away from `from` (the player), for `time` seconds
## (-1 = RogueRun.stun_time(), a shield's stun).
func stun_from(from: Vector3, time: float = -1.0) -> void:
	var d := global_position - from
	d.y = 0.0
	_stun_dir = d.normalized() if d.length() > 0.01 else global_basis.z.normalized()
	_stun_speed = 2.0 * STUN_PUSH * body_height() / STUN_PUSH_TIME   # (slows to 0 over the push)
	if _stun_left <= 0.0:
		_stun_pose.clear()
		for c in get_children():
			if c is Node3D and not (c is CollisionShape3D or c is NavigationAgent3D or c is AudioStreamPlayer3D):
				_stun_pose[c] = c.transform
		_stun_anims.clear()
		for ap in find_children("*", "AnimationPlayer", true, false):
			_stun_anims[ap] = ap.speed_scale
	_stun_total = RogueRun.stun_time() if time < 0.0 else maxf(time, STUN_PUSH_TIME + STUN_RECOVER)
	_stun_left = _stun_total
	AudioManager.play_sound(AudioManager.HeavyDamage, -4.0)
	_make_stun_fx()

func _stunned_physics(delta: float) -> void:
	_stun_left = maxf(_stun_left - delta, 0.0)
	var t := _stun_total - _stun_left   # time since the hit
	# knock-back: fast, slowing to a stop (walls stop it)
	_stun_speed = move_toward(_stun_speed, 0.0, delta * _stun_speed_decel())
	velocity.x = _stun_dir.x * _stun_speed
	velocity.z = _stun_dir.z * _stun_speed
	move_and_slide()
	# the walk frozen while it's out of it
	for ap in _stun_anims:
		if is_instance_valid(ap):
			ap.speed_scale = 0.0
	# the pose: lean back (away from the player) and sway
	var back := 0.0
	var side := 0.0
	if t < 0.12:
		back = lerpf(0.0, 28.0, t / 0.12)                       # the jolt
	elif t < STUN_PUSH_TIME + 0.2:
		back = lerpf(28.0, 16.0, (t - 0.12) / (STUN_PUSH_TIME + 0.08))   # staggering back
	else:
		var w := t - STUN_PUSH_TIME - 0.2
		back = 12.0 + sin(w * 3.1) * 6.0                       # groggy sway
		side = sin(w * 2.3) * 8.0
	if _stun_left < STUN_RECOVER:
		var k := _stun_left / STUN_RECOVER   # straightening up
		back *= k
		side *= k
	_pose_stunned(back, side)
	if is_instance_valid(_stun_fx):
		# over its head, wherever the lean has put it
		var lean := Basis(Vector3.UP.cross(_stun_dir).normalized(), deg_to_rad(back)) * Basis(_stun_dir, deg_to_rad(side))
		_stun_fx.global_position = global_position + lean * (Vector3.UP * body_height() * 1.05)
		_stun_fx.rotate_y(delta * 4.0)
	if _stun_left <= 0.0:
		_end_stun()

func _stun_speed_decel() -> float:
	return 2.0 * STUN_PUSH * body_height() / (STUN_PUSH_TIME * STUN_PUSH_TIME)

## Tips the model (about its feet): `back` degrees away from the player,
## `side` degrees across.
func _pose_stunned(back: float, side: float) -> void:
	var inv := global_basis.orthonormalized().inverse()
	var away: Vector3 = inv * Vector3.UP.cross(_stun_dir)          # tips the top along _stun_dir
	var across: Vector3 = inv * _stun_dir                            # tips it sideways
	var tilt := Basis(away.normalized(), deg_to_rad(back)) * Basis(across.normalized(), deg_to_rad(side))
	for c in _stun_pose:
		if is_instance_valid(c):
			c.transform = Transform3D(tilt, Vector3.ZERO) * _stun_pose[c]

func _end_stun() -> void:
	for c in _stun_pose:
		if is_instance_valid(c):
			c.transform = _stun_pose[c]
	_stun_pose.clear()
	for ap in _stun_anims:
		if is_instance_valid(ap):
			ap.speed_scale = _stun_anims[ap]
	_stun_anims.clear()
	velocity = Vector3.ZERO
	if is_instance_valid(_stun_fx):
		_stun_fx.queue_free()

## A few faint sparks circling its head while it's dazed.
func _make_stun_fx() -> void:
	if is_instance_valid(_stun_fx):
		return
	_stun_fx = Node3D.new()
	_stun_fx.name = "StunSparks"
	get_tree().current_scene.add_child(_stun_fx)
	var r := body_height() * 0.16
	var glow := Gradient.new()
	glow.colors = PackedColorArray([Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.8, 0.3, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = glow
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * body_height() * 0.07
	for i in 4:
		var m := MeshInstance3D.new()
		m.mesh = quad
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * i / 4.0
		m.position = Vector3(cos(a) * r, sin(a * 2.0) * r * 0.15, sin(a) * r)
		_stun_fx.add_child(m)

## ---------------------------------------------------------------------
## Hiding (see HidingSpot)
## ---------------------------------------------------------------------

## HidingSpot calls this when the player gets in. `seen` = this enemy saw
## them do it.
func player_hid(spot: Node, seen: bool) -> void:
	if seen and randf() < catch_seen_hiding_chance:
		hunting_spot = spot
	else:
		hunting_spot = null
		_last_known = spot.hidden_from_position()

## HidingSpot calls this once the player is back out.
func player_unhid() -> void:
	hunting_spot = null
	_last_known = Vector3.INF

## True while it's on its way to drag a hidden player out.
func is_hunting_hidden_player() -> bool:
	return PlayerManager.hiding and is_instance_valid(hunting_spot)

## What to chase instead of the player's real position: normally the player;
## while they hide, the spot it saw them use, or where it lost them.
func chase_target(player_position: Vector3) -> Vector3:
	if not PlayerManager.hiding:
		return player_position
	if is_instance_valid(hunting_spot):
		return hunting_spot.grab_position()
	return _last_known if _last_known != Vector3.INF else global_position

## Runs every physics tick: while hunting a hidden player, walks to the
## spot's grab position and starts the grab once it's there.
func _check_catch_hidden_player() -> void:
	var hunting := is_hunting_hidden_player()
	# walk right up to the grab spot instead of stopping the usual distance short,
	# and follow the path closely (hiding spots tend to be in tight corners)
	if nav and hunting != _nav_hunting:
		if _nav_stop_distance < 0.0:
			_nav_stop_distance = nav.target_desired_distance
			_nav_path_distance = nav.path_desired_distance
		_nav_hunting = hunting
		nav.target_desired_distance = GRAB_NAV_STOP if hunting else _nav_stop_distance
		nav.path_desired_distance = minf(0.3, _nav_path_distance) if hunting else _nav_path_distance
	if not hunting:
		_grab_best = INF
		_grab_stall = 0.0
		return
	var g: Vector3 = hunting_spot.grab_position()
	var d := Vector2(global_position.x - g.x, global_position.z - g.z).length()
	# right there - or the path ended near it - and no wall in between: line up from here
	var close := d <= GRAB_NAV_STOP + 0.25
	var stuck := nav != null and nav.is_navigation_finished() and d < 2.5
	# wedged on the way (a big enemy in a narrow gap between parked cars - the
	# nav mesh is made for a slimmer body): no real progress for a while,
	# close by - it reaches in from here
	if d < _grab_best - 0.25:
		_grab_best = d
		_grab_stall = 0.0
	else:
		_grab_stall += get_physics_process_delta_time()
	var wedged := _grab_stall > GRAB_STALL_TIME and d < GRAB_STALL_RANGE
	if wedged:
		_grab_best = INF
		_grab_stall = 0.0
	elif not (close or stuck) or not _clear_line_to(g, hunting_spot):
		return
	var spot := hunting_spot
	hunting_spot = null
	_line_up_and_grab(spot)

## Nothing solid between here and `point` at knee and chest height (so lining
## up never slides through a wall). Ignores itself and the spot's click box.
func _clear_line_to(point: Vector3, spot: Node) -> bool:
	var ignore: Array[RID] = [get_rid()]
	if spot is CollisionObject3D:
		ignore.append(spot.get_rid())
	if is_instance_valid(player) and player is CollisionObject3D:
		ignore.append(player.get_rid())
	for h: float in [0.5, 1.2]:
		var from: Vector3 = global_position + Vector3.UP * h
		var to := Vector3(point.x, global_position.y + h, point.z)
		var query := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, ignore)
		query.collide_with_areas = false
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true

## Steps onto the spot's grab position and turns square to its opening (so
## the reach-in lines up from any approach angle), then drags the player out.
func _line_up_and_grab(spot: Node) -> void:
	holding = true
	var g: Vector3 = spot.grab_position()
	var to_spot: Vector3 = -spot.out_direction()
	var from_pos := global_position
	var from_dir := global_basis.z if model_faces_plus_z else -global_basis.z
	from_dir.y = 0.0
	from_dir = from_dir.normalized()
	var dist := Vector2(g.x - from_pos.x, g.z - from_pos.z).length()
	var turn := from_dir.angle_to(to_spot)
	var time := clampf(maxf(dist / maxf(move_speed, 0.5), turn / deg_to_rad(300.0)), 0.15, 2.5)   # (a long one when it was wedged further off)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		global_position = Vector3(lerpf(from_pos.x, g.x, t), global_position.y, lerpf(from_pos.z, g.z, t))
		face_direction(from_dir.slerp(to_spot, t) if from_dir.dot(to_spot) > -0.999 else Basis(Vector3.UP, PI * t) * from_dir),
		0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	holding = false
	# yanks the player out of the spot (if they're still in it), then calls kill()
	# (being dragged out always kills, whatever the round)
	if is_instance_valid(spot):
		_dragging_out = true
		spot.drag_out(self)   # does nothing if they already got out

## True from reaching into a hiding spot until the kill it leads to.
var _dragging_out := false

## When it may not kill the player yet (rogue mode's early rounds, or a
## minigame early on - RogueRun.kill_allowed), it comes no closer than this
## (metres, times its size): it stands there, looming, facing them, until
## they stand still too long or get trapped.
const HOLD_OFF := 3.5
const HOLD_OFF_SLACK := 2.0
var _looming := false

func _hold_off_if_no_kill() -> void:
	if not RogueRun.active or RogueRun.kill_allowed() or not is_instance_valid(player) or is_hunting_hidden_player():
		return
	var d := global_position - player.global_position
	var far := Vector2(d.x, d.z).length()
	var s := global_basis.get_scale().y
	# stops at HOLD_OFF, sets off again only once they're a good bit further
	# (no stop-start shuffling while they edge about)
	if far < HOLD_OFF * s or (_looming and far < (HOLD_OFF + HOLD_OFF_SLACK) * s):
		_looming = true
		velocity.x = 0.0
		velocity.z = 0.0
		turn_toward(player.global_position - global_position, get_physics_process_delta_time())
	else:
		_looming = false

## ---------------------------------------------------------------------
## Getting unstuck: trying to walk but hardly moving (caught on a corner, a
## car, a prop) for STUCK_TIME, it re-plans its path and steps sideways for
## a moment.
## ---------------------------------------------------------------------
const STUCK_TIME := 0.6
const SIDESTEP_TIME := 0.6
var _stuck_for := 0.0
var _sidestep := Vector3.ZERO
var _sidestep_time := 0.0

func _check_stuck(wish: Vector3, moved: Vector3, delta: float) -> void:
	_sidestep_time = maxf(_sidestep_time - delta, 0.0)
	var want := wish.length()
	if want < 0.8 or Vector2(moved.x, moved.z).length() > want * delta * 0.35:
		_stuck_for = 0.0
		return
	_stuck_for += delta
	if _stuck_for < STUCK_TIME:
		return
	_stuck_for = 0.0
	_sidestep = wish.normalized().cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
	# away from whatever it's pressing on, if it knows
	if get_slide_collision_count() > 0:
		var n := get_slide_collision(0).get_normal()
		n.y = 0.0
		if n.length() > 0.1:
			_sidestep = (n.normalized() + _sidestep).normalized()
	_sidestep_time = SIDESTEP_TIME
	if _nav_target != Vector3.INF and nav:
		_apply_nav_target(_nav_target)

## Hooks - override these in your enemy.
func _enemy_ready() -> void:
	pass

func _enemy_physics(_delta: float) -> void:
	pass

## Levels call this on every enemy with the player's position.
## Default: chase that position.
func target_position(target: Vector3) -> void:
	set_nav_target(target)

func _find_player() -> void:
	if PlayerManager.player and is_instance_valid(PlayerManager.player):
		player = PlayerManager.player
		camera = player.CAMERA

## ---------------------------------------------------------------------
## Movement
## ---------------------------------------------------------------------

## Falls when in the air; pressed down a little when on the floor so it sticks.
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y -= 2.0

## set_nav_target
## Where to walk to. Safe to call every frame: the path is only rebuilt
## every repath_interval seconds, or right away if the target jumped.
func set_nav_target(target: Vector3) -> void:
	if nav == null:
		return
	if _nav_target == Vector3.INF or target.distance_to(_nav_target) > repath_distance:
		_apply_nav_target(target)
	else:
		_pending_target = target
		_nav_target_pending = true

func _update_nav_target(delta: float) -> void:
	_repath_timer -= delta
	if _nav_target_pending and _repath_timer <= 0.0:
		_apply_nav_target(_pending_target)

func _apply_nav_target(target: Vector3) -> void:
	_nav_target = target
	_nav_target_pending = false
	_repath_timer = repath_interval
	nav.target_position = target

## The target the path is (or soon will be) heading to.
func get_nav_target() -> Vector3:
	if _nav_target_pending:
		return _pending_target
	return nav.target_position if nav else global_position

## move_along_nav
## Steers velocity along the current path and faces the way it's going.
## Returns false if there's nowhere left to go.
func move_along_nav(speed: float = move_speed) -> bool:
	if nav == null or nav.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0.0, acceleration * speed)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * speed)
		return false
	var direction := nav.get_next_path_position() - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.000001:
		return true
	direction = direction.normalized()
	# stepping round something it got stuck on (see _check_stuck)
	if _sidestep_time > 0.0:
		direction = (direction + _sidestep).normalized()
	# turns smoothly towards where it's going instead of snapping round
	turn_toward(direction, get_physics_process_delta_time())
	var target_velocity := direction * speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * maxf(speed, 1.0))
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * maxf(speed, 1.0))
	return true

## face_direction
## Turns to face a world direction, yaw only (never tilts, never fails
## on straight up/down directions).
func face_direction(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.000001:
		return
	flat = flat.normalized()
	# look_at() points -Z at the target; flip it for models whose front is +Z.
	var look_point := global_position + (-flat if model_faces_plus_z else flat)
	look_at(look_point, Vector3.UP)

## turn_toward
## Like face_direction, but turning at most TURN_RATE a second (walking).
const TURN_RATE := 540.0
func turn_toward(direction: Vector3, delta: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.000001:
		return
	var want := atan2(flat.x, flat.z) if model_faces_plus_z else atan2(-flat.x, -flat.z)
	var r := global_rotation
	r.y = rotate_toward(r.y, want, deg_to_rad(TURN_RATE) * delta)
	global_rotation = r

## face_point
## Turns (yaw only) to face a world position.
func face_point(point: Vector3) -> void:
	face_direction(point - global_position)

## How far the enemy still has to walk along its path to the nav target.
func path_distance() -> float:
	if nav == null:
		return 0.0
	var path := nav.get_current_navigation_path()
	if path.is_empty():
		return global_position.distance_to(get_nav_target())
	var i := clampi(nav.get_current_navigation_path_index(), 0, path.size() - 1)
	var total := global_position.distance_to(path[i])
	for j in range(i, path.size() - 1):
		total += path[j].distance_to(path[j + 1])
	return total

## ---------------------------------------------------------------------
## Vision
## ---------------------------------------------------------------------

## can_see_player
## The enemy's own eyes: player in range, inside the vision cone, and not
## behind a wall.
func can_see_player() -> bool:
	if not is_instance_valid(player):
		return false
	if PlayerManager.hidden_from_enemies:
		return false   # tucked into a HidingSpot
	var eye := global_position + Vector3.UP * sight_height_offset
	var aim := player.global_position + Vector3.UP * sight_height_offset
	# a hiding player's body is tucked away oddly: look for their head instead
	if PlayerManager.hiding and "CAMERA" in player and player.CAMERA:
		aim = player.CAMERA.global_position
	if eye.distance_to(aim) > sight_range:
		return false
	var forward := global_basis.z if model_faces_plus_z else -global_basis.z
	forward.y = 0.0
	var to_player := aim - eye
	to_player.y = 0.0
	if forward.length_squared() > 0.0 and to_player.length_squared() > 0.0:
		if rad_to_deg(forward.angle_to(to_player)) > sight_fov_degrees:
			return false
	var ignore: Array[RID] = [get_rid()]
	# the click box of the hiding spot the player is peeking out of isn't a wall
	var spot = PlayerManager.current_hiding_spot
	if PlayerManager.hiding and spot is CollisionObject3D:
		ignore.append(spot.get_rid())
	var query := PhysicsRayQueryParameters3D.create(eye, aim, 0xFFFFFFFF, ignore)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == player

## player_can_see_me
## True if any of the given world points is inside the player's view cone
## (half-angle fov_degrees, within max_range) with nothing in between.
## Pass several points (feet ... head) so peeking round a corner counts.
func player_can_see_me(points: Array, fov_degrees: float = 80.0, max_range: float = INF) -> bool:
	var cam := _view_camera()
	if cam == null:
		return false
	var cam_pos := cam.global_position
	var cam_forward := -cam.global_basis.z
	var cos_fov := cos(deg_to_rad(fov_degrees))
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if player is CollisionObject3D:
		exclude.append(player.get_rid())
	for p in points:
		var to_point: Vector3 = p - cam_pos
		if to_point.length() > max_range:
			continue
		if to_point.normalized().dot(cam_forward) < cos_fov:
			continue
		if _clear_view(space, cam_pos, p, exclude):
			return true
	return false

## on_player_screen
## Stricter than player_can_see_me: true if any point is on the player's
## actual screen (grown by `margin`, a fraction of its size, so the very
## edge counts too) with a clear line to it. For enemies that must react
## the moment any bit of them is in view (the weeping angel).
func on_player_screen(points: Array, margin: float = 0.05, max_range: float = INF) -> bool:
	var cam := _view_camera()
	if cam == null:
		return false
	var cam_pos := cam.global_position
	var rect := cam.get_viewport().get_visible_rect()
	rect = rect.grow_individual(rect.size.x * margin, rect.size.y * margin, rect.size.x * margin, rect.size.y * margin)
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if player is CollisionObject3D:
		exclude.append(player.get_rid())
	for p in points:
		if cam_pos.distance_to(p) > max_range or cam.is_position_behind(p):
			continue
		if not rect.has_point(cam.unproject_position(p)):
			continue
		if _clear_view(space, cam_pos, p, exclude):
			return true
	return false

## Nothing (but this enemy) between the camera and the point. A hit just
## short of the point counts as clear too, so a railing or the edge of a
## wall right next to the body doesn't hide it.
func _clear_view(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, exclude)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	return hit.is_empty() or hit.collider == self or (hit.position as Vector3).distance_to(to) < 0.3

## Points across the whole body - up it (fractions of body_height()) and out
## to both sides - so an arm or shoulder in view counts, not just the middle.
func body_grid_points(fractions: Array = [0.03, 0.15, 0.28, 0.41, 0.54, 0.67, 0.8, 0.9, 1.0]) -> Array:
	if _half_width < 0.0:
		var box := AABB()
		var first := true
		for m in find_children("*", "MeshInstance3D", true, false):
			if m.mesh == null or not m.is_visible_in_tree():
				continue
			var a: AABB = global_transform.affine_inverse() * (m.global_transform * m.get_aabb())
			box = a if first else box.merge(a)
			first = false
		_half_width = maxf(box.size.x, box.size.z) * 0.4 if not first else 0.4
		# skinned meshes can report a tiny box: at least a person's shoulders
		_half_width = maxf(_half_width, body_height() * 0.12)
	var side: Vector3 = camera.global_basis.x if is_instance_valid(camera) else global_basis.x.normalized()
	side.y = 0.0
	side = side.normalized() * _half_width
	var out := []
	for p in body_points(fractions):
		out.append(p)
		out.append(p + side)
		out.append(p - side)
	return out

## Points up the enemy's body (fractions of its height, feet to the top of
## its head), for player_can_see_me / on_player_screen.
func body_points(fractions: Array = [0.17, 0.4, 0.55, 0.8, 0.95]) -> Array:
	var h := body_height()
	var out := []
	for f in fractions:
		out.append(global_position + Vector3.UP * (h * f))
	return out

## Every bone of its visible skeleton(s), in world space - points right on
## the model (head, hat, hands, fingers), so any bit of it peeking out from
## behind something counts as seen.
func bone_points() -> Array:
	var out := []
	for sk in find_children("*", "Skeleton3D", true, false):
		if not sk.is_visible_in_tree():
			continue
		for b in sk.get_bone_count():
			out.append(sk.global_transform * sk.get_bone_global_pose(b).origin)
	return out

## How tall the enemy really is (feet to the top of its head - a bit above
## the face, for a hat). From its head bone, so a model scaled inside its
## scene is measured right (face_height alone can be far off).
func body_height() -> float:
	return _face_offset() * 1.12

## ---------------------------------------------------------------------
## Catching the player
## ---------------------------------------------------------------------

## kill
## Called by the Player when this enemy touches them. Freezes the player,
## closes any minigame, turns their view to this enemy's face, then runs
## _play_kill().
func kill() -> void:
	if not can_kill_player or killing or PlayerManager.cutscene:
		return
	# rogue mode's early rounds: only a trapped or long-still player (or one
	# dragged out of a hiding spot) can be caught - see RogueRun.kill_allowed
	if not _dragging_out and not RogueRun.kill_allowed():
		return
	# a shield: the player lives, this enemy is stunned and knocked back
	if is_stunned() or PlayerManager.shield_protected() or PlayerManager.dying or PlayerManager.grabbed:
		return
	if PlayerManager.use_shield():
		_dragging_out = false
		holding = false
		PlayerManager.InAnimation = false   # (dragged out of a hiding spot: free to run)
		stun_from(PlayerManager.player.global_position if is_instance_valid(PlayerManager.player) else global_position - global_basis.z)
		return
	# rogue mode: a grab is a hit, not (yet) the end - it takes health, then
	# they mash F to break free (none left, or they don't: killed)
	var struggle := false
	if RogueRun.grabs_hurt():
		struggle = PlayerManager.take_damage(RogueRun.grab_damage())
	_dragging_out = false
	killing = true
	holding = false
	AudioManager.play_sound(AudioManager.StringStinger)
	PlayerManager.HideDialog()
	PlayerManager.dying = true
	PlayerManager.grabbed = struggle
	PlayerManager.InAnimation = true
	# caught while getting into the car: the getting-in stops, the player is
	# back on their feet with their own eyes
	_pull_out_of_car()
	if PlayerManager.minigameTwo:
		PlayerManager.minigameTwo = false
		UiManager.show_panel("gas_intake", false)
		PlayerManager.Gas_Canister.visible = false
		PlayerManager.gasIntakeSweetSpot.visible = false
	if PlayerManager.minigameThree:
		UiManager.show_panel("hood", false)
	if PlayerManager.player and PlayerManager.player.CAMERA:
		PlayerManager.player.CAMERA.current = true
		PlayerManager.MiniGameModeOff()
		UiManager.set_cursor_visible(false)
		_before_kill_turn()
		# same framing every time: player standing straight, enemy at kill_distance
		var p: Node3D = PlayerManager.player
		if p.has_method("stand_up_for_kill"):
			p.stand_up_for_kill(kill_turn_time)
		# it may step round the player to a side with room: don't get stuck on them
		add_collision_exception_with(p)
		var spot := _kill_spot()
		if spot.distance_to(global_position) > 0.01:
			var tw := create_tween()
			tw.tween_method(func(v: Vector3): global_position = v,
				global_position, spot, kill_turn_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await _turn_player_to_face(spot)
		if struggle:
			var presses := RogueRun.struggle_presses()
			var time := RogueRun.struggle_time()
			RogueRun.grabs_this_round += 1
			if await _struggle(presses, time):
				_break_free()
				return
	PlayerManager.grabbed = false
	PlayerManager.deaths += 1
	# the screen goes red (DamageOverlay) - not for the story's scripted deaths
	if not (PlayerManager.OpeningCutscene or PlayerManager.Loop0):
		PlayerManager.lose_all_health()
	_play_kill()

## ---------------------------------------------------------------------
## Grabbed (rogue mode - see RogueRun "Grabs")
## ---------------------------------------------------------------------
const STRUGGLE_HUD := preload("res://Scripts/UI/StruggleHud.gd")

## Holding the player, face to face: they have `time` seconds to press F
## `presses` times. The view shakes with every press and narrows as the
## time runs out. True = they broke free.
func _struggle(presses: int, time: float) -> bool:
	var p = PlayerManager.player
	var cam: Camera3D = p.CAMERA
	var hud := STRUGGLE_HUD.new()
	get_tree().root.add_child(hud)
	var roll := cam.rotation.z
	var fov := cam.fov
	var got := 0
	var left := time
	var shake := 0.0
	var t := 0.0
	while left > 0.0 and got < presses:
		await get_tree().process_frame
		if not is_instance_valid(self) or not is_instance_valid(p) or not is_instance_valid(cam):
			if is_instance_valid(hud):
				hud.queue_free()
			return false
		if get_tree().paused:
			continue
		var dt := get_process_delta_time()
		left -= dt
		t += dt
		if Input.is_action_just_pressed("Keysound"):   # F
			got += 1
			shake = 1.0
			hud.kick()
		shake = move_toward(shake, 0.0, dt * 6.0)
		var tight := 1.0 - left / time
		cam.rotation.z = roll + deg_to_rad(sin(t * 55.0) * 3.0 * shake + sin(t * 9.0) * (0.5 + 1.5 * tight))
		cam.fov = fov - 7.0 * tight
		hud.set_state(float(got) / float(presses), left / time)
	cam.rotation.z = roll
	cam.fov = fov
	var free := got >= presses
	hud.finish(free)
	return free

## Broke free: the player can move again (and can't be grabbed for a
## moment), this enemy staggers back.
func _break_free() -> void:
	var p = PlayerManager.player
	killing = false
	PlayerManager.grabbed = false
	PlayerManager.dying = false
	PlayerManager.InAnimation = false
	PlayerManager.grant_grace(RogueRun.ESCAPE_GRACE)
	if is_instance_valid(p):
		remove_collision_exception_with(p)
	_after_grab()
	stun_from(p.global_position if is_instance_valid(p) else global_position - global_basis.z, RogueRun.escape_stun_time())

## The player broke free: undo whatever _before_kill_turn set up (the kill
## model swapped in...). Default: nothing.
func _after_grab() -> void:
	pass

## Caught mid-way into the car (the getting-in animation): stop it and give
## the player back their own head, camera and body, so the kill plays as usual.
func _pull_out_of_car() -> void:
	var p = PlayerManager.player
	if not is_instance_valid(p) or not ("HEAD" in p):
		return
	var anim = AnimationManager.get("GetInCarAnimationPlayer")
	var entering: bool = is_instance_valid(anim) and anim.is_playing() and AnimationManager.CarEntering
	if not entering and not p.Incar:
		return
	if is_instance_valid(anim):
		anim.stop()
	AnimationManager.CarEntering = false
	p.Incar = false
	p.head = p.HEAD
	p.camera = p.CAMERA
	p.interact_ray = p.INTERACT_RAY
	p.CAMERA.current = true
	p.COLLISIONSHAPE3D.disabled = false
	p.gravity = true
	p.TbobON = true
	p.AREA3D.monitoring = true
	p.AREA3D.monitorable = true

## How far in front of the player this kill happens. Override for kills that
## need another distance (Killer's crush).
func _current_kill_distance() -> float:
	return kill_distance

## Where the enemy stands for the kill: kill_distance in front of the player,
## on a side with room for it (see _kill_side), pulled in if none has.
func _kill_spot() -> Vector3:
	var p: Node3D = PlayerManager.player
	var kd := _current_kill_distance() * global_basis.get_scale().y   # a scaled-up enemy stands further back
	if kd <= 0.0 or p == null:
		return global_position
	var side := _kill_side(kd)
	var dist := minf(kd, maxf(side.room - 0.4, 0.6))
	# on the player's floor too: an enemy that caught them from a ramp or step
	# above / below would otherwise be looked at steeply up or down
	return p.global_position + side.dir * dist

## Which side of the player to stand on for a kill needing `kd` of room:
## {dir, room}. Room for the whole kill is needed, or it's played half inside
## a wall / right up against the camera. If the side it came from is blocked
## (a ramp wall, a pillar), it swings round the player to the nearest side
## with room; if none has room, the side with the most.
func _kill_side(kd: float) -> Dictionary:
	var p: Node3D = PlayerManager.player
	var flat := global_position - p.global_position
	flat.y = 0.0
	if flat.length() < 0.05:
		flat = -p.global_basis.z
		flat.y = 0.0
	var dir := flat.normalized()
	var best_dir := dir
	var best_room := -1.0
	for deg in [0, 30, -30, 60, -60, 90, -90, 135, -135, 180]:
		var d := dir.rotated(Vector3.UP, deg_to_rad(deg))
		var room := _room_toward(p, d, kd + 0.4)
		if room >= kd + 0.4:
			best_dir = d
			best_room = room
			break
		if room > best_room:
			best_dir = d
			best_room = room
	return {"dir": best_dir, "room": best_room}

## How far from the player toward `dir` is clear (up to `limit`), checked
## low and at eye height, down the middle and either side (its whole body
## has to be in view, not half behind a corner).
func _room_toward(p: Node3D, dir: Vector3, limit: float) -> float:
	var room := limit
	var space := get_world_3d().direct_space_state
	var eye_h: float = (p.standing_eye_position() - p.global_position).y if p.has_method("standing_eye_position") else 1.7
	var side := dir.cross(Vector3.UP).normalized() * 0.3 * global_basis.get_scale().y
	for h in [0.5, eye_h * 0.6, eye_h]:
		for s in [Vector3.ZERO, side, -side]:
			var from: Vector3 = p.global_position + Vector3.UP * h + s
			var query := PhysicsRayQueryParameters3D.create(from, from + dir * limit)
			query.exclude = [get_rid(), p.get_rid()]
			var hit := space.intersect_ray(query)
			if hit:
				room = minf(room, from.distance_to(hit.position))
	# and floor at about the player's height all the way (not off the side
	# of a ramp or a ledge)
	# (walked out in small steps: a ramp's slope is fine, a drop isn't)
	var step := 0.4
	var dist := step
	var floor_y: float = p.global_position.y
	var under := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP * 0.5, p.global_position + Vector3.DOWN * 2.0)
	under.exclude = [get_rid(), p.get_rid()]
	var below := space.intersect_ray(under)
	if below:
		floor_y = below.position.y
	var start_y := floor_y   # and it stays about level with the player overall
	while dist <= room:
		var at: Vector3 = p.global_position + dir * dist
		at.y = floor_y
		var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.8, at + Vector3.DOWN * 0.8)
		down.exclude = [get_rid(), p.get_rid()]
		var ground := space.intersect_ray(down)
		if not ground or absf(ground.position.y - floor_y) > 0.3 or absf(ground.position.y - start_y) > 0.4:
			return maxf(dist - step, 0.0)
		floor_y = ground.position.y
		dist += step
	return room

## How far above its feet the face the player looks at when caught is: its
## model's head bone if it has one (so it's right whatever the model's
## scale), else face_height. Killer keeps face_height (its kills are framed
## around it).
func _face_offset() -> float:
	for sk in find_children("*", "Skeleton3D", true, false):
		if not sk.is_visible_in_tree():
			continue
		var bone: int = sk.find_bone("head")
		if bone < 0:
			bone = sk.find_bone("mixamorig_Head")
		if bone >= 0:
			var head_pos: Vector3 = sk.global_transform * sk.get_bone_global_pose(bone).origin
			return head_pos.y - global_position.y
	return face_height * global_basis.get_scale().y

## Held still by a cutscene (PlayerManager.cutscene). Default: nothing.
func _cutscene_pose() -> void:
	pass

## Runs just before the player's view turns. Default: nothing.
func _before_kill_turn() -> void:
	pass

## HidingSpot.drag_out calls this as the player is pulled out (over `time`
## seconds). Default: just stand still. Override to play a grab animation.
func play_drag_out(_time: float) -> void:
	holding = true

## The kill itself. Default: a lunge - it rushes the last stretch into the
## player's face (view jolts back), a hit, then black and the game over
## screen. Every death shows the enemy doing it.
func _play_kill() -> void:
	var p = PlayerManager.player
	if is_instance_valid(p) and p.CAMERA:
		var cam: Camera3D = p.CAMERA
		await get_tree().create_timer(0.35).timeout   # a beat staring at it
		var eye := cam.global_position
		var flat := eye - global_position
		flat.y = 0.0
		# stop with its face filling the view (closer and the camera ends up inside it)
		var lunge_to := global_position + flat.normalized() * maxf(flat.length() - 1.3, 0.0)
		# a shorter enemy leaps up to eye level (looking down on it up close
		# you'd only see the top of its head) and the view levels out onto it
		lunge_to.y += maxf(eye.y - (global_position.y + _face_offset()), 0.0)
		# hangs there in the leap, not pulled back down
		use_gravity = false
		velocity = Vector3.ZERO
		var tw := create_tween()
		tw.tween_property(self, "global_position", lunge_to, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var face_pitch := atan2(lunge_to.y + _face_offset() - eye.y, minf(flat.length(), 1.3))
		tw.parallel().tween_property(cam, "rotation:x", face_pitch, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		AudioManager.play_sound(AudioManager.HeavyDamage)
		AudioManager.play_sound(AudioManager.SkullCrush)
		var shake := create_tween()
		shake.tween_property(cam, "rotation:z", deg_to_rad(10.0), 0.05)
		shake.tween_property(cam, "rotation:x", cam.rotation.x + deg_to_rad(12.0), 0.08)
		var overlay := CanvasLayer.new()
		overlay.layer = 50
		var black := ColorRect.new()
		black.color = Color.BLACK
		black.set_anchors_preset(Control.PRESET_FULL_RECT)
		black.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(black)
		await get_tree().create_timer(0.12).timeout
		add_child(overlay)
	await get_tree().create_timer(game_over_delay).timeout
	UiManager.show_game_over()

## Turns the player's view to the face of an enemy standing at `stand_at`
## (aimed from standing eye height, as the player is stood up for the kill).
func _turn_player_to_face(stand_at: Vector3 = global_position) -> void:
	var head: Node3D = PlayerManager.player.HEAD
	var cam: Camera3D = PlayerManager.player.CAMERA
	var face_pos := stand_at + Vector3.UP * _face_offset()
	var eye: Vector3 = PlayerManager.player.standing_eye_position() if PlayerManager.player.has_method("standing_eye_position") else cam.global_position
	var to_face := (face_pos - eye).normalized()
	var h_dist := Vector2(to_face.x, to_face.z).length()
	var target_yaw := HelperManager.find_shortest_y_rotation(head.rotation.y, atan2(-to_face.x, -to_face.z))
	var target_pitch := clampf(atan2(to_face.y, h_dist) - deg_to_rad(kill_look_down_degrees), deg_to_rad(-60), deg_to_rad(60))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(head, "rotation:y", target_yaw, kill_turn_time)
	tween.tween_property(cam, "rotation:x", target_pitch, kill_turn_time)
	await tween.finished

## Small props in the "enemy_passthrough" group (bear traps, item pickups)
## and other enemies don't block enemies - checked once a second so things
## spawned later count.
func _update_passthrough(delta: float) -> void:
	_passthrough_timer -= delta
	if _passthrough_timer > 0.0:
		return
	_passthrough_timer = 1.0
	for body in get_tree().get_nodes_in_group("enemy_passthrough") + get_tree().get_nodes_in_group("enemy"):
		if body == self:
			continue
		if body is PhysicsBody3D and is_instance_valid(body):
			add_collision_exception_with(body)

## Walked into something low (a curb, a lip, a seam between floors) while on
## the floor and barely moved: if there's room to stand on top of it, hop up.
func _step_up(wish: Vector3, moved: Vector3, delta: float) -> void:
	if step_height <= 0.0 or not is_on_floor() or wish.length_squared() < 0.0001:
		return
	moved.y = 0.0
	if moved.length() > wish.length() * delta * 0.5:
		return   # moving fine
	var up := Vector3.UP * step_height
	if test_move(global_transform, up):
		return   # no headroom
	var forward := wish.normalized() * maxf(wish.length() * delta, 0.1)
	var raised := global_transform.translated(up)
	if test_move(raised, forward):
		return   # still blocked up there: it's a wall, not a step
	global_position += up + forward
	apply_floor_snap()

## Caught the player by reaching them (see kill_reach).
func _check_reach_kill() -> void:
	if kill_reach <= 0.0 or not can_kill_player or killing or not is_instance_valid(player):
		return
	if not RogueRun.kill_allowed():
		return
	if PlayerManager.dying or PlayerManager.grabbed or PlayerManager.hiding or PlayerManager.shield_protected() or is_stunned() or ("Incar" in player and player.Incar):
		return
	var d := player.global_position - global_position
	if absf(d.y) < 1.5 * global_basis.get_scale().y and Vector2(d.x, d.z).length() <= kill_reach * global_basis.get_scale().y:
		AudioManager.cancel_loop_sfx()
		kill()

## The camera the player is looking through right now: their own, or a
## minigame's (the tire change, the hood...) - what's on screen is what
## counts for "can they see me".
func _view_camera() -> Camera3D:
	var vc := get_viewport().get_camera_3d()
	if is_instance_valid(vc):
		return vc
	return camera if is_instance_valid(camera) else null
