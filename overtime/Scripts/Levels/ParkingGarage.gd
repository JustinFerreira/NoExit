## No Exit
## Overtime Studios
## Parking Garage
## - Sets up the garage for the current loop (music, killer, which car is
##   the player's, Loop 0 differences) and feeds the killer the player's
##   position. The security cameras on the walls follow the player
##   (SecurityCamera). Every car can be hidden under (CarHiding).

extends Node3D

@onready var target: Node3D = $Player
@export var fog_remover: FogVolume
@export var cars: Array[Node3D]
@export var player_car: Node3D
@export var attached_objects: Array[Node3D]

@export var orbit_distance: float = 5.0  # Distance from player to fog remover
@export var height_offset: float = 0.0   # Optional height offset


func _ready() -> void:
	if PlayerManager.Loop0:
		PlayerManager.Hint(EventManager.press_f_key_fob)
	if PlayerManager.Loop1:
		AudioManager.play_sound(AudioManager.GetBassStinger())
	if PlayerManager.sprint_engaged:
		PlayerManager.player.is_sprinting = PlayerManager.sprint_engaged
	PlayerManager.Office = false
	PlayerManager.ParkingGarage = true
	PlayerManager.player = get_tree().current_scene.get_node("Player")
	PlayerManager.examed = true
	HelperManager.fog_remover = fog_remover
	HelperManager.killer_eyes = $WorldEnvironment/FogRemover/KillerEyes
	GetCar(player_car, attached_objects)
	# every car can be hidden under
	load("res://Scripts/Environment/CarHiding.gd").attach(self)
	# the bear traps go somewhere new every time
	_scatter_bear_traps()
	# the security cameras follow the player
	load("res://Scripts/Environment/SecurityCamera.gd").attach(self)
	if RogueRun.active:
		RogueRun.setup_garage(self)
func _process(_delta: float) -> void:
	if fog_remover:
		# Get the camera's forward direction but flatten it to ignore vertical tilt
		var camera_forward = -target.CAMERA.global_transform.basis.z
		camera_forward.y = 0  # Remove Y component to prevent up/down movement
		camera_forward = camera_forward.normalized()  # Re-normalize the vector

		# Calculate the position horizontally in front of the player
		var target_position = target.global_position + (camera_forward * orbit_distance)
		target_position.y += height_offset  # Apply height offset if needed

		# Set fog remover position
		fog_remover.global_position = target_position

		# Make fog remover face the camera (optional)
		var camera_position = target.CAMERA.global_position
		camera_position.y = target_position.y  # Keep fog remover looking at same height
		fog_remover.look_at(camera_position)
	if SettingsManager.KillerDisabled:
		return
	get_tree().call_group("enemy" , "target_position" , target.global_transform.origin)


## Swaps the player's car with a random car in the garage - any parked car
## (under "Cars") or one of the `cars` stand-ins - so the car is somewhere
## else every loop. A parked car trades places with it (a stand-in is just
## removed, as before). Car models face different ways in their files and sit
## at different heights, so each is lined up by its front, its middle and its
## floor; the objects attached to the player's car move and turn with it.
func GetCar(_player_car: Node3D, _attached_objects: Array[Node3D]):
	var choices: Array[Node3D] = []
	for c in cars:
		if is_instance_valid(c):
			choices.append(c)
	for holder in find_children("Cars", "", true, false):
		for deck in holder.get_children():
			for c in deck.get_children():
				if c is Node3D and c != _player_car and _car_box(c).size != Vector3.ZERO:
					choices.append(c)
	if choices.is_empty():
		return
	# the room checks need the physics world up to date
	await get_tree().physics_frame
	if not is_instance_valid(_player_car):
		return
	choices.shuffle()

	# where the player's car is now: its front, middle and floor
	var player_front := _front_of(_player_car)
	var player_box := _car_box(_player_car)
	var home := _player_car.global_transform
	var rel: Array[Transform3D] = []
	for obj in _attached_objects:
		rel.append(home.affine_inverse() * obj.global_transform)

	# try spots until one leaves room to get round the car (in front of the
	# hood, down both sides) - nose in or out, whichever fits
	var selected_car: Node3D = null
	var neighbours: Array = []
	for candidate in choices.slice(0, 40):
		var other_front := _front_of(candidate)
		var other_box := _car_box(candidate)
		var first := other_front if randf() < 0.5 else -other_front
		for facing in [first, -first]:
			_player_car.global_transform = home
			_place(_player_car, player_front, facing, other_box)
			var room := _room_around(_player_car, facing, candidate, _attached_objects)
			if not room.blocked:
				selected_car = candidate
				neighbours = room.parked
				break
		if selected_car:
			break
	if selected_car == null:
		_player_car.global_transform = home   # nowhere with room: stays put
		return
	# parked cars hemming it in are taken away (an empty bay beside it)
	for n in neighbours:
		if is_instance_valid(n) and n != selected_car:
			n.queue_free()
	var other_front := _front_of(selected_car)
	var stand_in: bool = cars.has(selected_car)
	if stand_in:
		selected_car.queue_free()
	else:
		_place(selected_car, other_front, player_front, player_box)

	# everything attached to the player's car comes with it
	for i in _attached_objects.size():
		var obj := _attached_objects[i]
		if not is_instance_valid(obj):
			continue
		obj.global_transform = _player_car.global_transform * rel[i]
		if obj.is_in_group("battery_minigame") and obj.is_in_group("grabbable") and obj.has_method("SetOriginalPos"):
			obj.SetOriginalPos()

