## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Gas Intake Canister Script
## - This scripts hooks up the gascanister to work
## while the gas canister minigame is on so it rises
## and falls properly. It also moves the sweetspot and
## gives the player score for the game

extends MeshInstance3D

##
@onready var GasIntakeSweetSpot: MeshInstance3D = $"../GasIntakeSweetSpot"
@onready var progress_bar: TextureProgressBar = get_node_or_null("../GasIntakeCam/GasIntakeGame/TextureProgressBar")
var mouse_clicking: Node = null
var hint_label: Node = null

var progress_bar_value: float = 0.0

## Gas Canister movement variables
var fall_speed: float = 30.5

var lift_speed: float = 30

## progress variables
var car_filled: float = 0.0

var fill_speed: float = 0.1


## range of points for gas canister and sweet spot
var lowestPointSweetSpot: float = 10.098
var lowestPointGasCanister: float = 1.000

var highestPointGasCanister: float = 150.9
var highestPointSweetSpot: float = 100.6

## sweet spot movement variables
var sweet_spot_move_speed: float = 25.5  # Adjust for faster/slower movement
var sweet_spot_direction: float = 1     # 1 for moving up, -1 for moving down


func _ready() -> void:
	_make_target()
	mouse_clicking = get_node_or_null("../GasIntakeCam/GasIntakeGame/MouseClicking")
	hint_label = get_node_or_null("../GasIntakeCam/GasIntakeGame/Label")


var _was_on := false
func _process(delta: float) -> void:
	if not PlayerManager.minigameTwo:
		_was_on = false
	if not PlayerManager.minigameTwo and is_instance_valid(_stream) and _stream.visible:
		_stream.visible = false
		if is_instance_valid(_splash):
			_splash.emitting = false
	# Make sure Minigame Two is on
	if PlayerManager.minigameTwo:
		if not _target_fitted:
			# set up once the gas cap door has swung open (so the pour can be
			# kept clear of it)
			var door := get_parent().get_node_or_null("GasCapAnimationPlayer") as AnimationPlayer
			if door and door.is_playing():
				return
		AudioManager.play_sound_loop(AudioManager.Glug, "glug")

		if not _was_on:
			_was_on = true
			_refresh_car_rids()   # (a flat tire may have been added since last time)
		if not _target_fitted:
			_back_camera_up()
			_fit_target_out()
			_place_can()
		_move_sweet_spot(delta)
		_update_stream()

		# Fills only while the gas actually pours into the target (the stream
		# from the spout, falling as it goes, passes through it)
		if _stream_hits_target():
			# Per second, scaled so it fills like it did at 60 FPS on any frame rate.
			car_filled += fill_speed * delta * 60.0
			progress_bar_value += 0.1 * delta * 60.0
			progress_bar.value = progress_bar_value
			AudioManager.play_sound_loop(AudioManager.Glug, "glug")
			if PlayerManager.minigameTwoPassed:
				AudioManager.stop_loop("glug")
		else:
			AudioManager.stop_loop("glug")
		## Test if Gas Canister should be rising
		## checking if actioning is on
		## checking if it has reached highest point
		if PlayerManager.actioning == true && self.position.y <= highestPointGasCanister:
			PlayerManager.Gas_Canister.position.y += lift_speed * delta
		## Test to see if it should be falling by seeing visibility
		## and checking if it has reached lowest point
		## checking if actioing is off
		if self.visible == true && self.position.y >= lowestPointGasCanister && PlayerManager.actioning == false:
			self.position.y -= fall_speed * delta


