## No Exit
## Overtime Studios
## Security Camera
## - The garage's wall cameras keep turning to look at the player: the camera
##   body pans and tilts on its neck (smoothly, never swinging round into the
##   wall), the wall plate, arm and swivel stay put.
## - The model is one mesh, so it's cut in two at the neck (NECK_Y, in the
##   model's own units): the mount stays on the original MeshInstance3D, the
##   body goes on a new one on a pivot at the neck. The cut meshes are made
##   once and shared by every camera.
## - Put on every camera under a "Cameras" node by ParkingGarage (attach()).

extends Node3D

## Where the model is cut (its own units): below = mount, above = body.
const NECK_Y := 7.5
## The neck's middle - the body turns round this point (model units).
const PIVOT := Vector3(0.0, 7.5, 24.8)
## How far it can pan either side of straight out from the wall, and tilt
## down / up (degrees).
const MAX_PAN := 100.0
const MAX_TILT_DOWN := 70.0
const MAX_TILT_UP := 30.0
## How fast it turns (degrees per second).
const TURN_SPEED := 70.0

const MODEL := "M_Camera_Unwrapped"
static var _cut: Dictionary = {}   # source mesh -> [mount mesh, body mesh]

var _mesh: MeshInstance3D
var _pivot: Node3D
var _rest: Basis
var _pan := 0.0
var _tilt := 0.0

## Puts a tracker on every security camera under `root`'s "Cameras" nodes.
static func attach(root: Node) -> void:
	for holder in root.find_children("Cameras", "", true, false):
		for cam in holder.get_children():
			if not (cam is Node3D) or cam.has_node("Tracker"):
				continue
			var mi: MeshInstance3D = null
			for c in cam.get_children():
				if c is MeshInstance3D and c.mesh and c.mesh.resource_path.get_file().get_basename() == MODEL:
					mi = c
			if mi == null:
				continue
			var t := Node3D.new()
			t.name = "Tracker"
			t.set_script(load("res://Scripts/Environment/SecurityCamera.gd"))
			t._mesh = mi
			cam.add_child(t)

func _ready() -> void:
	if _mesh == null:
		return
	var parts := _split(_mesh.mesh)
	if parts.is_empty():
		return
	var body := MeshInstance3D.new()
	body.mesh = parts[1]
	body.material_override = _mesh.material_override
	for i in _mesh.get_surface_override_material_count():
		body.set_surface_override_material(i, _mesh.get_surface_override_material(i))
	_pivot = Node3D.new()
	_pivot.name = "Head"
	_mesh.get_parent().add_child.call_deferred(_pivot)
	_pivot.add_child(body)
	_rest = _mesh.transform.basis
	_pivot.transform = Transform3D(_rest, _mesh.transform * PIVOT)
	_mesh.mesh = parts[0]

func _process(delta: float) -> void:
	if _pivot == null or not _pivot.is_inside_tree():
		return
	var p = PlayerManager.player
	if not is_instance_valid(p) or not p.is_inside_tree():
		return
	var eyes: Vector3 = p.CAMERA.global_position if "CAMERA" in p and p.CAMERA else p.global_position
	# the player's direction in the camera's own (resting) frame: +Z = out
	var parent_space: Vector3 = _pivot.get_parent().global_transform.affine_inverse() * eyes
	var d: Vector3 = _rest.inverse() * (parent_space - _pivot.position)
	if d.length_squared() < 0.0001:
		return
	var want_pan := clampf(rad_to_deg(atan2(d.x, d.z)), -MAX_PAN, MAX_PAN)
	var want_tilt := clampf(rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length())), -MAX_TILT_DOWN, MAX_TILT_UP)
	_pan = move_toward(_pan, want_pan, TURN_SPEED * delta)
	_tilt = move_toward(_tilt, want_tilt, TURN_SPEED * delta)
	# pan round the neck, then tilt the lens up / down (+Z tilted up = about -X)
	var turn := Basis(Vector3.UP, deg_to_rad(_pan)) * Basis(Vector3.RIGHT, deg_to_rad(-_tilt))
	_pivot.transform.basis = _rest * turn

## [mount, body] cut from the camera model at NECK_Y; the body's vertices
## moved so PIVOT is its origin.
static func _split(src: Mesh) -> Array:
	if _cut.has(src):
		return _cut[src]
	if src == null or src.get_surface_count() != 1:
		return []
	var a := src.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	if idx.is_empty():
		return []
	var low := PackedInt32Array()
	var high := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var cy := (v[idx[t]].y + v[idx[t + 1]].y + v[idx[t + 2]].y) / 3.0
		var tri := [idx[t], idx[t + 1], idx[t + 2]]
		if cy > NECK_Y:
			high.append_array(tri)
		else:
			low.append_array(tri)
	var mount_arrays := a.duplicate()
	mount_arrays[Mesh.ARRAY_INDEX] = low
	var body_arrays := a.duplicate()
	var moved := PackedVector3Array()
	moved.resize(v.size())
	for i in v.size():
		moved[i] = v[i] - PIVOT
	body_arrays[Mesh.ARRAY_VERTEX] = moved
	body_arrays[Mesh.ARRAY_INDEX] = high
	var mount := ArrayMesh.new()
	mount.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mount_arrays)
	mount.surface_set_material(0, src.surface_get_material(0))
	var body := ArrayMesh.new()
	body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body_arrays)
	body.surface_set_material(0, src.surface_get_material(0))
	_cut[src] = [mount, body]
	return _cut[src]