## How much room the player has round their car once it's in a spot (facing
## `front`): boxes in front of the hood (to open it) and down both sides
## (doors, gas cap, wheels), about as tall as the player and wide enough to
## walk. Anything solid in them blocks the spot - except parked cars, which
## are listed (they can be taken away). The car being swapped out of the
## spot (`leaving`) and the car's own bits don't count.
const ROOM_FRONT := 1.8
const ROOM_SIDE := 1.3
func _room_around(car: Node3D, front: Vector3, leaving: Node3D, attached: Array[Node3D]) -> Dictionary:
	var out := {"blocked": false, "parked": []}
	var ex: Array[RID] = []
	for root in [car, leaving] + attached:
		if not is_instance_valid(root):
			continue
		if root is CollisionObject3D:
			ex.append(root.get_rid())
		for b in root.find_children("*", "CollisionObject3D", true, false):
			ex.append(b.get_rid())
	if is_instance_valid(PlayerManager.player):
		ex.append(PlayerManager.player.get_rid())
	var box := _car_box(car)
	var side := front.cross(Vector3.UP).normalized()
	var half_len := (absf(front.x) * box.size.x + absf(front.z) * box.size.z) * 0.5
	var half_w := (absf(side.x) * box.size.x + absf(side.z) * box.size.z) * 0.5
	var mid := Vector3(box.get_center().x, box.position.y + 1.5, box.get_center().z)
	var zones := [
		[mid + front * (half_len + ROOM_FRONT * 0.5 + 0.05), Vector3(half_w * 2.0, 2.2, ROOM_FRONT)],
		[mid + side * (half_w + ROOM_SIDE * 0.5 + 0.05), Vector3(ROOM_SIDE, 2.2, half_len * 2.0)],
		[mid - side * (half_w + ROOM_SIDE * 0.5 + 0.05), Vector3(ROOM_SIDE, 2.2, half_len * 2.0)],
	]
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.exclude = ex
	q.collide_with_areas = false
	for z in zones:
		var shape := BoxShape3D.new()
		shape.size = z[1]
		q.shape = shape
		q.transform = Transform3D(Basis(side, Vector3.UP, front), z[0])
		for hit in space.intersect_shape(q, 32):
			if hit.collider is HidingSpot:
				continue   # a click area, not a wall
			var parked := _parked_car_of(hit.collider)
			if parked:
				if not out.parked.has(parked):
					out.parked.append(parked)
			else:
				out.blocked = true
				return out
	return out

## The parked car (a child of a "Cars" deck) a collider belongs to, or null.
func _parked_car_of(n: Object) -> Node3D:
	var node := n as Node
	while node and node.get_parent():
		var deck := node.get_parent()
		if deck.get_parent() and deck.get_parent().name == "Cars":
			return node as Node3D
		node = deck
	return null

## Turns `car` (whose front points along `front_now`) to point along
## `front_to`, then moves it so its middle and floor match `box`.
func _place(car: Node3D, front_now: Vector3, front_to: Vector3, box: AABB) -> void:
	var yaw := front_now.signed_angle_to(front_to, Vector3.UP)
	var mid := _car_box(car).get_center()
	var turn := Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
	car.global_transform = Transform3D(Basis(), mid) * turn * Transform3D(Basis(), -mid) * car.global_transform
	var now := _car_box(car)
	var target := box.get_center()
	car.global_position += Vector3(target.x - now.get_center().x, box.position.y - now.position.y, target.z - now.get_center().z)

