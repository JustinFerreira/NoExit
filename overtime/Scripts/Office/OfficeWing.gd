## No Exit
## Overtime Studios
## Office Wing
## - Rogue mode's extra office rooms, built from code behind the office's
##   back wall (where the fake doors are painted): bathroom, copy room,
##   meeting room, janitor's closet, kitchen and break room (the kitchen
##   and break room open into each other).
## - Opens the back wall: takes the office's own wall face out (render and
##   collision), hides the painted doors on it and puts up a new wall with a
##   real doorway into each room - placed clear of the corner cubicles,
##   the plants, the fire alarm and the corkboards on that wall.
## - Sized for the office: the level is built about UNIT (1.8) times real
##   size (the player stands 3.3 m tall), so the rooms are office height
##   with big doorways, and the furniture is laid out in real metres inside
##   a pivot per room scaled by UNIT (_furnish_*: x 0..W left to right, z
##   0..D from the back wall towards the office, W/D the room's size in
##   real metres).
## - Gives the rooms their own navigation mesh (baked when it loads) joined
##   to the office's by a NavigationLink3D through each doorway, so NPCs
##   (and the janitor) can path in and out.
## - Every place an NPC can go to do something is a "spot" (spots[kind]):
##   {pos, face, room, sit} - see SPOT KINDS below. OfficeLife.gd hands them
##   out (one NPC per spot at a time: claim_spot / free_spot).
## - Office.gd adds it in rogue mode (Office_Fitted only).
##
## - The mail room is behind the office's right-hand wall (MAIL_ROOM), by
##   the player's desk: that wall is opened the same way.
## - Office job stations (OfficeButton.gd, handled by OfficeJobs.gd): the
##   mail tray, the copiers, the filing cabinet, the coffee machine, the
##   vending machine, the revolver in the fridge; doc_spots are table tops
##   the copy job's documents can turn up on.
##
## SPOT KINDS: "closet", "stall", "sink", "copier", "meeting", "coffee",
##   "fridge", "counter", "couch", "break_seat", "vending", "vendor"

extends Node3D

## How many level units make a real metre (the player is 3.3 tall here).
const UNIT := 1.8
## The office's back wall (its inside face) and the new rooms behind it.
const WALL_Z := -24.67
const WALL_T := 0.25
const WALL_H := 5.6             # up past the office ceiling (it slopes 4.8-5.0)
const ROOM_DEPTH := 16.0
const ROOM_H := 5.0
const FLOOR_Y := 0.02
## The new floors' top: a hair under the office floor (0.016), so walking
## in steps down onto them instead of catching on an edge.
const FLOOR_TOP := 0.008
## The door models (Assets/Environments/Office/Door, in cm) at DOOR_SCALE:
## the frame is 100 x 220 cm, so the doorway is 2.1 x 4.62.
const DOOR_SCALE := 0.021
const DOOR_W := 100.0 * DOOR_SCALE
const DOOR_H := 220.0 * DOOR_SCALE
const OFFICE_X0 := -39.5
const OFFICE_X1 := 13.0

## Rooms left to right: [name, x from, x to, doorway centre x]. The
## doorways sit in the gaps between what's on the wall (corner cubicles
## to -36.8 and from 10.2, plants at -30.8..-27 and -1..2.9, the fire
## alarm at -22.3, corkboards at -21..-17 and -11..-7).
const ROOMS := [
	["Bathroom", -39.5, -28.0, -33.8],
	["CopyRoom", -28.0, -20.0, -24.7],
	["MeetingRoom", -20.0, -8.0, -14.0],
	["JanitorCloset", -8.0, -1.5, -4.5],
	["Kitchen", -1.5, 6.5, 4.7],
	["BreakRoom", 6.5, 13.0, 8.4],
]
## The mail room, behind the office's right-hand wall (x = OFFICE_X1):
## [z from, z to, doorway centre z, depth into the wall]. The doorway is
## where a door was painted on that wall, between the cubicle rows.
const MAIL_ROOM := [8.0, 18.5, 13.19, 12.0]
const OFFICE_Z0 := -24.67
const OFFICE_Z1 := 41.0

## Kitchen <-> break room: an open gap this wide in the wall between them.
const KITCHEN_BREAK_GAP := 4.4

const WALL_MAT := preload("res://Assets/Materials/OfficeWalls.tres")
const CARPET_MAT := preload("res://Assets/Materials/OfficeCarpet.tres")
const CEILING_MAT := preload("res://Assets/Materials/OfficeCeiling.tres")
const LIGHT_TEX := preload("res://Levels/Greyboxing/Textures/office_ceiling_light.png")
const FRIDGE := preload("res://Assets/Environments/Office/Fridge/fridge.tscn")
const DOOR_MESH := preload("res://Assets/Environments/Office/Door/M_DoorSim_Unwrapped.obj")
const DOOR_TEX := "res://Assets/Environments/Office/Door/Textures/Simple Door/M_DoorSim_Unwrapped_DefaultMaterial_BaseMap.png"
const FRAME_MESH := preload("res://Assets/Environments/Office/Door/M_DoorFrame_Unwrapped.obj")
const FRAME_TEX := "res://Assets/Environments/Office/Door/Textures/Door Frame/M_DoorFrame_Unwrapped_DefaultMaterial_BaseMap.png"
const PRINTER := preload("res://Assets/Environments/Office/Printer/printer.tscn")
const SWING_DOOR := preload("res://Scripts/Interactables/SwingDoor.gd")
const OFFICE_BUTTON := preload("res://Scripts/Office/OfficeButton.gd")
const REVOLVER_MESH := preload("res://Assets/Environments/Garage/Revolver/M_Revolver_Unwrapped.obj")
const REVOLVER_TEX := "res://Assets/Environments/Garage/Revolver/Textures/M_Revolver_Unwrapped_DefaultMaterial_BaseMap.png"
const MOP := preload("res://Assets/Environments/Office/Mop/M_Mop.obj")
const MOP_BUCKET := preload("res://Assets/Environments/Office/Mop/M_MopBucket_Unwrapped.obj")

