## No Exit
## Overtime Studios
## Elevator Ride
## - Getting into an elevator, as a cutscene (both the office one going down
##   and the garage ones going up): the view turns to the doors straight away
##   and the player steps up in front of them while they open, walks in once
##   they're OPEN_ENOUGH, turns to the inside button and presses it, then
##   steps back into the elevator turning to face the doors as they close. Always ending at the
##   same spot (STEP_BACK behind the elevator's spawn marker, facing out), so
##   the elevator at the other end - same marker, same facing - picks up from
##   exactly the same view.
## - The whole time: no control, no looking around, enemies stand still
##   (PlayerManager.cutscene). The elevator the player arrives in ends it once
##   its doors are fully open.

## (Not a class_name - used via preload, so it works before the editor rescans.)

const WALK_SPEED := 3.2      # m/s
const TURN_TIME := 0.45
## How far back from the spawn marker the player ends up (towards the back
## wall), and how long stepping back there takes.
const STEP_BACK := 0.9
const STEP_BACK_TIME := 1.1
## Lined up this far in front of the doors (metres) before going in.
const OUTSIDE_MIN := 1.4
const OUTSIDE_MAX := 1.6
## How far the doors' opening animation gets (0-1) before walking in.
const OPEN_ENOUGH := 0.6
## Longest a ride cutscene may last before control comes back regardless.
const MAX_SECONDS := 45.0

## Runs the walk-in. `by` owns the tweens (the button that started it);
## `marker` is where to stand, -Z facing out through the doors; `door` is the
## door's collision (to find the doorway); `doors_anim` is opening the doors
## (walked in once it's OPEN_ENOUGH); `button` is looked at while `press` is called.
static func ride_in(by: Node, marker: Transform3D, door: Node3D, doors_anim: AnimationPlayer, button: Node3D, press: Callable) -> void:
	var p = PlayerManager.player
	if not is_instance_valid(p):
		return
	PlayerManager.set_cutscene(true, MAX_SECONDS)
	if is_instance_valid(p.last_collider):
		p.last_collider.hide_outline()
		p.last_collider = null
	UiManager.set_cursor_visible(false)
	p.velocity = Vector3.ZERO
	if p.has_method("stand_up_for_kill"):
		p.stand_up_for_kill(0.4)   # out of any crouch / lean
	# where to stand, which way the doors are, and a spot just outside them
	var out := -marker.basis.z
	out.y = 0.0
	out = out.normalized()
	var body := p as Node3D
	var stand := Vector3(marker.origin.x, body.global_position.y, marker.origin.z)
	var to_door := (door.global_position - stand).dot(out)
	var cam0: Camera3D = body.CAMERA
	var doorway := stand + out * to_door + Vector3.UP * (cam0.global_position.y - body.global_position.y)
	var side: Vector3 = body.global_position - stand
	var along: float = side.dot(out)
	side -= out * along
	if along > to_door - 0.2 or side.length() > 1.2:
		# not inside yet: straight away face the doors and step up in front of
		# them while they open (no closer than OUTSIDE_MIN, no further than
		# OUTSIDE_MAX - anyone already that close just lines up)
		var outside := stand + out * (to_door + clampf(along - to_door, OUTSIDE_MIN, OUTSIDE_MAX))
		await walk_to(by, body, outside, doorway)
		# and in as soon as they're open enough to fit through
		if doors_anim and doors_anim.is_playing():
			var length := doors_anim.current_animation_length
			while doors_anim.is_playing() and doors_anim.current_animation_position < length * OPEN_ENOUGH:
				await by.get_tree().process_frame
	await walk_to(by, body, stand)
	GameState.settle_on_floor(body)   # rest on the cabin floor like physics would
	# turn to the button and press it
	await look_toward(by, body, button.global_position, TURN_TIME)
	await by.get_tree().create_timer(0.25).timeout
	press.call()
	await by.get_tree().create_timer(0.3).timeout
	# step back into the elevator, turning to face the doors (eyes level) as
	# they close
	var back: Vector3 = stand - out * STEP_BACK
	var cam: Camera3D = body.CAMERA
	var eye_h: float = cam.global_position.y - body.global_position.y
	look_toward(by, body, back + out * 10.0 + Vector3.UP * eye_h, STEP_BACK_TIME)
	var tw := by.create_tween()
	tw.tween_property(body, "global_position", Vector3(back.x, body.global_position.y, back.z), STEP_BACK_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

## Walks the player to a point, turning to face where they're going - or to
## keep looking at `look_at` if given.
static func walk_to(by: Node, p: Node3D, point: Vector3, look_at = null) -> void:
	point.y = p.global_position.y
	var dist := p.global_position.distance_to(point)
	if dist < 0.05:
		return
	var cam: Camera3D = p.CAMERA
	var time := dist / WALK_SPEED
	if look_at == null:
		var face := p.global_position + (point - p.global_position) * 10.0
		face.y = cam.global_position.y
		look_toward(by, p, face, minf(TURN_TIME, time))
		var tw := by.create_tween()
		tw.tween_property(p, "global_position", point, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
		return
	# keep the view on look_at all the way (turning onto it over TURN_TIME)
	var head: Node3D = p.HEAD
	var from := p.global_position
	var yaw0: float = head.rotation.y
	var pitch0: float = cam.rotation.x
	var target: Vector3 = look_at
	var tw2 := by.create_tween()
	tw2.tween_method(func(t: float) -> void:
		p.global_position = from.lerp(point, smoothstep(0.0, 1.0, t))
		var aim := _aim(p, target)
		var b := smoothstep(0.0, 1.0, clampf(t * time / TURN_TIME, 0.0, 1.0))
		head.rotation.y = yaw0 + wrapf(aim.x - yaw0, -PI, PI) * b
		cam.rotation.x = lerpf(pitch0, aim.y, b),
		0.0, 1.0, time)
	await tw2.finished

## The head yaw (local) and camera pitch that look at a point from where the
## player is now.
static func _aim(p: Node3D, point: Vector3) -> Vector2:
	var cam: Camera3D = p.CAMERA
	var d := point - cam.global_position
	var body_yaw: float = p.global_basis.orthonormalized().get_euler().y
	return Vector2(wrapf(atan2(-d.x, -d.z) - body_yaw, -PI, PI),
		clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-60), deg_to_rad(60)))