## this function takes in the parameter value from the progress bar
## this then compares the value to pre determined values to have different effects
func _on_progress_bar_value_changed(value: float) -> void:
	if value >= 25:
		if mouse_clicking:
			mouse_clicking.visible = false
		if hint_label:
			hint_label.visible = false
	if value == 100:
		if PlayerManager.Enemy:
			PlayerManager.Enemy.exit_stalking_mode()
		AnimationManager.GasCapAnimationPlayer.play("GasCapClose")
		AudioManager.play_sound(AudioManager.GasCapClose)
		PlayerManager.player.CAMERA.current = true
		PlayerManager.minigameTwo = false
		PlayerManager.MiniGameModeOff()
		PlayerManager.gotGas_Canister = false
		PlayerManager.RemoveItemByName("Gas Canister")
		PlayerManager.minigameTwoPassed = true
		AudioManager.stop_loop("glug")
		$".".visible = false
		$"../GasIntakeCam/GasIntakeGame".visible = false
		$"../GasCap/GasCap"._on_interaction_complete()
		$"../GasIntakeSweetSpot".visible = false

## ---------------------------------------------------------------------
## The gas: a stream of amber drops pouring out of the canister's spout toward
## the intake, falling as it goes (drawn as particles in the world, so it
## trails as the can moves). It fills only while that stream passes through
## the target - so the can has to be held a little above it.
## ---------------------------------------------------------------------
## The pour is always the same arc, just stretched to how far the nozzle is
## from the intake: it leaves the nozzle rising a little (POUR_UP) and comes
## down to the intake's height - and while the can is held in range it's
## stretched to come down right in the middle of the target. In range is
## anywhere from the spout a touch below the target (LOW_REACH - it squirts
## up a little harder to get there) to the can's middle a bit above it (the
## arc taking REACH_TIME.y to come down): players line up either the spout or
## the can with the target, and both pour in. Too high or too low, it carries
## over or falls short.
const POUR_TIME := 0.22          # seconds from the nozzle to the intake, held just right
const REACH_TIME := Vector2(0.1, 0.36)    # the quickest and slowest the arc gets to the target (in range)
const LOW_REACH := 0.06          # how far below the target the spout can be and still pour in
const POUR_UP := 0.5             # how fast it rises leaving the nozzle
const POUR_REACH := 0.4          # the can's nozzle is set this far beside the target
const POUR_GRAVITY := 12.0       # how fast it falls (the garage is ~2x real size)
const GAS_COLOR := Color(0.86, 0.62, 0.12, 0.8)
var _spout_local := Vector3.INF  # the spout, in the canister mesh's own space
var _stream: MeshInstance3D

## Where the gas comes out (world): the tip of the can's nozzle (the jerry
## can's flexible spout - the separate piece of the model that reaches
## highest), found once from the model.
func _spout() -> Vector3:
	if _spout_local == Vector3.INF:
		_find_nozzle()
	return global_transform * _spout_local

## The way the gas leaves the nozzle: heading for the intake, rising a little,
## fast enough sideways to be over it just as it comes down to its height
## (within REACH_TIME) - then falling.
func _pour_velocity() -> Vector3:
	var to_t: Vector3 = GasIntakeSweetSpot.global_position - _spout()
	to_t.y = 0.0
	if to_t.length() < 0.001:
		return Vector3.UP * POUR_UP
	var t := _reach_time()
	var up := POUR_UP
	if _in_range():
		# just enough rise to come down (or up) exactly on the target's middle
		var h: float = _spout().y - GasIntakeSweetSpot.global_position.y
		up = (0.5 * POUR_GRAVITY * t * t - h) / t
	return to_t / t + Vector3.UP * up

## How long the arc takes to come back down to the target's height, held to
## REACH_TIME (outside it the can's too high or too low to pour in).
func _reach_time() -> float:
	return clampf(_fall_time(), REACH_TIME.x, REACH_TIME.y)

## When the stream (rising at POUR_UP, then falling) is back down at the
## target's height; 0 if it never gets that high.
func _fall_time() -> float:
	var h: float = _spout().y - GasIntakeSweetSpot.global_position.y
	var disc := POUR_UP * POUR_UP + 2.0 * POUR_GRAVITY * h
	if disc < 0.0:
		return 0.0
	return (POUR_UP + sqrt(disc)) / POUR_GRAVITY

