## No Exit
## Overtime Studios
## Pipe Fall Event (COMMON - comes back after kind_cooldown, see GarageEvent)
## - A length of ceiling pipe a little ahead of the player gives way at one
##   end: a metal groan, a jolt, then that end swings down with a crash and
##   hangs there. Steam blasts out of the broken joint with a loud hiss, then
##   settles into a thin leak that dies away. The pipe stays hanging.
## - Put on spread-out ceiling pipes at load (EventDirector); each pipe only
##   falls once. Fine with the killer nearby.

extends "res://Scripts/Events/GarageEvent.gd"
const EnemyNoise = preload("res://Scripts/Enemies/EnemyNoise.gd")

const EventSounds = preload("res://Scripts/Events/EventSounds.gd")
const CRASH := preload("res://Assets/Audio/SFX/MetalCrash.mp3")
const GROAN := preload("res://Assets/Audio/SFX/car_hood-open_metalic-hollow-springy-91593.mp3")
const HISS := preload("res://Assets/Audio/SFX/WhiteNoise.wav")

## Most the loose end can swing down (degrees).
const MAX_SWING := 65.0
## Strong blast, then the thin leak (seconds).
const BLAST_TIME := 2.5
const LEAK_TIME := 9.0

## The pipe piece (a Node3D with its mesh under it) - set by EventDirector.
var pipe: Node3D

func _init() -> void:
	tier = Tier.COMMON
	kind = "pipe_fall"
	kind_cooldown = 200.0
	weight = 0.8

func can_fire() -> bool:
	return is_instance_valid(pipe) and not pipe.has_meta("fallen")

## The pipe's two ends in world space, and its length.
func _ends() -> Array:
	var mesh: MeshInstance3D = null
	for m in pipe.find_children("*", "MeshInstance3D", true, false):
		if m.mesh:
			mesh = m
			break
	if mesh == null:
		return []
	var box := mesh.get_aabb()
	var axis := 0
	if box.size.y > box.size[axis]: axis = 1
	if box.size.z > box.size[axis]: axis = 2
	var c := box.get_center()
	var a := c
	var b := c
	a[axis] = box.position[axis]
	b[axis] = box.end[axis]
	var wa: Vector3 = mesh.global_transform * a
	var wb: Vector3 = mesh.global_transform * b
	return [wa, wb]

func _fire() -> void:
	if not can_fire():
		return
	var ends := _ends()
	if ends.is_empty():
		return
	pipe.set_meta("fallen", true)
	# the end further from the player stays up, the near end comes down -
	# so it falls toward them, in view
	var p = PlayerManager.player
	var near: Vector3 = ends[0]
	var hinge: Vector3 = ends[1]
	if is_instance_valid(p) and ends[1].distance_to(p.global_position) < ends[0].distance_to(p.global_position):
		near = ends[1]
		hinge = ends[0]
	var along: Vector3 = near - hinge
	var length := along.length()
	if length < 0.3:
		return
	var turn_axis := along.cross(Vector3.UP).normalized()
	if turn_axis == Vector3.ZERO:
		return
	# how far it can swing before the end hits the floor
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(near + Vector3.DOWN * 0.3, near + Vector3.DOWN * 12.0))
	var drop: float = (near.y - hit.position.y - 0.25) if hit else length
	var swing := deg_to_rad(MAX_SWING)
	if drop < length:
		swing = minf(swing, asin(clampf(drop / length, 0.0, 1.0)))
	var hits_floor := swing < deg_to_rad(MAX_SWING) - 0.01
	var start := pipe.global_transform
	# the right way round: the near end goes DOWN
	var down_sign := -1.0 if (Basis(turn_axis, 0.1) * along).y > along.y else 1.0
	var rotate_to := func(angle: float) -> void:
		if not is_instance_valid(pipe):
			return
		var r := Transform3D(Basis(turn_axis, angle * down_sign), Vector3.ZERO)
		pipe.global_transform = Transform3D(Basis(), hinge) * r * Transform3D(Basis(), -hinge) * start
	# groan, a jolt...
	EventSounds.play_at(get_tree(), GROAN, near, -4.0, 40.0, 0.55)
	var tw := create_tween()
	tw.tween_method(rotate_to, 0.0, deg_to_rad(4.0), 0.12)
	tw.tween_method(rotate_to, deg_to_rad(4.0), deg_to_rad(2.5), 0.15)
	tw.tween_interval(randf_range(0.35, 0.7))
	# ...and it goes
	tw.tween_method(rotate_to, deg_to_rad(2.5), swing, 0.75).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw.step_finished   # the jolt
	_steam(near, -along.normalized(), BLAST_TIME * 0.3, 0.25)
	await tw.finished
	var end_now: Vector3 = hinge + (Basis(turn_axis, swing * down_sign) * along)
	EventSounds.play_at(get_tree(), CRASH, end_now if hits_floor else near, 2.0 if hits_floor else -2.0, 55.0)
	EnemyNoise.make(get_tree(), end_now if hits_floor else near, EnemyNoise.PIPE_FALL)
	_steam(near, (-along.normalized() + Vector3.DOWN * 0.6).normalized(), BLAST_TIME + LEAK_TIME, 1.0)