## kind -> [{pos: Vector3, face: Vector3 (direction to look), room, sit: bool}]
var spots := {}
## spot dictionaries that are taken (an NPC is going to / using it)
var _claimed := {}
## room name -> AABB (floor area, for "is this in a room")
var rooms := {}
## The copiers' status lights - OfficeLife blinks them while copying.
var copier_lights: Array[MeshInstance3D] = []
## room name -> its SwingDoor (lock one: doors["Kitchen"].lock())
var doors := {}
## Table tops the copy job's documents can be left on (world positions).
var doc_spots: Array[Vector3] = []
## The revolver lying in the fridge (OfficeJobs takes it out).
var fridge_gun: Node3D

var _wall_mat: StandardMaterial3D
var _carpet_mat: StandardMaterial3D
var _ceiling_mat: StandardMaterial3D
var _nav: NavigationRegion3D
var _z_front: float
var _z_back: float
## The room being furnished: its pivot (back-left corner, scaled UNIT), its
## name and its size in real metres.
var _fur: Node3D
var _room := ""
var W := 0.0
var D := 0.0

## Material cache: colour -> material
var _mats := {}

func _ready() -> void:
	name = "OfficeWing"
	add_to_group("office_wing")
	_z_front = WALL_Z - WALL_T
	_z_back = _z_front - ROOM_DEPTH
	# (the office's materials are scaled for its one big mesh: tile these by
	# world position instead, about the same size)
	_wall_mat = WALL_MAT.duplicate()
	_wall_mat.uv1_triplanar = true
	_wall_mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	_carpet_mat = CARPET_MAT.duplicate()
	_carpet_mat.uv1_triplanar = true
	_carpet_mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	_ceiling_mat = CEILING_MAT.duplicate()
	_ceiling_mat.uv1_triplanar = true
	_ceiling_mat.uv1_scale = Vector3(0.3, 0.3, 0.3)
	_open_back_wall()
	_nav = NavigationRegion3D.new()
	_nav.name = "WingNav"
	add_child(_nav)
	_build_shell()
	for r in ROOMS:
		_fur = Node3D.new()
		_fur.name = "Furniture_" + r[0]
		_nav.add_child(_fur)
		_fur.global_position = Vector3(r[1], FLOOR_Y, _z_back)
		_fur.scale = Vector3.ONE * UNIT
		_room = r[0]
		W = (r[2] - r[1]) / UNIT
		D = ROOM_DEPTH / UNIT
		var fn := "_furnish_" + (r[0] as String).to_snake_case()
		if has_method(fn):
			call(fn)
	_build_mail_room()
	_light_rooms()
	_bake_nav()
	_link_doors.call_deferred()

## ---------------------------------------------------------------------
## Spots
## ---------------------------------------------------------------------

## A spot in the room being furnished (local real-metre position).
func _spot(kind: String, local: Vector3, face: Vector3, sit := false) -> void:
	if not spots.has(kind):
		spots[kind] = []
	var p := _fur.to_global(Vector3(local.x, 0.0, local.z))
	spots[kind].append({"kind": kind, "room": _room, "pos": Vector3(p.x, FLOOR_Y, p.z), "face": face.normalized(), "sit": sit})

## A free spot of this kind (random), claimed for the asker - or {} if none.
func claim_spot(kind: String) -> Dictionary:
	var free: Array = []
	for s in spots.get(kind, []):
		if not _claimed.has(s):
			free.append(s)
	if free.is_empty():
		return {}
	var s: Dictionary = free.pick_random()
	_claimed[s] = true
	return s

func free_spot(s: Dictionary) -> void:
	_claimed.erase(s)

## How many spots of this kind are free.
func free_count(kind: String) -> int:
	var n := 0
	for s in spots.get(kind, []):
		if not _claimed.has(s):
			n += 1
	return n

## Which room a point is in ("" = the main office).
func room_at(p: Vector3) -> String:
	for r in rooms:
		if (rooms[r] as AABB).grow(0.05).has_point(Vector3(p.x, 0.5, p.z)):
			return r
	return ""

## ---------------------------------------------------------------------
## The office's back wall
## ---------------------------------------------------------------------

## Takes the office mesh's back wall face out (it's one big flat quad) and
## hides the doors painted on it - the new wall (_build_shell) replaces it.
func _open_back_wall() -> void:
	var level := get_parent()
	var m := level.get_node_or_null("NavigationRegion3D/EmptyOfficeGreybox/MeshInstance3D") as MeshInstance3D
	if m == null:
		push_warning("OfficeWing: no office mesh to open the back wall of.")
		return
	# the back wall and the right-hand wall (the mail room's)
	var on_wall := func(p: Vector3) -> bool: return absf(p.z - WALL_Z) < 0.05 or absf(p.x - OFFICE_X1) < 0.05
	# render mesh: rebuild without the wall triangles
	var old: ArrayMesh = m.mesh
	var fresh := ArrayMesh.new()
	for s in old.get_surface_count():
		var arr := old.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		if idx.size() > 0:
			var keep := PackedInt32Array()
			for t in idx.size() / 3:
				var all_on := true
				for k in 3:
					if not on_wall.call(m.global_transform * v[idx[t * 3 + k]]):
						all_on = false
				if not all_on:
					keep.append_array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
			arr[Mesh.ARRAY_INDEX] = keep
		fresh.add_surface_from_arrays(old.surface_get_primitive_type(s), arr)
		fresh.surface_set_material(s, old.surface_get_material(s))
	m.mesh = fresh
	# collision: the same
	var cs := m.get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
	if cs and cs.shape is ConcavePolygonShape3D:
		var faces: PackedVector3Array = cs.shape.get_faces()
		var keep := PackedVector3Array()
		for t in faces.size() / 3:
			var all_on := true
			for k in 3:
				if not on_wall.call(cs.global_transform * faces[t * 3 + k]):
					all_on = false
			if not all_on:
				keep.append_array([faces[t * 3], faces[t * 3 + 1], faces[t * 3 + 2]])
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = cs.shape.backface_collision
		shape.set_faces(keep)
		cs.shape = shape
	# the painted doors on that wall
	var doors := level.get_node_or_null("NavigationRegion3D/EmptyOfficeGreybox/Doors")
	if doors:
		for d in doors.find_children("OfficeDoor*", "Node3D", true, false):
			if absf(d.global_position.z - WALL_Z) < 0.3:
				d.visible = false
			elif absf(d.global_position.x - OFFICE_X1) < 0.3 and absf(d.global_position.z - MAIL_ROOM[2]) < 1.5:
				d.visible = false   # (the mail room's real door goes there)