## The can is held at a height that pours into the target.
func _in_range() -> bool:
	var h: float = _spout().y - GasIntakeSweetSpot.global_position.y
	return h >= -LOW_REACH and _fall_time() <= REACH_TIME.y

var _nozzle_dir_local := Vector3.UP

## The nozzle: of the model's separate pieces, the one reaching highest. Its
## tip is the middle of its top end, and its direction runs from a little way
## down it to that tip.
func _find_nozzle() -> void:
	var a := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var parent := []
	parent.resize(v.size())
	for i in v.size():
		parent[i] = i
	var root := func(x: int) -> int:
		while int(parent[x]) != x:
			x = parent[x]
		return x
	var at := {}
	for i in v.size():
		var k := v[i].snapped(Vector3.ONE * 0.0001)
		if at.has(k):
			parent[root.call(i)] = root.call(at[k])
		else:
			at[k] = i
	for t in range(0, idx.size(), 3):
		var r0: int = root.call(idx[t])
		for j in [1, 2]:
			var r: int = root.call(idx[t + j])
			if r != r0:
				parent[r] = r0
	# the piece with the highest point
	var top_i := 0
	for i in v.size():
		if v[i].y > v[top_i].y:
			top_i = i
	var nozzle: int = root.call(top_i)
	var top_y := v[top_i].y
	var tip := Vector3.ZERO
	var n_tip := 0
	var lower := Vector3.ZERO
	var n_lower := 0
	for i in v.size():
		if root.call(i) != nozzle:
			continue
		if v[i].y > top_y - 0.012:
			tip += v[i]
			n_tip += 1
		elif v[i].y > top_y - 0.07 and v[i].y < top_y - 0.05:
			lower += v[i]
			n_lower += 1
	_spout_local = tip / maxf(n_tip, 1)
	if n_lower > 0:
		_nozzle_dir_local = (_spout_local - lower / n_lower).normalized()

## The stream's path, worked out each frame (_trace): where it lands (the
## target, or whatever it hits first - the car, the floor) and when.
const STEP := 0.012
const STEPS := 70
var _lands_at := Vector3.INF
var _lands_normal := Vector3.UP
var _lands_t := 0.8
var _on_target := false

func _point(t: float, s: Vector3, v: Vector3) -> Vector3:
	return s + v * t + Vector3.DOWN * 0.5 * POUR_GRAVITY * t * t

## Follows the stream from the spout: the first thing it reaches is where it
## lands. The stream is right over the target _reach_time() in (it's aimed
## that way): in range, that's the target's centre and it pours in; otherwise
## it passes over it or under it. The same can height counts from any angle.
## On the way to the target it goes past the car's own bits (the body, the
## open gas cap, a flat tire): the can's held right there, so they'd only
## ever cut off a good pour. Past the target (a miss) it lands on them.
## (Placing the can still keeps clear of them - _strict - so it looks right.)
var _strict := false
var _car_rids: Array[RID] = []
func _refresh_car_rids() -> void:
	_car_rids.clear()
	var car := get_parent()
	if car is CollisionObject3D:
		_car_rids.append(car.get_rid())
	for b in car.find_children("*", "CollisionObject3D", true, false):
		_car_rids.append(b.get_rid())

## Everything solid - not the click-only boxes (hiding under a car), which
## only the player's aim sees.
const SOLID_MASK := 0xFFFFFFFF & ~(1 << 6)

## The player (and anything they're holding) - standing at the car, often
## right where the minigame camera is - never blocks the pour or the view.
func _player_rids() -> Array[RID]:
	var out: Array[RID] = []
	var p = PlayerManager.player
	if not is_instance_valid(p):
		return out
	if p is CollisionObject3D:
		out.append(p.get_rid())
	for b in p.find_children("*", "CollisionObject3D", true, false):
		out.append(b.get_rid())
	return out

