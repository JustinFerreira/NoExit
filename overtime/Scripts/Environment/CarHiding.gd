## No Exit
## Overtime Studios
## Car Hiding
## - Every car in the garage can be hidden under, from either long side: a
##   HidingSpot on each side (a low click area along the side, between the
##   wheels; the eyes go under the car looking out; the way in is crouched
##   just outside it). An enemy that sees the player duck under comes over
##   and drags them out (HidingSpot / Enemy do that).
## - Put on every car by ParkingGarage at load (attach()). Static helper.

const HIDING_SPOT := preload("res://Scripts/Interactables/HidingSpot.gd")

## Eye height under the car, and how far in from its side (garage units).
const EYE_HEIGHT := 0.3
const EYE_IN := 0.45
## The way in: this far out from the side, this high (crouched).
const ENTRY_OUT := 0.8
const ENTRY_HEIGHT := 0.7
## The click area: this tall, this far out from the side, this share of the
## car's length (centred - clear of the wheels).
const CLICK_HEIGHT := 0.9
const CLICK_OUT := 0.15
const CLICK_LENGTH := 0.45
## Physics layer 7 ("Clickable"): the player's interact ray sees it, bodies
## don't collide with it.
const CLICK_LAYER := 1 << 6

## `level` is the ParkingGarage (it measures the cars: _car_box, _front_of).
static func attach(level: Node) -> void:
	var cars: Array[Node3D] = []
	for holder in level.find_children("Cars", "", true, false):
		for deck in holder.get_children():
			for c in deck.get_children():
				if c is Node3D:
					cars.append(c)
	for holder in level.find_children("AlarmCars", "", true, false):
		for c in holder.get_children():
			if c is Node3D:
				cars.append(c)
	if "player_car" in level and is_instance_valid(level.player_car):
		cars.append(level.player_car)
	for c in level.get("cars"):
		if is_instance_valid(c):
			cars.append(c)
	for car in cars:
		if car.has_node("HideUnderL"):
			continue
		var box: AABB = level._car_box(car)
		if box.size == Vector3.ZERO:
			continue
		var front: Vector3 = level._front_of(car)
		for s in [1.0, -1.0]:
			_make_spot(car, box, front, s)

static func _make_spot(car: Node3D, box: AABB, front: Vector3, s: float) -> void:
	var side := front.cross(Vector3.UP).normalized() * s
	var half_len := (absf(front.x) * box.size.x + absf(front.z) * box.size.z) * 0.5
	var half_w := (absf(side.x) * box.size.x + absf(side.z) * box.size.z) * 0.5
	var mid := box.get_center()
	var floor_y := box.position.y
	var spot := StaticBody3D.new()
	spot.set_script(HIDING_SPOT)
	spot.name = "HideUnderL" if s > 0.0 else "HideUnderR"
	spot.has_outline = false
	# its own layer, which only the player's aim ray looks at (CLICK_LAYER):
	# clickable, but nobody walks into it
	spot.collision_layer = CLICK_LAYER
	spot.collision_mask = 0
	var hide := Marker3D.new()
	hide.name = "HidePoint"
	spot.add_child(hide)
	var entry := Marker3D.new()
	entry.name = "EntryPoint"
	spot.add_child(entry)
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(half_len * 2.0 * CLICK_LENGTH, CLICK_HEIGHT, 0.3)
	shape.shape = b
	spot.add_child(shape)
	spot.hide_point = hide
	spot.entry_point = entry
	# lying flat under a car: not much room to look up, plenty along the floor
	spot.look_up_limit = 10.0
	spot.look_down_limit = 15.0
	car.add_child(spot)
	# facing out of the car (-Z = out of the hiding spot)
	var out_basis := Basis.looking_at(side, Vector3.UP)
	spot.global_transform = Transform3D(out_basis, Vector3(mid.x, floor_y + CLICK_HEIGHT * 0.5, mid.z) + side * (half_w + CLICK_OUT))
	hide.global_transform = Transform3D(out_basis, Vector3(mid.x, floor_y + EYE_HEIGHT, mid.z) + side * (half_w - EYE_IN))
	entry.global_transform = Transform3D(out_basis, Vector3(mid.x, floor_y + ENTRY_HEIGHT, mid.z) + side * (half_w + ENTRY_OUT))