## ---------------------------------------------------------------------
## Walls, floors, ceilings (level units)
## ---------------------------------------------------------------------

func _build_shell() -> void:
	var zc := (_z_front + _z_back) * 0.5
	var wz := WALL_Z - WALL_T * 0.5
	# the new back wall of the office, with a doorway into every room
	var cuts: Array = []
	for r in ROOMS:
		cuts.append(r[3])
	cuts.sort()
	var x := OFFICE_X0 - WALL_T
	for c in cuts:
		_wall_x(x, c - DOOR_W * 0.5, wz, 0.0, WALL_H)
		x = c + DOOR_W * 0.5
	_wall_x(x, OFFICE_X1 + WALL_T, wz, 0.0, WALL_H)
	for c in cuts:
		_wall_x(c - DOOR_W * 0.5, c + DOOR_W * 0.5, wz, DOOR_H, WALL_H)
	# back and side walls of the wing
	_wall_x(OFFICE_X0 - WALL_T, OFFICE_X1 + WALL_T, _z_back - WALL_T * 0.5, 0.0, ROOM_H + 0.2)
	_wall_z(OFFICE_X0 - WALL_T * 0.5, _z_back, _z_front, 0.0, ROOM_H + 0.2)
	_wall_z(OFFICE_X1 + WALL_T * 0.5, _z_back, _z_front, 0.0, ROOM_H + 0.2)
	# walls between the rooms
	for i in range(1, ROOMS.size()):
		var wx: float = ROOMS[i][1]
		if ROOMS[i - 1][0] == "Kitchen" and ROOMS[i][0] == "BreakRoom":
			var g0 := zc - KITCHEN_BREAK_GAP * 0.5
			var g1 := zc + KITCHEN_BREAK_GAP * 0.5
			_wall_z(wx, _z_back, g0, 0.0, ROOM_H)
			_wall_z(wx, g1, _z_front, 0.0, ROOM_H)
			_wall_z(wx, g0, g1, DOOR_H, ROOM_H)
		else:
			_wall_z(wx, _z_back, _z_front, 0.0, ROOM_H)
	# floor and ceiling per room
	for r in ROOMS:
		var x0: float = r[1]
		var x1: float = r[2]
		var floor_mat: Material = _carpet_mat
		if r[0] in ["Bathroom", "Kitchen"]:
			floor_mat = _mat(Color(0.62, 0.64, 0.66))
		elif r[0] == "JanitorCloset":
			floor_mat = _mat(Color(0.38, 0.38, 0.36))
		_box(Vector3(x1 - x0, 0.2, ROOM_DEPTH), Vector3((x0 + x1) * 0.5, FLOOR_TOP - 0.1, zc), floor_mat, true, "Floor_" + r[0], _nav)
		_box(Vector3(x1 - x0, 0.2, ROOM_DEPTH), Vector3((x0 + x1) * 0.5, ROOM_H + 0.1, zc), _ceiling_mat, false, "Ceiling_" + r[0], _nav)
		rooms[r[0]] = AABB(Vector3(x0, FLOOR_Y, _z_back), Vector3(x1 - x0, ROOM_H, ROOM_DEPTH))
		# the doorway's floor through the wall (running on under the office
		# floor a little, so there's no edge to trip on)
		_box(Vector3(DOOR_W, 0.2, WALL_T + 1.2), Vector3(r[3], FLOOR_TOP - 0.1, wz + 0.5), floor_mat, true, "Threshold_" + r[0], _nav)
		doors[r[0]] = _make_door(Vector3(r[3], FLOOR_Y, wz), 0.0, r[0])

func _wall_x(x0: float, x1: float, zc: float, y0: float, y1: float) -> void:
	if x1 - x0 > 0.01 and y1 - y0 > 0.01:
		_box(Vector3(x1 - x0, y1 - y0, WALL_T), Vector3((x0 + x1) * 0.5, y0 + (y1 - y0) * 0.5, zc), _wall_mat, true, "Wall", _nav)

func _wall_z(xc: float, z0: float, z1: float, y0: float, y1: float) -> void:
	if z1 - z0 > 0.01 and y1 - y0 > 0.01:
		_box(Vector3(WALL_T, y1 - y0, z1 - z0), Vector3(xc, y0 + (y1 - y0) * 0.5, (z0 + z1) * 0.5), _wall_mat, true, "Wall", _nav)

