## No Exit
## Overtime Studios
## Gate Arm Event (RARE - once per run, see GarageEvent)
## - One of the toll booth's boom arms lifts by itself, hangs there, and drops
##   back with a clunk. Put on each boom arm at load (EventDirector).

extends "res://Scripts/Events/GarageEvent.gd"

const EventSounds = preload("res://Scripts/Events/EventSounds.gd")
## How far it lifts (degrees) and which local axis it pivots about.
@export var lift_degrees: float = 75.0
@export var pivot_axis: Vector3 = Vector3.BACK

func _init() -> void:
	tier = Tier.RARE
	kind = "gate_arm"
	min_killer_distance = 25.0

func _fire() -> void:
	var arm: Node3D = get_parent()
	var down := arm.transform.basis
	# lift whichever way raises the arm's far end (it may stick out either way)
	var angle := deg_to_rad(lift_degrees)
	var far := _far_end(arm) - arm.global_position
	var axis_world := (arm.global_basis * pivot_axis).normalized()
	if far.rotated(axis_world, angle).y < far.y:
		angle = -angle
	# (the arm model is scaled: turn its rotation only, keep its scale)
	var scale := down.get_scale()
	var q_down := down.get_rotation_quaternion()
	var q_up := (Basis(q_down) * Basis(pivot_axis, angle)).get_rotation_quaternion()
	var at := func(q: Quaternion) -> Basis: return Basis(q) * Basis.from_scale(scale)
	EventSounds.play_at(get_tree(), AudioManager.HoodOpen, arm.global_position, -4.0, 35.0, 0.8)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void: arm.transform.basis = at.call(q_down.slerp(q_up, t)), 0.0, 1.0, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(3.0)
	tw.tween_method(func(t: float) -> void: arm.transform.basis = at.call(q_up.slerp(q_down, t)), 0.0, 1.0, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	arm.transform.basis = down
	EventSounds.play_at(get_tree(), AudioManager.Thud4, arm.global_position, 0.0, 35.0)

## The middle of the arm's meshes (world) - away from its pivot.
func _far_end(arm: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for m in arm.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null:
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.get_center() if not first else arm.global_position + arm.global_basis.x
