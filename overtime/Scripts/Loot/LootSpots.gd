## No Exit
## Overtime Studios
## Loot Spots
## - attach_bins(level): every object named in LootSheet.SEARCHABLES (the
##   bins) becomes searchable with its table - a LootContainer click box round
##   it, outlined with the object. Found by name, so it works in every version
##   of the office and garage.
## - spawn_bodies(level): LootSheet.BODIES dead bodies (DeadBody.gd) at random
##   flat floor spots in the garage, away from where the player arrives, their
##   car and each other. New spots every load.
## - The click boxes are on the click-only layer (like hiding under a car):
##   the player's aim finds them, nothing walks into them.

const LOOT_CONTAINER := preload("res://Scripts/Loot/LootContainer.gd")
const DEAD_BODY := preload("res://Scripts/Loot/DeadBody.gd")
const LOOT_SHEET := preload("res://Scripts/Loot/LootSheet.gd")
const CLICK_LAYER := 1 << 6
## Click box this much bigger than the bin all round (world units).
const BIN_PAD := 0.06

## The loot table for an object, by its name (LootSheet.SEARCHABLES), or "".
static func _bin_kind(n: Node) -> String:
	if n == null:
		return ""
	for prefix in LOOT_SHEET.SEARCHABLES:
		if str(n.name).begins_with(prefix):
			return LOOT_SHEET.SEARCHABLES[prefix]
	return ""

static func attach_bins(level: Node) -> void:
	for n in level.find_children("*", "Node3D", true, false):
		var kind := _bin_kind(n)
		if kind == "" or _bin_kind(n.get_parent()) != "":
			continue   # (only the bin itself - not the model inside it)
		_make_bin(n as Node3D, kind)

static func _make_bin(bin: Node3D, kind: String) -> void:
	var meshes: Array[MeshInstance3D] = []
	if bin is MeshInstance3D and bin.mesh:
		meshes.append(bin)
	for m in bin.find_children("*", "MeshInstance3D", true, false):
		if m.mesh:
			meshes.append(m)
	if meshes.is_empty():
		return
	var box := AABB()
	for i in meshes.size():
		var b: AABB = meshes[i].global_transform * meshes[i].get_aabb()
		box = b if i == 0 else box.merge(b)
	box = box.grow(BIN_PAD)
	var click := StaticBody3D.new()
	click.name = "SearchBin"
	click.set_script(LOOT_CONTAINER)
	click.table = kind
	click.search_time = LOOT_SHEET.search_time(kind)
	click.has_outline = true
	click.mesh = meshes[0]
	click.mesh_list = meshes.slice(1)
	click.collision_layer = CLICK_LAYER
	click.collision_mask = 0
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box.size
	shape.shape = bs
	click.add_child(shape)
	bin.add_child(click)
	click.global_transform = Transform3D(Basis(), box.get_center())

## ---------------------------------------------------------------------
## Dead bodies (garage)
## ---------------------------------------------------------------------
const BODY_SPACING := 15.0
const BODY_FROM_START := 12.0
const BODY_FROM_CAR := 8.0

static func spawn_bodies(level: Node3D) -> void:
	var region := level.find_children("*", "NavigationRegion3D", true, false)
	if region.is_empty():
		return
	var map: RID = region[0].get_navigation_map()
	await HelperManager.nav_map_updated(level.get_tree(), map)
	if not is_instance_valid(level) or not level.is_inside_tree():
		return
	var space := level.get_world_3d().direct_space_state
	var start: Vector3 = PlayerManager.player.global_position if is_instance_valid(PlayerManager.player) else Vector3.INF
	var car = level.get("player_car")
	var car_at: Vector3 = level._car_box(car).get_center() if is_instance_valid(car) and level.has_method("_car_box") else Vector3.INF
	var booth = level.get_tree().get_first_node_in_group("toll_booth")
	# (sizes go by the player: the story garage is built at a much bigger scale)
	var unit := 1.0
	if is_instance_valid(PlayerManager.player) and is_instance_valid(PlayerManager.player.CAMERA):
		unit = maxf((PlayerManager.player.CAMERA.global_position.y - PlayerManager.player.global_position.y) / 3.0, 0.01)
	var count := randi_range(LOOT_SHEET.BODIES.x, LOOT_SHEET.BODIES.y)
	var placed: Array[Vector3] = []
	var run_id := randi()
	for k in count:
		var spot := Vector3.INF
		for attempt in 80:
			var p := NavigationServer3D.map_get_random_point(map, 1, true)
			if p == Vector3.ZERO:
				continue
			if start != Vector3.INF and p.distance_to(start) < BODY_FROM_START * unit:
				continue
			if car_at != Vector3.INF and Vector2(p.x - car_at.x, p.z - car_at.z).length() < BODY_FROM_CAR * unit:
				continue
			if booth and booth.has_method("is_inside") and booth.is_inside(p):
				continue
			if placed.any(func(q): return q.distance_to(p) < BODY_SPACING * unit):
				continue
			# flat floor right there (not a ramp, the stairs or a car roof)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * unit, p + Vector3.DOWN * 1.5 * unit))
			if hit.is_empty() or (hit.normal as Vector3).y < 0.999:
				continue
			spot = hit.position
			break
		if spot == Vector3.INF:
			continue
		placed.append(spot)
		var body := Node3D.new()
		body.name = "DeadBody%d" % k
		body.set_script(DEAD_BODY)
		level.add_child(body)
		body.global_position = spot
		body.rotation.y = randf() * TAU
		# a fresh id each load: a new body is never "already searched"
		body.build("dead_body_%d_%d" % [run_id, k])