## The door frame model in the doorway and a swinging door in it (hinged
## on the left, opening into the room) - unlocked. `at`: the doorway's
## middle on the floor; `yaw`: 0 = a room behind the back wall (towards
## -z), -90 degrees = one behind the right-hand wall (towards +x).
func _make_door(at: Vector3, yaw: float, room: String) -> StaticBody3D:
	var base := Node3D.new()
	base.name = "Door_" + room
	add_child(base)
	base.global_position = at
	base.rotation.y = yaw
	var frame := MeshInstance3D.new()
	frame.name = "DoorFrame"
	frame.mesh = FRAME_MESH
	frame.material_override = _tex_mat(FRAME_TEX)
	base.add_child(frame)
	frame.scale = Vector3.ONE * DOOR_SCALE
	# hinge at the left jamb; the door model's own hinge edge is its x = 0
	var door_w: float = DOOR_MESH.get_aabb().size.x * DOOR_SCALE
	var hinge := Node3D.new()
	hinge.name = "DoorHinge"
	base.add_child(hinge)
	hinge.position = Vector3(-door_w * 0.5, 0.0, 0.0)
	var panel := MeshInstance3D.new()
	panel.name = "Door"
	panel.mesh = DOOR_MESH
	panel.material_override = _tex_mat(DOOR_TEX)
	panel.scale = Vector3.ONE * DOOR_SCALE
	hinge.add_child(panel)
	var body := StaticBody3D.new()
	body.name = "DoorBody"
	body.set_script(SWING_DOOR)
	body.hinge = hinge
	body.is_locked = false
	body.has_outline = true
	body.mesh = panel
	body.persist_id = "office_wing_door_" + room
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	var ab: AABB = DOOR_MESH.get_aabb()
	sh.size = Vector3(ab.size.x, ab.size.y, 6.0)
	cs.shape = sh
	body.add_child(cs)
	body.position = Vector3(ab.get_center().x, ab.get_center().y, 0.0)
	panel.add_child(body)
	# the room's name on a plate on the door (office side, swings with it)
	var plate := Label3D.new()
	plate.text = room.capitalize()
	plate.font_size = 40
	plate.pixel_size = 0.0045 / DOOR_SCALE
	plate.modulate = Color(0.95, 0.92, 0.8)
	plate.outline_size = 8
	plate.outline_modulate = Color(0.1, 0.08, 0.05)
	panel.add_child(plate)
	plate.position = Vector3(ab.get_center().x, 165.0, ab.end.z + 0.6)
	return body