func _trace() -> void:
	var s := _spout()
	var v := _pour_velocity()
	var reach := _reach_time()
	var in_range := _in_range()
	var t_pos: Vector3 = GasIntakeSweetSpot.global_position
	var space := get_world_3d().direct_space_state
	var prev := s
	var prev_t := 0.0
	_on_target = false
	_lands_at = Vector3.INF
	_lands_miss = INF
	for i in range(1, STEPS + 1):
		var t := i * STEP
		# the step that reaches the target ends exactly at it
		var at_target := prev_t < reach and t >= reach
		if at_target:
			t = reach
		var p := _point(t, s, v)
		# onto something solid on the way?
		var q := PhysicsRayQueryParameters3D.create(prev, p)
		q.collide_with_areas = false
		q.exclude = _player_rids()
		q.collision_mask = SOLID_MASK
		if not _strict and t <= reach:
			q.exclude += _car_rids
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			_lands_at = hit.position
			_lands_normal = hit.normal
			_lands_t = prev_t + (t - prev_t) * prev.distance_to(hit.position) / maxf(prev.distance_to(p), 0.0001)
			# anything in the way (the car) stops it short: it only counts
			# when it gets all the way to the middle of the target
			_lands_miss = hit.position.distance_to(t_pos)
			return
		# over the target: in it, or past it (above or below)?
		if at_target:
			_lands_miss = absf(p.y - t_pos.y)
			if in_range:
				_on_target = true
				_lands_at = p
				_lands_normal = (s - p) * Vector3(1, 0, 1)
				_lands_normal = _lands_normal.normalized() if _lands_normal.length() > 0.001 else Vector3.UP
				_lands_t = t
				return
		prev = p
		prev_t = t
	_lands_t = STEPS * STEP
var _lands_miss := INF   # how far the stream is from the target's centre where it gets there

func _stream_hits_target() -> bool:
	return _on_target

func _update_stream() -> void:
	if not is_instance_valid(_stream):
		_stream = _make_stream()
		_splash = _make_splash()
	_trace()
	_stream.visible = true
	_draw_stream()
	# the target reacts while it's being filled: it pulses and glows gas-yellow
	_hit_time = _hit_time + get_process_delta_time() if _on_target else 0.0
	if _target_mat:
		_target_mat.albedo_color = Color(1.0, 0.85, 0.35) if _on_target else Color.WHITE
	if _target_scale != Vector3.ZERO:
		GasIntakeSweetSpot.scale = _target_scale * (1.0 + (0.18 * absf(sin(_hit_time * 14.0)) if _on_target else 0.0))
	# and splash there
	if _lands_at != Vector3.INF:
		var n := _lands_normal if _lands_normal.length() > 0.1 else Vector3.UP
		_splash.global_transform = Transform3D(Basis(), _lands_at + n * 0.01)
		(_splash.process_material as ParticleProcessMaterial).direction = (n + Vector3.UP).normalized()
		# going into the intake: just a little splash back; a miss sprays everywhere
		var sm := _splash.process_material as ParticleProcessMaterial
		sm.initial_velocity_min = 0.15 if _on_target else 0.5
		sm.initial_velocity_max = 0.45 if _on_target else 1.3
		_splash.amount_ratio = 0.35 if _on_target else 1.0
		if not _splash.emitting:
			_splash.emitting = true
	elif _splash.emitting:
		_splash.emitting = false

func _draw_stream() -> void:
	_stream_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var s := _spout()
	var v := _pour_velocity()
	var end_t := clampf(_lands_t, 0.02, STEPS * STEP)
	_flow += get_process_delta_time()
	_stream_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in STREAM_SEGMENTS + 1:
		var f := float(i) / STREAM_SEGMENTS
		var t := end_t * f
		var p := _point(t, s, v)
		# its width, square to the way it's going and to the camera
		var along := v + Vector3.DOWN * POUR_GRAVITY * t
		var across := along.cross(cam.global_position - p)
		across = across.normalized() * STREAM_WIDTH * 0.5 * lerpf(1.0, 0.75, f) if across.length() > 0.00001 else Vector3.ZERO
		var shade := 0.85 + 0.15 * sin(t * 90.0 - _flow * 30.0)
		var c := Color(GAS_COLOR.r * shade, GAS_COLOR.g * shade, GAS_COLOR.b * shade, GAS_COLOR.a)
		_stream_mesh.surface_set_color(c)
		_stream_mesh.surface_add_vertex(p - across)
		_stream_mesh.surface_set_color(c)
		_stream_mesh.surface_add_vertex(p + across)
	_stream_mesh.surface_end()