## Steam out of the broken joint at `at`, blowing along `dir`: a hard blast
## that thins to a leak and stops, with its hiss.
func _steam(at: Vector3, dir: Vector3, time: float, strength: float) -> void:
	var fx := GPUParticles3D.new()
	fx.amount = 160
	fx.lifetime = 1.8
	fx.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, -1)
	mat.spread = 18.0
	mat.initial_velocity_min = 6.0
	mat.initial_velocity_max = 10.0
	mat.gravity = Vector3(0, 1.2, 0)   # it rises as it slows
	mat.damping_min = 5.0
	mat.damping_max = 8.0
	mat.angle_min = -180.0
	mat.angle_max = 180.0
	mat.scale_min = 0.6
	mat.scale_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 2.6))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	mat.scale_curve = grow_tex
	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 0.85, 0.88, 0.55))
	fade.set_color(1, Color(0.7, 0.7, 0.72, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	mat.color_ramp = fade_tex
	fx.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var puff := StandardMaterial3D.new()
	puff.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.vertex_color_use_as_albedo = true
	puff.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	soft.gradient = g
	puff.albedo_texture = soft
	quad.material = puff
	fx.draw_pass_1 = quad
	get_tree().current_scene.add_child(fx)
	fx.global_position = at
	if absf(dir.normalized().dot(Vector3.UP)) < 0.99:
		fx.look_at(at + dir, Vector3.UP)
	fx.amount_ratio = strength
	fx.emitting = true
	var hiss := EventSounds.play_at(get_tree(), HISS, at, -2.0 + 6.0 * (strength - 1.0), 45.0, 1.7)
	if hiss:
		hiss.finished.disconnect(hiss.queue_free)
		hiss.finished.connect(hiss.play)   # keep hissing until we stop it
	var tw := create_tween()
	if time > BLAST_TIME:
		tw.tween_interval(BLAST_TIME)
		tw.tween_property(fx, "amount_ratio", 0.25 * strength, 1.5)
		if hiss:
			tw.parallel().tween_property(hiss, "volume_db", -14.0, 1.5)
		tw.tween_interval(maxf(time - BLAST_TIME - 3.0, 0.0))
	else:
		tw.tween_interval(maxf(time - 1.5, 0.0))
	tw.tween_property(fx, "amount_ratio", 0.0, 1.5)
	if hiss:
		tw.parallel().tween_property(hiss, "volume_db", -50.0, 1.5)
	await tw.finished
	fx.emitting = false
	if is_instance_valid(hiss):
		hiss.queue_free()
	await get_tree().create_timer(fx.lifetime + 0.2).timeout
	fx.queue_free()
