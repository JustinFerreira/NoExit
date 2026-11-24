## No Exit
## Overtime Studios
## Payphone Ring Event (RARE - once per run, see GarageEvent)
## - A payphone near the player rings for a few rings (the ring comes from
##   the phone itself). While it rings it can be picked up: the ringing stops,
##   and on the line - close, in the player's ear - is the killer's heavy
##   breathing. "...Hello?" More breathing. Then the line goes dead.
##   Left alone it just stops ringing. Put on every payphone at load
##   (EventDirector).

extends "res://Scripts/Events/GarageEvent.gd"
const EnemyNoise = preload("res://Scripts/Enemies/EnemyNoise.gd")

const EventSounds = preload("res://Scripts/Events/EventSounds.gd")
const RING := preload("res://Assets/Audio/SFX/office_phone-ring_medium-loudaif-14604.mp3")
## How long it rings if nobody answers (seconds, random in this range).
const RING_TIME := Vector2(8.0, 14.0)

var _ring: AudioStreamPlayer3D
var _pickup: StaticBody3D
var _answered := false

func _init() -> void:
	tier = Tier.RARE
	kind = "payphone"
	min_killer_distance = 40.0

func _fire() -> void:
	_make_pickup()
	# the ring sound is several rings long: let it go 8-14 s (a few rings)
	_ring = EventSounds.play_at(get_tree(), RING, _phone_mesh().global_position + Vector3.UP * 2.0, 0.0, 45.0)
	EnemyNoise.make(get_tree(), _phone_mesh().global_position, EnemyNoise.PAYPHONE)
	var until := Time.get_ticks_msec() + int(randf_range(RING_TIME.x, RING_TIME.y) * 1000.0)
	while not _answered and is_instance_valid(_ring) and _ring.playing and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	if _answered:
		return
	if is_instance_valid(_ring):
		_ring.stop()
		_ring.queue_free()
	_remove_pickup()   # nobody answered

## The payphone's model (the trigger hangs off the payphone node).
func _phone_mesh() -> MeshInstance3D:
	for m in get_parent().find_children("*", "MeshInstance3D", true, false):
		if m.mesh:
			return m
	return null

## While it rings: a clickable copy of the phone's collision, a touch bigger so
## the aim finds it first, outlined like everything else.
func _make_pickup() -> void:
	var mesh := _phone_mesh()
	if mesh == null:
		return
	var shape_src: CollisionShape3D = null
	for s in mesh.find_children("*", "CollisionShape3D", true, false):
		shape_src = s
		break
	_pickup = StaticBody3D.new()
	_pickup.name = "AnswerPhone"
	_pickup.set_script(load("res://Scripts/Interactables/Interactable.gd"))
	_pickup.has_outline = true
	_pickup.mesh = mesh
	_pickup.is_interactable = true
	var shape := CollisionShape3D.new()
	if shape_src and shape_src.shape:
		shape.shape = shape_src.shape
		shape.transform = shape_src.transform.scaled_local(Vector3.ONE * 1.06)
	else:
		var box := BoxShape3D.new()
		box.size = mesh.get_aabb().size * 1.06
		shape.shape = box
		shape.position = mesh.get_aabb().get_center()
	_pickup.add_child(shape)
	mesh.add_child(_pickup)
	_pickup.interacted.connect(_on_answered)

func _remove_pickup() -> void:
	if is_instance_valid(_pickup):
		_pickup.hide_outline()
		_pickup.queue_free()
	_pickup = null