var _target_mat: StandardMaterial3D
var _target_scale := Vector3.ZERO
var _hit_time := 0.0

## Where the gas lands: drops bouncing up and out of it.
var _splash: GPUParticles3D
func _make_splash() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "GasSplash"
	p.amount = 48
	p.lifetime = 0.35
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 65.0
	m.initial_velocity_min = 0.5
	m.initial_velocity_max = 1.3
	m.gravity = Vector3(0.0, -POUR_GRAVITY, 0.0)
	m.scale_min = 0.5
	m.scale_max = 1.0
	p.process_material = m
	var drop := SphereMesh.new()
	drop.radius = 0.012
	drop.height = 0.024
	drop.radial_segments = 5
	drop.rings = 2
	var splash_mat := _gas_material()
	# drawn on top, like the target - so a splash on it shows in front of it
	splash_mat.no_depth_test = true
	splash_mat.render_priority = 20
	drop.material = splash_mat
	p.draw_pass_1 = drop
	get_tree().current_scene.add_child(p)
	return p

func _gas_material() -> StandardMaterial3D:
	var gas := StandardMaterial3D.new()
	gas.albedo_color = GAS_COLOR
	gas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gas.roughness = 0.1
	gas.metallic_specular = 0.9
	gas.emission_enabled = true
	gas.emission = Color(0.45, 0.3, 0.05)
	gas.emission_energy_multiplier = 0.6
	# drawn after the target (render_priority 10) so the stream shows over the
	# bullseye all the way to where it lands, not cut off at its rim
	gas.render_priority = 15
	return gas

## The stream: a ribbon redrawn every frame right along the pour's path from
## the spout to where it lands - so it always ends exactly where the gas is
## going (the middle of the target), even while the can and the target move.
## A ripple runs down it so it reads as flowing.
const STREAM_WIDTH := 0.03
const STREAM_SEGMENTS := 28
var _stream_mesh: ImmediateMesh
var _flow := 0.0

func _make_stream() -> MeshInstance3D:
	var p := MeshInstance3D.new()
	p.name = "GasStream"
	_stream_mesh = ImmediateMesh.new()
	p.mesh = _stream_mesh
	var mat := _gas_material()
	mat.albedo_color = Color.WHITE   # (the colour's in the vertices)
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# in the level itself, unturned and unscaled: its points are world points
	get_tree().current_scene.add_child(p)
	p.global_transform = Transform3D()
	return p

