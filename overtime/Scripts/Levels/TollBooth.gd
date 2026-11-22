## No Exit
## Overtime Studios
## Toll Booth
## - The toll booth model (toll_booth.tscn). Gives the model collision built
##   from its own mesh, and a clickable door (BoothDoor) that steps the
##   player in or out - the door is part of the model, so it doesn't open.
## - hub_points(): spots on the booth's floor where things can be placed
##   (rogue mode spawns items here).
## - All positions below are in the model's own units (centimetres).

extends Node3D
class_name TollBooth

## Middle of the door, and the size of its click box.
@export var door_center := Vector3(-92.0, 100.0, -93.0)
@export var door_size := Vector3(24.0, 200.0, 90.0)
## Where the player stands after going in / coming out through the door.
@export var inside_spot := Vector3(-40.0, 12.0, -93.0)
@export var outside_spot := Vector3(-175.0, 0.0, -93.0)
## Spots on the floor inside for placing items.
@export var hub_spots: Array[Vector3] = [
	Vector3(40.0, 12.0, -230.0), Vector3(-40.0, 12.0, -230.0),
	Vector3(40.0, 12.0, -150.0), Vector3(40.0, 12.0, -60.0),
	Vector3(0.0, 12.0, -10.0), Vector3(-45.0, 12.0, -170.0),
]

func _ready() -> void:
	add_to_group("toll_booth")
	_build_collision()
	_build_door()

## World positions of the inside floor spots, dropped onto the floor.
func hub_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var space := get_world_3d().direct_space_state
	for spot in hub_spots:
		var p := global_transform * spot
		var up := global_basis.y * 0.8   # 80 cm up in the model's own scale
		var query := PhysicsRayQueryParameters3D.create(p + up, p - up * 0.5)
		var hit := space.intersect_ray(query)
		out.append(hit.position if hit else p)
	return out

## True if a world position is inside the booth (between its walls).
func is_inside(world_pos: Vector3) -> bool:
	var local := global_transform.affine_inverse() * world_pos
	return local.x > door_center.x + door_size.x * 0.5

## Moves a floor spot inside the booth just far enough from its walls that
## something `radius` metres across (from its middle) fits without poking
## through them - checked a little above the floor in 16 directions.
func fit_inside(world_pos: Vector3, radius: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	var p := world_pos
	for pass_i in 16:
		var push := Vector3.ZERO
		for k in 16:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 16.0)
			var from := p + Vector3.UP * 0.25
			var query := PhysicsRayQueryParameters3D.create(from, from + dir * radius)
			var hit := space.intersect_ray(query)
			if hit:
				push -= dir * (radius - from.distance_to(hit.position))
		if push.length() < 0.002:
			break
		p += push * 0.35
	return p

## How far it is from a floor spot to the nearest wall (a little above the
## floor, 16 directions, up to `limit`).
func clearance(world_pos: Vector3, limit: float = 3.0) -> float:
	var space := get_world_3d().direct_space_state
	var from := world_pos + Vector3.UP * 0.25
	var best := limit
	for k in 16:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 16.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * limit))
		if hit:
			best = minf(best, from.distance_to(hit.position))
	return best

func _build_collision() -> void:
	for mesh_instance in find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.mesh == null or mesh_instance.has_node("BoothCollision"):
			continue
		var body := StaticBody3D.new()
		body.name = "BoothCollision"
		var shape := CollisionShape3D.new()
		shape.shape = mesh_instance.mesh.create_trimesh_shape()
		body.add_child(shape)
		mesh_instance.add_child(body)

func _build_door() -> void:
	var door := StaticBody3D.new()
	door.name = "BoothDoor"
	door.set_script(load("res://Scripts/Interactables/BoothDoor.gd"))
	door.booth = self
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = door_size
	shape.shape = box
	door.add_child(shape)
	door.position = door_center
	add_child(door)