## Turns the player's view (head yaw + camera pitch) to look at a point.
static func look_toward(by: Node, p: Node3D, point: Vector3, time: float) -> void:
	var cam: Camera3D = p.CAMERA
	var head: Node3D = p.HEAD
	var d := point - cam.global_position
	var world_yaw := atan2(-d.x, -d.z)
	var body_yaw: float = p.global_basis.orthonormalized().get_euler().y
	var yaw_from: float = head.rotation.y
	var yaw_to: float = yaw_from + wrapf(world_yaw - body_yaw - yaw_from, -PI, PI)
	var pitch_to := clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-60), deg_to_rad(60))
	var tw := by.create_tween().set_parallel(true)
	tw.tween_property(head, "rotation:y", yaw_to, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "rotation:x", pitch_to, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

## How far open (fraction of the opening animation) the doors are when the
## player gets control back - wide enough to walk out; they don't have to
## wait for them to finish opening.
const WALK_OUT_AT := 0.4

## Ends the cutscene once an arriving elevator's doors are open enough to
## walk through (see WALK_OUT_AT). Call when they start opening; `anim` is
## the player running the opening.
static func arrive_as_doors_open(anim: AnimationPlayer, anim_name: StringName) -> void:
	if anim == null or not anim.is_inside_tree() or not anim.has_animation(anim_name):
		arrived()
		return
	var wait := anim.get_animation(anim_name).length / maxf(absf(anim.get_playing_speed()), 0.01) * WALK_OUT_AT
	anim.get_tree().create_timer(wait).timeout.connect(arrived)

## Ends the ride cutscene (hands control back). Safe to call more than once.
static func arrived() -> void:
	if PlayerManager.cutscene:
		PlayerManager.set_cutscene(false)