## When the minigame starts (once) the can is set up to pour: tilted so its
## nozzle points a little up along the pour (the way you tip a jerry can),
## and moved beside the target - POUR_REACH away, across the player's view -
## so the arc is seen from the side, not end on. If the car's in the way of
## that arc anywhere along the target's path, it's brought a little toward
## the player (or tried on the other side) until it isn't.
var _placed := false
func _place_can() -> void:
	if _placed:
		return
	_placed = true
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var right := cam.global_basis.x
	right.y = 0.0
	if right.length() < 0.01:
		return
	right = right.normalized()
	if _spout_local == Vector3.INF:
		_find_nozzle()
	var keep_y := position.y
	var t_pos: Vector3 = GasIntakeSweetSpot.global_position
	# tilt: bring the nozzle's slope up to the pour's
	var nozzle: Vector3 = (global_basis * _nozzle_dir_local).normalized()
	var flat := Vector3(nozzle.x, 0.0, nozzle.z)
	if flat.length() > 0.05:
		flat = flat.normalized()
		var want := atan2(POUR_UP, POUR_REACH / POUR_TIME)
		var have := asin(clampf(nozzle.y, -1.0, 1.0))
		var turn := clampf(want - have, -deg_to_rad(MAX_TILT), deg_to_rad(MAX_TILT))
		var spout_before := _spout()
		global_basis = Basis(flat.cross(Vector3.UP).normalized(), turn) * global_basis
		global_position += spout_before - _spout()   # tipped about its spout
	# beside the target - on the side it's already on if it can - and as
	# little toward the player as lets the arc reach the target clear of the
	# car wherever the target is along its path
	var side := signf((_spout() - t_pos).dot(right))
	if side == 0.0:
		side = 1.0
	var toward := cam.global_position - t_pos
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.01 else Vector3.ZERO
	var best := Vector3.INF
	var best_clear := -1
	for step in 9:
		for sd in [side, -side]:
			var want: Vector3 = t_pos + right * sd * POUR_REACH + toward * step * 0.05
			var s := _spout()
			global_position += Vector3(want.x - s.x, 0.0, want.z - s.z)
			var clear := _clear_pours(cam)
			if clear > best_clear:
				best_clear = clear
				best = global_position
			if clear == CLEAR_CHECKS:
				break
		if best_clear == CLEAR_CHECKS:
			break
	global_position = best
	position.y = keep_y
const MAX_TILT := 45.0   # the most it's tipped (degrees)
const CLEAR_CHECKS := 6  # target heights the placement is checked at

## Of CLEAR_CHECKS heights along the target's path, how many the can (here,
## held just right) pours cleanly into - nothing in the way, can in reach,
## spout in sight.
func _clear_pours(cam: Camera3D) -> int:
	var spot := GasIntakeSweetSpot
	var keep_spot := spot.position.y
	var keep_can := position.y
	var per_unit: float = (get_parent().global_basis * Vector3.UP).y if get_parent() is Node3D else 1.0
	var space := get_world_3d().direct_space_state
	var n := 0
	_strict = true
	for k in CLEAR_CHECKS:
		spot.position.y = lerpf(lowestPointSweetSpot, highestPointSweetSpot, float(k) / (CLEAR_CHECKS - 1))
		# the whole range that pours in: held lowest, just right, highest
		var ok := true
		var slow := REACH_TIME.y - 0.004
		for drop in [-LOW_REACH + 0.005, 0.5 * POUR_GRAVITY * POUR_TIME * POUR_TIME - POUR_UP * POUR_TIME, 0.5 * POUR_GRAVITY * slow * slow - POUR_UP * slow]:
			var want_y: float = spot.global_position.y + drop
			if absf(per_unit) > 0.00001:
				position.y += (want_y - _spout().y) / per_unit
			if position.y < lowestPointGasCanister or position.y > highestPointGasCanister:
				ok = false
				break
			_trace()
			if not _on_target:
				ok = false
				break
			var q := PhysicsRayQueryParameters3D.create(cam.global_position, _spout())
			q.exclude = _player_rids()
			q.collision_mask = SOLID_MASK
			q.collide_with_areas = false
			if not space.intersect_ray(q).is_empty():
				ok = false
				break
		if ok:
			n += 1
	_strict = false
	spot.position.y = keep_spot
	position.y = keep_can
	return n

## The minigame camera steps back CAMERA_BACK (once), so there's more to see -
## less if a wall or car is behind it.
const CAMERA_BACK := 0.6
var _camera_backed := false
func _back_camera_up() -> void:
	if _camera_backed:
		return
	_camera_backed = true
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var back := cam.global_basis.z.normalized()
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + back * (CAMERA_BACK + 0.25))
	q.exclude = _player_rids()
	q.collision_mask = SOLID_MASK
	q.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var room := CAMERA_BACK if hit.is_empty() else maxf(cam.global_position.distance_to(hit.position) - 0.25, 0.0)
	cam.global_position += back * room