func _tex_mat(path: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m

## ---------------------------------------------------------------------
## The mail room (behind the right-hand wall)
## ---------------------------------------------------------------------

func _build_mail_room() -> void:
	var z0: float = MAIL_ROOM[0]
	var z1: float = MAIL_ROOM[1]
	var dz: float = MAIL_ROOM[2]
	var depth: float = MAIL_ROOM[3]
	var wx := OFFICE_X1 + WALL_T * 0.5          # the right-hand wall's middle
	var x_in := OFFICE_X1 + WALL_T              # the room's inside face
	var x_back := x_in + depth
	var xc := (x_in + x_back) * 0.5
	var zc := (z0 + z1) * 0.5
	# the office's right-hand wall again, with the doorway
	_wall_z(wx, OFFICE_Z0 - WALL_T, dz - DOOR_W * 0.5, 0.0, WALL_H)
	_wall_z(wx, dz + DOOR_W * 0.5, OFFICE_Z1 + WALL_T, 0.0, WALL_H)
	_wall_z(wx, dz - DOOR_W * 0.5, dz + DOOR_W * 0.5, DOOR_H, WALL_H)
	# the room's own walls, floor and ceiling
	_wall_z(x_back + WALL_T * 0.5, z0 - WALL_T, z1 + WALL_T, 0.0, ROOM_H + 0.2)
	_wall_x(x_in, x_back + WALL_T, z0 - WALL_T * 0.5, 0.0, ROOM_H + 0.2)
	_wall_x(x_in, x_back + WALL_T, z1 + WALL_T * 0.5, 0.0, ROOM_H + 0.2)
	_box(Vector3(depth, 0.2, z1 - z0), Vector3(xc, FLOOR_TOP - 0.1, zc), _carpet_mat, true, "Floor_MailRoom", _nav)
	_box(Vector3(depth, 0.2, z1 - z0), Vector3(xc, ROOM_H + 0.1, zc), _ceiling_mat, false, "Ceiling_MailRoom", _nav)
	_box(Vector3(WALL_T + 1.2, 0.2, DOOR_W), Vector3(wx - 0.5, FLOOR_TOP - 0.1, dz), _carpet_mat, true, "Threshold_MailRoom", _nav)
	rooms["MailRoom"] = AABB(Vector3(x_in, FLOOR_Y, z0), Vector3(depth, ROOM_H, z1 - z0))
	doors["MailRoom"] = _make_door(Vector3(wx, FLOOR_Y, dz), -PI * 0.5, "MailRoom")
	# furniture: in real metres, x across (z0 -> z1), z from the back wall
	# towards the office
	_fur = Node3D.new()
	_fur.name = "Furniture_MailRoom"
	_nav.add_child(_fur)
	_fur.global_position = Vector3(x_back, FLOOR_Y, z0)
	_fur.rotation.y = -PI * 0.5
	_fur.scale = Vector3.ONE * UNIT
	_room = "MailRoom"
	W = (z1 - z0) / UNIT
	D = depth / UNIT
	_furnish_mail_room()

func _furnish_mail_room() -> void:
	var wood := _mat(Color(0.5, 0.4, 0.3))
	var slot := _mat(Color(0.3, 0.24, 0.18))
	# pigeonholes along the back wall, letters in some
	_block(Vector3(W - 0.6, 1.8, 0.4), Vector3(W * 0.5, 0, 0.22), wood, true, "Pigeonholes")
	for row in 4:
		for col in 8:
			var at := Vector3(0.55 + col * (W - 1.1) / 7.0, 0.45 + row * 0.38, 0.42)
			_box(Vector3(0.28, 0.26, 0.02), at, slot, false, "Slot")
			if randf() < 0.4:
				_box(Vector3(0.2, 0.12, 0.02), at + Vector3(0, -0.04, 0.012), _mat(Color(0.95, 0.93, 0.85)), false, "Letter")
	# the sorting table with the outgoing mail tray on it
	var table := Vector3(W * 0.5, 0, 2.6)
	_block(Vector3(2.2, 0.85, 0.9), table, wood, true, "SortingTable")
	var tray := _block(Vector3(0.5, 0.1, 0.36), table + Vector3(0, 0.85, 0), _mat(Color(0.25, 0.4, 0.6)), false, "MailTray")
	for i in 4:
		_box(Vector3(0.22, 0.012, 0.11), table + Vector3(-0.08 + i * 0.05, 0.95 + i * 0.012, 0.02 * i), _mat(Color(0.95, 0.93, 0.85)), false, "Envelope")
	OFFICE_BUTTON.make(_fur, "mail_tray", table + Vector3(0, 1.0, 0), Vector3(0.6, 0.35, 0.5), tray)
	_sign("OUTGOING MAIL", table + Vector3(0, 1.45, 0), Color(0.9, 0.9, 0.85))
	# a mail cart and a parcel stack
	_block(Vector3(0.6, 0.8, 1.0), Vector3(W - 0.7, 0, 3.8), _mat(Color(0.35, 0.35, 0.38)), true, "MailCart")
	for i in 3:
		_block(Vector3(0.45, 0.3, 0.35), Vector3(0.5, i * 0.3, 4.6), _mat(Color(0.62, 0.47, 0.3)), true if i == 0 else false, "Parcel")
	doc_spots.append(_fur.to_global(table + Vector3(0.7, 0.86, 0)))

## A station's click box round `mesh` (OfficeButton - OfficeJobs handles it).
func _station(job: String, mesh: MeshInstance3D, pad := 0.05) -> StaticBody3D:
	var ab := mesh.get_aabb()
	return OFFICE_BUTTON.make(mesh, job, ab.get_center(), ab.size + Vector3.ONE * pad * 2.0, mesh)

## ---------------------------------------------------------------------
## Building blocks (sizes/positions local to `parent` - in a room's
## furniture pivot that's real metres)
## ---------------------------------------------------------------------

func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var key := "%s|%s" % [c.to_html(), glow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m

## A box centred at `at` (local to parent - default: the room's furniture),
## optionally solid (counts for the navigation mesh).
func _box(size: Vector3, at: Vector3, mat: Material, solid := true, n := "Box", parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	(parent if parent else _fur).add_child(mi)
	mi.position = at
	if solid:
		_solid(mi, size)
	return mi

func _solid(mi: Node3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	mi.add_child(body)

## A box standing on the floor: `at` is the middle of its footprint.
func _block(size: Vector3, at: Vector3, mat: Material, solid := true, n := "Box") -> MeshInstance3D:
	return _box(size, Vector3(at.x, at.y + size.y * 0.5, at.z), mat, solid, n)

func _cyl(radius: float, height: float, at: Vector3, mat: Material, solid := true, n := "Cylinder") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 14
	mi.mesh = cm
	mi.material_override = mat
	_fur.add_child(mi)
	mi.position = at
	if solid:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = height
		cs.shape = sh
		body.add_child(cs)
		mi.add_child(body)
	return mi

## A chair at `at` whose sitter looks along `face`: seat, back, a leg.
func _chair(at: Vector3, face: Vector3, seat_y := SEAT_Y, col := Color(0.2, 0.22, 0.26)) -> void:
	var root := Node3D.new()
	root.name = "Chair"
	_fur.add_child(root)
	root.position = Vector3(at.x, 0.0, at.z)
	root.rotation.y = atan2(face.x, face.z)
	var m := _mat(col)
	_box(Vector3(0.5, 0.07, 0.48), Vector3(0, seat_y - 0.035, 0), m, true, "Seat", root)
	_box(Vector3(0.5, 0.55, 0.06), Vector3(0, seat_y + 0.3, -0.24), m, false, "Back", root)
	_box(Vector3(0.07, seat_y - 0.07, 0.07), Vector3(0, (seat_y - 0.07) * 0.5, 0), _mat(Color(0.1, 0.1, 0.1)), false, "Leg", root)
## Seat height (real metres) that fits the workers' sitting pose.
const SEAT_Y := 0.47

## A loose prop model with its texture (the mop, the bucket), `h` real
## metres tall, standing at `at`.
func _model(mesh: Mesh, tex_path: String, at: Vector3, yaw_deg: float, h: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if ResourceLoader.exists(tex_path):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(tex_path)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mi.material_override = m
	_fur.add_child(mi)
	var mh := mesh.get_aabb().size.y
	if mh > 0.0001:
		mi.scale = Vector3.ONE * (h / mh)
	mi.rotation_degrees.y = yaw_deg
	mi.position = at
	var ab := mi.transform * mesh.get_aabb()
	mi.position.y += at.y - ab.position.y
	return mi

## A placed scene `h` real metres tall, standing on the floor at `at`.
func _scene(scene: PackedScene, at: Vector3, yaw_deg: float, h: float) -> Node3D:
	var n := scene.instantiate() as Node3D
	_fur.add_child(n)
	n.position = at
	n.rotation_degrees.y = yaw_deg
	var box := _local_box(n)
	if box.size.y > 0.0001:
		n.scale *= h / box.size.y
	box = _local_box(n)
	n.position.y += at.y - box.position.y
	return n

## The revolver on the fridge's middle shelf (under its Contents node, so
## it can only be taken once the door is open).
func _gun_in_fridge(fridge: Node3D) -> void:
	var contents := fridge.get_node_or_null("Contents") as Node3D
	if contents == null:
		return
	var body := fridge.get_node_or_null("MFridgeBody") as MeshInstance3D
	var box: AABB = body.get_aabb() if body else AABB(Vector3.ZERO, Vector3(60, 180, 60))
	var gun := MeshInstance3D.new()
	gun.name = "Revolver"
	gun.mesh = REVOLVER_MESH
	gun.material_override = _tex_mat(REVOLVER_TEX)
	contents.add_child(gun)
	# about 25 cm long, lying on its side on the shelf
	var gl: float = maxf(REVOLVER_MESH.get_aabb().size.x, REVOLVER_MESH.get_aabb().size.z)
	var parent_scale: float = contents.global_transform.basis.get_scale().x
	gun.scale = Vector3.ONE * (0.25 * UNIT / maxf(gl, 0.0001)) / maxf(parent_scale, 0.0001)
	gun.position = Vector3(box.get_center().x, box.position.y + box.size.y * 0.42, box.get_center().z)
	gun.rotation_degrees = Vector3(0, 70, 90)
	fridge_gun = gun
	_station("fridge_gun", gun, 2.0)

## Box round a node's meshes, in the furniture pivot's space.
func _local_box(n: Node3D) -> AABB:
	var inv := _fur.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (inv * m.global_transform) * m.get_aabb()
		box = a if first else box.merge(a)
		first = false
	return box

## A sign (real metres, in the room).
func _sign(text: String, at: Vector3, col := Color(1.0, 0.85, 0.3)) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = 8
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_fur.add_child(l)
	l.position = at

## ---------------------------------------------------------------------
## The rooms (real metres: x 0..W, z 0..D from the back wall, y up)
## ---------------------------------------------------------------------

func _furnish_janitor_closet() -> void:
	var shelf := _mat(Color(0.45, 0.42, 0.38))
	var card := _mat(Color(0.62, 0.47, 0.3))
	# metal shelving along the back wall, boxes and bottles on it
	_block(Vector3(W - 0.3, 1.9, 0.45), Vector3(W * 0.5, 0, 0.25), shelf, true, "Shelves")
	for i in 3:
		_block(Vector3(0.45, 0.35, 0.4), Vector3(0.6 + i * 0.75, 1.9, 0.25), card, false, "CardboardBox")
		_block(Vector3(0.4, 0.3, 0.38), Vector3(0.7 + i * 0.75, 0.95, 0.25), card, false, "CardboardBox")
	# chemicals on a side shelf
	_block(Vector3(0.4, 1.4, 2.2), Vector3(0.22, 0, 2.6), shelf, true, "SideShelf")
	for i in 5:
		_block(Vector3(0.12, 0.25, 0.12), Vector3(0.22, 1.4, 1.7 + i * 0.45), _mat([Color(0.2, 0.5, 0.9), Color(0.9, 0.8, 0.2), Color(0.3, 0.8, 0.3)][i % 3]), false, "Bottle")
	# a spare mop and bucket, a sink
	_model(MOP_BUCKET, "res://Assets/Environments/Office/Mop/Textures/Mop Bucket/M_MopBucket_Unwrapped_DefaultMaterial_BaseMap.png", Vector3(W - 0.5, 0, 1.4), 30.0, 0.4)
	_model(MOP, "res://Assets/Environments/Office/Mop/Textures/Mop/M_Mop_BaseColor.png", Vector3(W - 0.25, 0, 2.1), 10.0, 1.4)
	_block(Vector3(0.5, 0.6, 0.5), Vector3(W - 0.3, 0, 3.4), _mat(Color(0.8, 0.82, 0.85)), true, "MopSink")
	_spot("closet", Vector3(W * 0.5, 0, 1.4), Vector3(0, 0, -1))

func _furnish_bathroom() -> void:
	var tile := _mat(Color(0.82, 0.84, 0.86))
	var part := _mat(Color(0.55, 0.6, 0.62))
	var white := _mat(Color(0.95, 0.95, 0.95))
	# three stalls along the back wall, at the right
	var stall_w := 1.15
	var sx := W - stall_w * 3.0 - 0.05
	for i in 4:
		_block(Vector3(0.05, 1.9, 1.6), Vector3(sx + i * stall_w, 0.12, 0.8), part, true, "StallWall")
	for i in 3:
		var cx := sx + stall_w * (i + 0.5)
		# door swung open
		var door := _block(Vector3(0.6, 1.75, 0.04), Vector3(cx - 0.28, 0.12, 1.62), part, false, "StallDoor")
		door.rotation_degrees.y = -40.0
		_block(Vector3(0.4, 0.42, 0.55), Vector3(cx, 0, 0.32), white, true, "Toilet")
		_block(Vector3(0.42, 0.4, 0.18), Vector3(cx, 0.42, 0.09), white, false, "Cistern")
		_spot("stall", Vector3(cx, 0, 0.95), Vector3(0, 0, 1))
	# sinks along the left wall under a mirror
	_block(Vector3(0.55, 0.85, 3.0), Vector3(0.28, 0, 4.6), tile, true, "SinkCounter")
	_box(Vector3(0.02, 0.9, 2.8), Vector3(0.01, 1.55, 4.6), _mat(Color(0.7, 0.8, 0.85), 0.25), false, "Mirror")
	for i in 3:
		var z := 3.6 + i * 1.0
		_box(Vector3(0.36, 0.06, 0.42), Vector3(0.3, 0.88, z), white, false, "Sink")
		_spot("sink", Vector3(0.95, 0, z), Vector3(-1, 0, 0))
	# hand dryer, bin
	_box(Vector3(0.12, 0.3, 0.25), Vector3(0.06, 1.2, 6.5), white, false, "Dryer")
	_cyl(0.18, 0.5, Vector3(0.35, 0.25, 7.0), _mat(Color(0.3, 0.3, 0.3)), true, "Bin")

func _furnish_copy_room() -> void:
	var paper := _mat(Color(0.97, 0.97, 0.95))
	for i in 2:
		var cx := 1.0 + i * 1.9
		# the printer model (cm), facing the room, with a solid box round it
		var copier := _scene(PRINTER, Vector3(cx, 0, 0.5), 0.0, 1.16)
		copier.name = "Copier"
		var cb := _local_box(copier)
		var solid := Node3D.new()
		_fur.add_child(solid)
		solid.position = cb.get_center()
		_solid(solid, cb.size)
		copier_lights.append(_box(Vector3(0.06, 0.03, 0.03), Vector3(cx + cb.size.x * 0.3, cb.end.y + 0.015, cb.end.z - 0.08), _mat(Color(0.2, 0.9, 0.3), 1.5), false, "CopierLight"))
		var cm := copier.find_children("*", "MeshInstance3D", true, false)
		OFFICE_BUTTON.make(_fur, "copier", cb.get_center(), cb.size + Vector3.ONE * 0.1, cm[0] if not cm.is_empty() else null)
		_spot("copier", Vector3(cx, 0, 1.3), Vector3(0, 0, -1))
	# paper shelf in the corner, a sorting table
	_block(Vector3(0.45, 1.8, 1.6), Vector3(W - 0.25, 0, 1.2), _mat(Color(0.45, 0.42, 0.38)), true, "PaperShelf")
	for i in 3:
		_block(Vector3(0.35, 0.2, 0.3), Vector3(W - 0.25, 1.8, 0.6 + i * 0.5), paper, false, "Ream")
	_block(Vector3(1.8, 0.85, 0.8), Vector3(W * 0.5, 0, 5.0), _mat(Color(0.5, 0.4, 0.3)), true, "SortTable")
	doc_spots.append(_fur.to_global(Vector3(W * 0.5 + 0.5, 0.86, 5.0)))
	# the filing cabinet (the copy job files its copies here)
	var cab := _block(Vector3(0.5, 1.35, 0.6), Vector3(0.3, 0, 3.2), _mat(Color(0.55, 0.57, 0.6)), true, "FilingCabinet")
	for i in 4:
		_box(Vector3(0.02, 0.26, 0.44), Vector3(0.56, 0.2 + i * 0.32, 3.2), _mat(Color(0.4, 0.42, 0.45)), false, "Drawer")
		_box(Vector3(0.03, 0.03, 0.12), Vector3(0.58, 0.28 + i * 0.32, 3.2), _mat(Color(0.15, 0.15, 0.15)), false, "Handle")
	_station("filing", cab)
	_sign("FILING", Vector3(0.3, 1.6, 3.2), Color(0.9, 0.9, 0.85))
	_block(Vector3(0.4, 0.12, 0.3), Vector3(W * 0.5 - 0.4, 0.85, 5.0), paper, false, "PaperStack")
	_spot("copier", Vector3(W * 0.5, 0, 5.75), Vector3(0, 0, -1))

func _furnish_meeting_room() -> void:
	var cx := W * 0.5
	var cz := 4.2
	var wood := _mat(Color(0.36, 0.25, 0.17))
	_box(Vector3(3.6, 0.06, 1.3), Vector3(cx, 0.74, cz), wood, true, "Table")
	doc_spots.append(_fur.to_global(Vector3(cx - 1.0, 0.78, cz)))
	_block(Vector3(3.0, 0.71, 0.25), Vector3(cx, 0, cz), _mat(Color(0.15, 0.12, 0.1)), true, "TableBase")
	# whiteboard on the back wall, a screen on the side
	_box(Vector3(2.4, 1.1, 0.04), Vector3(cx, 1.5, 0.03), _mat(Color(0.96, 0.97, 0.98), 0.15), false, "Whiteboard")
	_box(Vector3(0.04, 0.8, 1.4), Vector3(0.03, 1.5, cz), _mat(Color(0.08, 0.1, 0.14), 0.3), false, "Screen")
	for sx in [-1.2, -0.4, 0.4, 1.2]:
		for side in [-1, 1]:
			var at := Vector3(cx + sx, 0, cz + side * 0.95)
			var face := Vector3(0, 0, -side)
			_chair(at, face)
			_spot("meeting", at, face, true)
	var head := Vector3(cx + 2.25, 0, cz)
	_chair(head, Vector3(-1, 0, 0))
	_spot("meeting", head, Vector3(-1, 0, 0), true)

func _furnish_kitchen() -> void:
	var counter := _mat(Color(0.75, 0.73, 0.7))
	var top := _mat(Color(0.3, 0.3, 0.32))
	# counter along the back wall (the fridge stands at its left end)
	_block(Vector3(W - 1.2, 0.88, 0.6), Vector3(W * 0.5 + 0.55, 0, 0.32), counter, true, "Counter")
	_block(Vector3(W - 1.2, 0.04, 0.64), Vector3(W * 0.5 + 0.55, 0.88, 0.32), top, false, "CounterTop")
	# sink, coffee machine, microwave on it
	_box(Vector3(0.6, 0.04, 0.4), Vector3(1.6, 0.92, 0.32), _mat(Color(0.8, 0.82, 0.85)), false, "KitchenSink")
	_spot("counter", Vector3(1.6, 0, 1.05), Vector3(0, 0, -1))
	var coffee := _block(Vector3(0.3, 0.42, 0.32), Vector3(2.6, 0.9, 0.3), _mat(Color(0.1, 0.1, 0.1)), false, "CoffeeMachine")
	_station("coffee", coffee)
	_box(Vector3(0.05, 0.04, 0.02), Vector3(2.68, 1.2, 0.47), _mat(Color(0.9, 0.2, 0.1), 2.0), false, "CoffeeLight")
	_spot("coffee", Vector3(2.6, 0, 1.05), Vector3(0, 0, -1))
	_block(Vector3(0.5, 0.3, 0.38), Vector3(3.5, 0.9, 0.3), _mat(Color(0.85, 0.85, 0.85)), false, "Microwave")
	_spot("counter", Vector3(3.5, 0, 1.05), Vector3(0, 0, -1))
	# the fridge (it opens - fridge.tscn)
	var fridge := _scene(FRIDGE, Vector3(0.45, 0, 0.45), 0.0, 1.8)
	_gun_in_fridge(fridge)
	_spot("fridge", Vector3(0.5, 0, 1.5), Vector3(0, 0, -1))
	# a round table in the middle
	_cyl(0.5, 0.04, Vector3(W * 0.5, 0.76, 4.8), _mat(Color(0.85, 0.85, 0.82)), true, "KitchenTable")
	doc_spots.append(_fur.to_global(Vector3(W * 0.5 + 0.15, 0.79, 4.7)))
	_cyl(0.05, 0.74, Vector3(W * 0.5, 0.37, 4.8), _mat(Color(0.15, 0.15, 0.15)), false, "TableLeg")
	_spot("counter", Vector3(W * 0.5, 0, 5.6), Vector3(0, 0, -1))
	# water cooler by the door
	_block(Vector3(0.35, 1.2, 0.35), Vector3(W - 0.3, 0, D - 1.6), _mat(Color(0.85, 0.85, 0.88)), true, "WaterCooler")
	_block(Vector3(0.3, 0.4, 0.3), Vector3(W - 0.3, 1.2, D - 1.6), _mat(Color(0.5, 0.7, 0.95)), false, "WaterBottle")
	_spot("coffee", Vector3(W - 0.95, 0, D - 1.6), Vector3(1, 0, 0))

func _furnish_break_room() -> void:
	var fabric := _mat(Color(0.3, 0.38, 0.5))
	# couch along the back wall
	var couch_x := W * 0.5
	_block(Vector3(2.0, 0.42, 0.75), Vector3(couch_x, 0, 0.42), fabric, true, "CouchSeat")
	_block(Vector3(2.0, 0.5, 0.2), Vector3(couch_x, 0.42, 0.1), fabric, false, "CouchBack")
	for side in [-1, 1]:
		_block(Vector3(0.2, 0.6, 0.75), Vector3(couch_x + side * 1.1, 0, 0.42), fabric, true, "CouchArm")
	for i in 3:
		_spot("couch", Vector3(couch_x - 0.65 + i * 0.65, 0, 0.62), Vector3(0, 0, 1), true)
	_block(Vector3(1.0, 0.35, 0.5), Vector3(couch_x, 0, 1.55), _mat(Color(0.36, 0.25, 0.17)), true, "CoffeeTable")
	# a table with two chairs
	var tc := Vector3(W * 0.5 + 0.3, 0, 5.2)
	_cyl(0.45, 0.04, tc + Vector3(0, 0.74, 0), _mat(Color(0.85, 0.85, 0.82)), true, "BreakTable")
	doc_spots.append(_fur.to_global(tc + Vector3(0.1, 0.77, 0.1)))
	_cyl(0.05, 0.72, tc + Vector3(0, 0.36, 0), _mat(Color(0.15, 0.15, 0.15)), false, "TableLeg")
	for side in [-1, 1]:
		var at := tc + Vector3(side * 0.8, 0, 0)
		_chair(at, Vector3(-side, 0, 0))
		_spot("break_seat", at, Vector3(-side, 0, 0), true)
	# vending machine on the right wall
	var vend := _block(Vector3(0.75, 1.85, 0.9), Vector3(W - 0.4, 0, 3.0), _mat(Color(0.6, 0.1, 0.12)), true, "VendingMachine")
	_station("vending", vend)
	_sign("SNACKS 1 coin", Vector3(W - 0.82, 1.95, 3.0), Color(1.0, 0.85, 0.3))
	_box(Vector3(0.02, 1.2, 0.6), Vector3(W - 0.78, 1.05, 2.95), _mat(Color(0.75, 0.85, 0.9), 0.8), false, "VendingGlass")
	_spot("vending", Vector3(W - 1.3, 0, 3.0), Vector3(1, 0, 0))
	# the shop: Gus at a folding table by the kitchen gap, with a sign
	var shop := Vector3(0.45, 0, 3.4)
	_block(Vector3(0.6, 0.72, 1.1), shop + Vector3(0.65, 0, 0), _mat(Color(0.55, 0.5, 0.42)), true, "ShopTable")
	for i in 3:
		_block(Vector3(0.1, 0.16, 0.1), shop + Vector3(0.65, 0.72, -0.3 + i * 0.3), _mat(Color(0.3, 0.85, 0.95), 0.6), false, "StaminaCharge")
	_chair(shop, Vector3(1, 0, 0))
	_spot("vendor", shop, Vector3(1, 0, 0), true)
	_sign("STAMINA CHARGES\n5 coins", shop + Vector3(0.65, 1.55, 0))

## ---------------------------------------------------------------------
## Lights
## ---------------------------------------------------------------------

func _light_rooms() -> void:
	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_texture = LIGHT_TEX
	panel_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	panel_mat.emission_enabled = true
	panel_mat.emission_texture = LIGHT_TEX
	panel_mat.emission_energy_multiplier = 0.6
	for r in rooms:
		var box: AABB = rooms[r]
		var c := box.get_center()
		# one panel per 8 m of depth
		for k in 2:
			var z := box.position.z + box.size.z * (0.28 + 0.44 * k)
			var panel := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(minf(2.64, box.size.x - 1.0), 3.28)
			pm.flip_faces = true
			panel.mesh = pm
			panel.material_override = panel_mat
			add_child(panel)
			panel.global_position = Vector3(c.x, ROOM_H - 0.01, z)
			var l := OmniLight3D.new()
			l.light_energy = 1.6
			l.omni_range = maxf(box.size.x, 9.0) * 1.2
			l.light_color = Color(1.0, 0.97, 0.9)
			add_child(l)
			l.global_position = Vector3(c.x, ROOM_H - 0.6, z)

## ---------------------------------------------------------------------
## Navigation
## ---------------------------------------------------------------------

func _bake_nav() -> void:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.75
	nm.agent_height = 3.25
	nm.agent_max_climb = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, _nav)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	_nav.navigation_mesh = nm

## A two-way link through every doorway: office side (on the office's own
## nav mesh) to room side (on ours).
func _link_doors() -> void:
	var map := get_world_3d().navigation_map
	await HelperManager.nav_map_updated(get_tree(), map)
	if not is_inside_tree():
		return
	for r in ROOMS:
		var x: float = r[3]
		var outside := NavigationServer3D.map_get_closest_point(map, Vector3(x, 0.3, WALL_Z + 2.5))
		var inside := Vector3(x, FLOOR_Y, _z_front - 1.8)
		var link := NavigationLink3D.new()
		link.name = "DoorLink_" + r[0]
		link.bidirectional = true
		add_child(link)
		link.global_position = Vector3.ZERO
		link.start_position = outside
		link.end_position = inside
	# and the mail room, through the right-hand wall
	var dz: float = MAIL_ROOM[2]
	var mail := NavigationLink3D.new()
	mail.name = "DoorLink_MailRoom"
	mail.bidirectional = true
	add_child(mail)
	mail.global_position = Vector3.ZERO
	mail.start_position = NavigationServer3D.map_get_closest_point(map, Vector3(OFFICE_X1 - 2.5, 0.3, dz))
	mail.end_position = Vector3(OFFICE_X1 + WALL_T + 1.8, FLOOR_Y, dz)
