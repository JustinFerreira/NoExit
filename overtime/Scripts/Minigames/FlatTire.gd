## No Exit
## Overtime Studios
## Flat Tire
## - Made by RogueRun on one of the car's wheels when this round's problem
##   is a flat. Squashes the wheel so it looks flat, and puts a click box on
##   it: with a Spare Tire in hand, clicking opens the tire-change minigame
##   (TireGame). Once it's done the wheel is round again.

extends Interactable

## The car's wheel mesh that's flat, and the car (lifted by the jack).
var wheel: MeshInstance3D
var car: Node3D

var _round_basis: Basis
var _round_position: Vector3
var _game: Node
## How far the tire change got before stopping (TireGame saves it on Esc).
var _progress: Dictionary = {}

func _ready() -> void:
	has_outline = true
	mesh = wheel
	_round_basis = wheel.global_basis
	_round_position = wheel.global_position
	var aabb: AABB = wheel.global_transform * wheel.get_aabb()
	# flatten: squash it top to bottom and drop it onto the ground
	wheel.global_basis = Basis.from_scale(Vector3(1.0, 0.72, 1.0)) * _round_basis
	wheel.global_position = _round_position - Vector3(0, aabb.size.y * 0.14, 0)
	_make_click_shape()
	super._ready()
	# once the car's own collision is in the physics world, push the click
	# shape out past its side (see _fit_past_body)
	await get_tree().physics_frame
	_fit_past_body()

## ---------------------------------------------------------------------
## The click shape: a disc the size of the wheel, lying along its axle. The
## car body's collision wraps round the wheels, so a box in the wheel used
## to be hidden behind it - most clicks on the wheel hit the car instead.
## The disc sticks out just past the body's side, so aiming anywhere on the
## wheel finds it first.
## ---------------------------------------------------------------------
var _shape: CollisionShape3D
var _disc: CylinderShape3D
var _center: Vector3
var _out: Vector3
var _half_width := 0.0
var _r_h := 0.5   # the flattened wheel's half width and half height (its face)
var _r_v := 0.5

func _make_click_shape() -> void:
	var box: AABB = wheel.global_transform * wheel.get_aabb()   # flattened now
	_center = box.get_center()
	# out of the car, along the axle (the car's side axis, toward this wheel)
	var side_axis := car.global_basis.x.normalized()
	_out = side_axis * signf(side_axis.dot(_center - car.global_position))
	if _out == Vector3.ZERO:
		_out = side_axis
	var along := car.global_basis.z.normalized()
	_half_width = (absf(_out.x) * box.size.x + absf(_out.z) * box.size.z) * 0.5
	var radius := (absf(along.x) * box.size.x + absf(along.z) * box.size.z) * 0.5
	_disc = CylinderShape3D.new()
	_disc.radius = radius
	_r_h = radius
	_r_v = box.size.y * 0.5
	add_to_group("aim_claim")
	_shape = CollisionShape3D.new()
	_shape.shape = _disc
	add_child(_shape)
	global_basis = Basis()
	_set_disc(-_half_width, _half_width + 0.06)

## The disc runs from `inner` to `outer` along _out (metres from the wheel's
## middle).
func _set_disc(inner: float, outer: float) -> void:
	_disc.height = maxf(outer - inner, 0.05)
	global_position = _center + _out * (inner + outer) * 0.5
	# a cylinder stands along its Y: lay it along the axle
	var y := _out
	var x := Vector3.UP.cross(y).normalized()
	if x == Vector3.ZERO:
		x = Vector3.RIGHT
	_shape.global_basis = Basis(x, y, x.cross(y).normalized())

## Where the car body's side is, out from the wheel (checked from outside,
## along the axle, over the wheel's face) - the disc ends a little past it.
func _fit_past_body() -> void:
	if not is_inside_tree() or _disc == null:
		return
	var space := get_world_3d().direct_space_state
	var furthest := _half_width
	var up := Vector3.UP
	var along := _out.cross(up).normalized()
	for p in [Vector2.ZERO, Vector2(0.7, 0), Vector2(-0.7, 0), Vector2(0, 0.7), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
		var at: Vector3 = _center + (along * p.x + up * p.y) * _disc.radius
		var q := PhysicsRayQueryParameters3D.create(at + _out * 1.2, at - _out * _half_width, 0xFFFFFFFF, [get_rid()])
		var hit := space.intersect_ray(q)
		if hit and hit.collider is Node and car.is_ancestor_of(hit.collider):
			furthest = maxf(furthest, (hit.position - _center).dot(_out))
	_set_disc(-_half_width, minf(furthest, _half_width + 1.0) + 0.06)

func _on_interacted(_body: Variant) -> void:
	if _game:
		return
	if not PlayerManager.has_item(RogueRun.PROBLEM_ITEMS[RogueRun.TIRE]):
		PlayerManager.CharacterDialog("This tire's flat. I need a spare.")
		AudioManager.play_sound(AudioManager.Thud4)
		return
	_game = load("res://Scripts/Minigames/TireGame.gd").new()
	_game.car = car
	_game.wheel = wheel
	_game.wheel_round_xf = Transform3D(_round_basis, _round_position)
	_game.state = _progress
	_game.finished.connect(_on_game_finished)
	# the wheel itself isn't outlined while you work on it (its outline also
	# ringed every lug nut in front of it)
	set_outline_blocked(true)
	get_tree().current_scene.add_child(_game)

func _on_game_finished(success: bool) -> void:
	_game = null
	set_outline_blocked(false)
	if not success:
		return
	RogueRun.tire_fixed = true
	_progress.clear()
	PlayerManager.RemoveItemByName(RogueRun.PROBLEM_ITEMS[RogueRun.TIRE])
	wheel.global_basis = _round_basis
	wheel.global_position = _round_position
	wheel.show()
	_on_interaction_complete()
	if RogueRun.unfixed_problems().is_empty():
		PlayerManager.CharacterDialog("That's everything. Let's get out of here.")

## Player aiming (Player._aim_claim): from standing height you look down on
## the wheel, and the car's fender is in the way of any collision shape - so
## the tire is picked by what the player sees: the aim line passing through
## the tire itself (an oval the size of the flattened tire, its whole width) within
## `length`, with nothing but this car itself (or something invisible: a
## trigger area, the battery minigame's reset zones)
## in front of it.
func claims_aim(from: Vector3, dir: Vector3, length: float, first: Object, first_dist: float) -> bool:
	if _disc == null:
		return false
	var denom := dir.dot(_out)
	if denom > -0.05:
		return false   # looking along or away from the wheel's face
	# slices through the tire, outer face to inner face: at a steep angle
	# you see its tread, not its face
	var along := _out.cross(Vector3.UP).normalized()
	for k in 5:
		var depth := _half_width - 2.0 * _half_width * k / 4.0
		var t := (_center + _out * depth - from).dot(_out) / denom
		if t < 0.0 or t > length:
			continue
		if first != null and first != self and not (first is Area3D) and not (first is Node and first.is_in_group("resetzone")) and not (first is Node and car.is_ancestor_of(first)) and first_dist < t - 0.05:
			return false   # a wall or something else in front
		var d: Vector3 = from + dir * t - _center
		var x := d.dot(along) / _r_h
		var y := d.dot(Vector3.UP) / _r_v
		if x * x + y * y <= 1.0:
			return true
	return false