## World box round a car's meshes (wheels and all).
func _car_box(car: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in car.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		if _under_ui(m, car):
			continue   # a minigame's on-screen bits (the gas game's icon) aren't the car
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func _under_ui(n: Node, stop: Node) -> bool:
	var p := n.get_parent()
	while p and p != stop:
		if p is CanvasItem:
			return true
		p = p.get_parent()
	return false

## Which way a car's front points (flat, world). The parked car models face
## different ways in their files (sedan / SUV +Z, pickup -X); the player's car
## has a "Hood"; anything else: its own +Z.
const MODEL_FRONT := {
	"M_NPCar_Unwrapped": Vector3(0, 0, 1),
	"M_SUV_Unwrapped": Vector3(0, 0, 1),
	"M_Truck_Unwrapped": Vector3(-1, 0, 0),
}
func _front_of(car: Node3D) -> Vector3:
	var f := Vector3.ZERO
	for m in car.find_children("*", "MeshInstance3D", true, false):
		if m.mesh and MODEL_FRONT.has(m.mesh.resource_path.get_file().get_basename()):
			f = m.global_basis * MODEL_FRONT[m.mesh.resource_path.get_file().get_basename()]
			break
	if f == Vector3.ZERO:
		var hood := car.find_child("Hood", true, false) as Node3D
		if hood:
			var hood_mid: Vector3 = (hood.global_transform * (hood as MeshInstance3D).get_aabb()).get_center() if hood is MeshInstance3D else hood.global_position
			f = hood_mid - _car_box(car).get_center()
			# snap to the car's own axis nearest to it (its length)
			var best := Vector3.ZERO
			for axis in [car.global_basis.x, car.global_basis.z]:
				var a: Vector3 = axis.normalized()
				if absf(a.dot(f.normalized())) > absf(best.dot(f.normalized())):
					best = a * signf(a.dot(f))
			f = best
	if f == Vector3.ZERO:
		f = car.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD

## ---------------------------------------------------------------------
## Bear traps: every load they're moved to random spots on the walkable
## floor (flat floor - not ramps or stairs - spread apart, away from the
## elevator the player arrives in, their car and the toll booth).
## ---------------------------------------------------------------------
const TRAP_SPACING := 15.0
const TRAP_FROM_START := 12.0
const TRAP_FROM_CAR := 6.0

func _scatter_bear_traps() -> void:
	var traps: Array[Node3D] = []
	for holder in find_children("BearTraps", "", true, false):
		for t in holder.get_children():
			if t is Node3D and t.has_method("_snap_jaws"):
				traps.append(t)
	if traps.is_empty():
		return
	var region := find_children("*", "NavigationRegion3D", true, false)
	if region.is_empty():
		return
	var map: RID = region[0].get_navigation_map()
	await HelperManager.nav_map_updated(get_tree(), map)
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var start: Vector3 = PlayerManager.player.global_position if is_instance_valid(PlayerManager.player) else Vector3.INF
	var car_at: Vector3 = _car_box(player_car).get_center() if is_instance_valid(player_car) else Vector3.INF
	var booth = get_tree().get_first_node_in_group("toll_booth")
	var placed: Array[Vector3] = []
	var ignore: Array[RID] = []
	for t in traps:
		for b in t.find_children("*", "CollisionObject3D", true, false):
			ignore.append(b.get_rid())
	for t in traps:
		var spot := Vector3.INF
		for attempt in 80:
			var p := NavigationServer3D.map_get_random_point(map, 1, true)
			if p == Vector3.ZERO:
				continue
			if start != Vector3.INF and p.distance_to(start) < TRAP_FROM_START:
				continue
			if car_at != Vector3.INF and Vector2(p.x - car_at.x, p.z - car_at.z).length() < TRAP_FROM_CAR:
				continue
			if booth and booth.is_inside(p):
				continue
			if placed.any(func(q): return q.distance_to(p) < TRAP_SPACING):
				continue
			# flat floor right there (not a ramp, the stairs or a car roof)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p + Vector3.DOWN * 1.5, 0xFFFFFFFF, ignore))
			if hit.is_empty() or (hit.normal as Vector3).y < 0.999:   # the ramps are gentle (~6 degrees)
				continue
			spot = hit.position
			break
		if spot == Vector3.INF:
			continue   # nowhere found: it stays where it was
		placed.append(spot)
		t.global_position = spot
		t.rotation.y = randf() * TAU