## Picked up: the ringing stops, the handset comes off the phone, and
## someone is breathing on the line. The player stands there, phone to ear,
## until the line goes dead (they can't walk off mid-call).
func _on_answered(_body: Variant) -> void:
	if _answered:
		return
	_answered = true
	_remove_pickup()
	if is_instance_valid(_ring):
		_ring.stop()
		_ring.queue_free()
	_hold_player(true)
	# nobody walks up on them while they're stuck on the phone
	_send_killers_away()
	_set_handset_on_hook(false)
	AudioManager.play_sound(AudioManager.GetKeyPress(), -10.0)   # the receiver lifting
	await get_tree().create_timer(0.8).timeout
	await _breathe(-4.0, 1.0)
	PlayerManager.CharacterDialog("...Hello?")
	await get_tree().create_timer(1.6).timeout
	await _breathe(-2.0, 0.92)
	# the line goes dead - hang it back up
	AudioManager.play_sound(AudioManager.Thud4, -16.0)
	await get_tree().create_timer(0.5).timeout
	_set_handset_on_hook(true)
	AudioManager.play_sound(AudioManager.GetKeyPress(), -12.0)
	_hold_player(false)

## Stops the player walking (they can still look round) while on the call.
func _hold_player(hold: bool) -> void:
	if PlayerManager.dying:
		return
	PlayerManager.InAnimation = hold
	var p = PlayerManager.player
	if hold and is_instance_valid(p):
		p.velocity = Vector3.ZERO

## ---------------------------------------------------------------------
## The handset. The payphone is one mesh; the handset is its own separate
## piece of it (the part with the most triangles - the pole and box are
## simple). Lifting it swaps in a copy of the mesh without that piece.
## ---------------------------------------------------------------------
static var _off_hook_meshes: Dictionary = {}   # mesh -> mesh without the handset
var _on_hook_mesh: Mesh

func _set_handset_on_hook(on_hook: bool) -> void:
	var m := _phone_mesh()
	if m == null:
		return
	if on_hook:
		if _on_hook_mesh:
			m.mesh = _on_hook_mesh
			_on_hook_mesh = null
		return
	if _on_hook_mesh:
		return
	var lifted := _without_handset(m.mesh)
	if lifted:
		_on_hook_mesh = m.mesh
		m.mesh = lifted

static func _without_handset(src: Mesh) -> ArrayMesh:
	if _off_hook_meshes.has(src):
		return _off_hook_meshes[src]
	if src == null or src.get_surface_count() != 1:
		return null
	var a := src.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	if idx.is_empty():
		return null
	# pieces = groups of triangles joined by shared corners (same position)
	var parent := []   # (a plain Array: the lambda below must see it change)
	parent.resize(v.size())
	for i in v.size():
		parent[i] = i
	var root := func(x: int) -> int:
		while int(parent[x]) != x:
			x = parent[x]
		return x
	var at := {}
	for i in v.size():
		var k := v[i].snapped(Vector3.ONE * 0.0001)
		if at.has(k):
			parent[root.call(i)] = root.call(at[k])
		else:
			at[k] = i
	for t in range(0, idx.size(), 3):
		var r0: int = root.call(idx[t])
		for j in [1, 2]:
			var r: int = root.call(idx[t + j])
			if r != r0:
				parent[r] = r0
	var count := {}
	for t in range(0, idx.size(), 3):
		var r: int = root.call(idx[t])
		count[r] = count.get(r, 0) + 1
	if count.size() < 2:
		return null
	var handset: int = count.keys()[0]
	for r in count:
		if count[r] > count[handset]:
			handset = r
	var keep := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		if root.call(idx[t]) != handset:
			keep.append_array([idx[t], idx[t + 1], idx[t + 2]])
	a[Mesh.ARRAY_INDEX] = keep
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	out.surface_set_material(0, src.surface_get_material(0))
	_off_hook_meshes[src] = out
	return out

## The killer's breath, close in the ear (not from the phone - it's on the line).
func _breathe(volume_db: float, pitch: float) -> void:
	var s := AudioStreamPlayer.new()
	s.stream = AudioManager.HeavyBreath
	s.volume_db = volume_db
	s.pitch_scale = pitch
	s.bus = "SFX"
	add_child(s)
	s.play()
	await s.finished
	s.queue_free()
