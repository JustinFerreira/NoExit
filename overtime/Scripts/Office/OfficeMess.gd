## No Exit
## Overtime Studios
## Office Mess
## - Something an office worker left on the floor (OfficeLife makes them):
##   "coffee" (a brown puddle), "water" (a puddle by the sinks), "papers"
##   (sheets scattered about) or "trash" (crumpled bits).
## - The janitor goes and cleans it (DialogNpc.go_clean): clean() fades it
##   out and frees it. In group "office_mess".
## - Nothing to click or bump into - it's just on the floor.

extends Node3D

var kind := "coffee"
## true once the janitor is on his way (so he isn't sent twice)
var claimed := false
var _cleaning := false
var _base_scale := Vector3.ONE

func _ready() -> void:
	add_to_group("office_mess")
	_base_scale = scale
	match kind:
		"coffee":
			_puddle(Color(0.28, 0.17, 0.08, 0.92), randf_range(0.35, 0.6))
		"water":
			_puddle(Color(0.6, 0.75, 0.85, 0.55), randf_range(0.4, 0.7))
		"papers":
			for i in randi_range(4, 7):
				_bit(Vector3(0.21, 0.004, 0.29), Color(0.95, 0.95, 0.92), 0.6)
		_:
			for i in randi_range(3, 6):
				_bit(Vector3(0.1, 0.08, 0.1), [Color(0.8, 0.75, 0.6), Color(0.85, 0.85, 0.85), Color(0.6, 0.3, 0.25)].pick_random(), 0.45)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.15 if kind in ["coffee", "water"] else 0.9
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _puddle(c: Color, r: float) -> void:
	# a few overlapping flat blobs
	for i in 3:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var rr := r * randf_range(0.5, 1.0)
		cm.top_radius = rr
		cm.bottom_radius = rr
		cm.height = 0.004
		cm.radial_segments = 14
		mi.mesh = cm
		mi.material_override = _mat(c)
		add_child(mi)
		mi.position = Vector3(randf_range(-r, r) * 0.5, 0.01 + i * 0.001, randf_range(-r, r) * 0.5)
		mi.scale = Vector3(randf_range(0.8, 1.3), 1, randf_range(0.8, 1.3))

func _bit(size: Vector3, c: Color, spread: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	add_child(mi)
	mi.position = Vector3(randf_range(-spread, spread), size.y * 0.5 + 0.005, randf_range(-spread, spread))
	mi.rotation.y = randf() * TAU

## While it's mopped: how much is left (1 = all of it, 0 = gone) - it
## shrinks in under the mop.
func set_dirt(left: float) -> void:
	var f := clampf(left, 0.03, 1.0)
	scale = Vector3(_base_scale.x * f, _base_scale.y, _base_scale.z * f)

## Cleaned up: fades away, then gone.
func clean() -> void:
	if _cleaning:
		return
	_cleaning = true
	remove_from_group("office_mess")
	var tw := create_tween()
	tw.tween_property(self, "scale", scale * Vector3(0.05, 1, 0.05), 0.8).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	queue_free()