## The target slides up and down by the car's side, and low down it used to go
## behind the body (into the car, as far as the player could see). When the
## minigame starts its path is moved toward the camera, just far enough that
## nothing of the car is in front of it anywhere along it. (It's also drawn on
## top - see _make_target - so it never vanishes whatever happens.)
var _target_fitted := false
const TARGET_CLEARANCE := 0.05   # how far the target's centre is kept off the car
func _fit_target_out() -> void:
	_target_fitted = true
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var spot := GasIntakeSweetSpot
	var keep_y := spot.position.y
	var toward := cam.global_position - spot.global_position
	toward.y = 0.0
	if toward.length() < 0.01:
		return
	toward = toward.normalized()
	var space := get_world_3d().direct_space_state
	var start := spot.global_position
	# (and a stream's width off the car everywhere along its path, so the gas
	# can get to its middle without clipping the body where it bulges)
	var room := SphereShape3D.new()
	room.radius = TARGET_CLEARANCE
	var room_q := PhysicsShapeQueryParameters3D.new()
	room_q.shape = room
	room_q.collide_with_areas = false
	room_q.exclude = _player_rids()
	room_q.collision_mask = SOLID_MASK
	# the first offset clear at every height - or, if none is, the one clear
	# at the most (drawn on top anyway)
	var best_off := 0.0
	var best_clear := -1
	for step in 76:
		var off := step * 0.02
		var clear := 0
		for k in 11:
			spot.global_position = start + toward * off
			spot.position.y = lerpf(lowestPointSweetSpot, highestPointSweetSpot, k / 10.0)
			var q := PhysicsRayQueryParameters3D.create(cam.global_position, spot.global_position)
			q.exclude = room_q.exclude
			q.collision_mask = SOLID_MASK
			q.collide_with_areas = false
			if not space.intersect_ray(q).is_empty():
				continue
			room_q.transform = Transform3D(Basis(), spot.global_position)
			if not space.intersect_shape(room_q, 1).is_empty():
				continue
			clear += 1
		if clear > best_clear:
			best_clear = clear
			best_off = off
		if clear == 11:
			break
	spot.global_position = start + toward * best_off
	spot.position.y = keep_y

## This fucntion move the "sweet spot" up or down
## between its max height and lowest point
func _move_sweet_spot(delta: float) -> void:

	# Move the sweet spot
	GasIntakeSweetSpot.position.y += sweet_spot_move_speed * sweet_spot_direction * delta

	# Reverse direction when hitting boundaries
	if GasIntakeSweetSpot.position.y >= highestPointSweetSpot:
		GasIntakeSweetSpot.position.y = highestPointSweetSpot
		sweet_spot_direction = -1  # Start moving down
	elif GasIntakeSweetSpot.position.y <= lowestPointSweetSpot:
		GasIntakeSweetSpot.position.y = lowestPointSweetSpot
		sweet_spot_direction = 1   # Start moving up

## The sweet spot to aim the canister at, drawn as a target (red and white
## rings, a red bullseye) instead of a plain red box - twice the old size, so
## it reads clearly. Same node and the same movement (only its height counts
## for the score). Always faces the camera.
func _make_target() -> void:
	var spot := GasIntakeSweetSpot
	if spot == null:
		return
	var rings := Gradient.new()
	rings.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var red := Color(0.8, 0.04, 0.04)
	var white := Color(0.95, 0.93, 0.9)
	rings.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 0.97])
	rings.colors = PackedColorArray([red, white, red, white, red, Color(0, 0, 0, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = rings
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# always seen, never hidden by the car it sits beside
	mat.no_depth_test = true
	mat.render_priority = 10
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)   # twice the old box: easier to read (only its height counts)
	spot.mesh = quad
	spot.material_override = mat
	_target_mat = mat
	_target_scale = spot.scale
