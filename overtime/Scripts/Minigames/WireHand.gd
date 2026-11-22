## No Exit
## Overtime Studios
## Wire Hand
## - In the battery minigame the mouse pointer is hidden and the player's own
##   hand reaches in instead: it follows the mouse over the battery, opens up
##   when it touches a wire (a click then takes it - it doesn't have to be
##   right on it), closes round the wire while it's dragged (the wire stays
##   right in its grip) and lets go when the wire is dropped or connects.
## - Two hands (WireHand.use_model, switched in the dev pause menu's Dev Tools):
##     simple (default) - a low-poly hand built here from blocks: palm, two-
##                        joint fingers, thumb and a sleeved forearm
##     model            - the player's arm model (ArmMenu), fingers curled from
##                        its bones, curling round the wire as it holds it
## - Made by Player while minigameThree is on (WireHand.update()).

extends Node3D

## Which hand: false = the simple built one, true = the arm model.
static var use_model := false

## How high above the wires the grip floats while not holding one (metres).
const HOVER_LIFT := 0.06
const POSE_TIME := 0.12

## Poses: (knuckle curl, middle-joint curl, finger spread), degrees.
## Simple hand:
const S_RELAXED := Vector3(18.0, 22.0, 4.0)
const S_OPEN := Vector3(2.0, 4.0, 9.0)
const S_GRIP := Vector3(72.0, 85.0, 0.0)
## Model hand: flat and firm, fingers apart (it looked limp hanging curled).
const M_RELAXED := Vector3(4.0, 5.0, 7.0)
const M_OPEN := Vector3(-6.0, -3.0, 12.0)
const M_GRIP := Vector3(62.0, 70.0, 0.0)

static var _hand: Node3D

var _model := false              # which hand this one is
var _curl := Vector3.ZERO
var _scale := 2.0
var _grip := Vector3.ZERO        # the grip point (hand space) while hovering
var _hold_grip := Vector3.ZERO   # ... and while holding a wire
var _grip_curl := S_GRIP
var _pose_tw: Tween
var _pose := ""
var _plane_y := 0.0

## Called every frame by Player: makes / moves / removes the hand (and
## remakes it if the dev toggle switched hands).
static func update(player: Node) -> void:
	var on: bool = PlayerManager.minigameThree and not PlayerManager.dying
	if is_instance_valid(_hand) and (not on or _hand._model != use_model):
		_hand.name = "WireHandGone"
		_hand.queue_free()
		_hand = null
		if not on and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not on:
		return
	if not is_instance_valid(_hand):
		var scene := player.get_tree().current_scene
		if scene == null:
			return
		_hand = Node3D.new()
		_hand.set_script(load("res://Scripts/Minigames/WireHand.gd"))
		_hand.name = "WireHand"
		scene.add_child(_hand)
	_hand._follow(player)

func _ready() -> void:
	_model = use_model
	if _model:
		_build_model()
	else:
		_build_simple()
	_set_curl(_relaxed())

func _relaxed() -> Vector3:
	return M_RELAXED if _model else S_RELAXED

func _open() -> Vector3:
	return M_OPEN if _model else S_OPEN

## ---------------------------------------------------------------------
## Following the mouse
## ---------------------------------------------------------------------

func _follow(player: Node) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN   # the hand is the pointer
	var mouse := get_viewport().get_mouse_position()
	var held: Node3D = player.grabbed_object
	# fingers point "up the screen" (away from the player), palm down, the
	# arm coming in from the bottom of the screen
	var fwd: Vector3 = cam.global_basis.y
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = -cam.global_basis.z
		fwd.y = 0.0
	fwd = fwd.normalized()
	if is_instance_valid(held):
		# the hand turns across the wire and its fingers curl just enough to
		# fit round it; the middle of that curl stays on the cursor and the
		# wire slides into it (Player) - so the wire sits in the palm, the
		# fingers round it, not through it
		var w := wire_shape(held)
		var axis: Vector3 = w[1]
		var across := Vector3(axis.z, 0.0, -axis.x).normalized()
		if across.dot(fwd) < 0.0:
			across = -across
		if across.length() > 0.01:
			fwd = across
		_fit_grip(w[4], w[2])   # round its widest side
		_place(fwd, _cursor_on(cam, mouse, w[0].y), _hold_grip)
		_go_pose("grip", _grip_curl)
		return
	# not holding: the grip floats just over the wires, under the cursor
	_plane_y = _wires_height() + HOVER_LIFT
	var at := _cursor_on(cam, mouse, _plane_y)
	if at == Vector3.INF:
		return
	_place(fwd, at, _grip)
	# open up when a click would take a wire
	if wire_touched(cam, mouse) != null:
		_go_pose("open", _open())
	else:
		_go_pose("relaxed", _relaxed())

func _cursor_on(cam: Camera3D, mouse: Vector2, y: float) -> Vector3:
	var at: Variant = Plane(Vector3.UP, y).intersects_ray(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))
	return at if at != null else Vector3.INF

## Turns the hand to point along `fwd` (palm down) with `grip` (a point in
## hand space) on `at`.
func _place(fwd: Vector3, at: Vector3, grip: Vector3) -> void:
	if at == Vector3.INF:
		return
	var right := fwd.cross(Vector3.UP).normalized()
	global_basis = Basis(right, Vector3.UP, -fwd).scaled(Vector3.ONE * _scale)
	global_position = at - global_basis * grip

func _wires_height() -> float:
	for w in [PlayerManager.PositiveWire, PlayerManager.NegativeWire]:
		if is_instance_valid(w) and w.visible:
			return w.global_position.y
	return global_position.y

## ---------------------------------------------------------------------
## Touching a wire
## ---------------------------------------------------------------------

## How far past the wire's surface the hand still counts as touching it.
const TOUCH_REACH := 0.1
## Room left between the fingers and the wire when holding it.
const GRIP_CLEARANCE := 0.024   # (the straight finger segments cut inside the curve a little)

## A wire's shape: [centre, long axis (world, unit), half its length, its
## radius at its thinnest, at its widest], from its mesh (it isn't round).
static func wire_shape(wire: Node3D) -> Array:
	var mesh: MeshInstance3D = null
	for c in wire.get_children():
		if c is MeshInstance3D and c.mesh:
			mesh = c
			break
	if mesh == null:
		return [wire.global_position, Vector3.RIGHT, 0.1, 0.05, 0.05]
	var box := mesh.get_aabb()
	var s := mesh.global_basis.get_scale()
	var dims := [box.size.x * s.x, box.size.y * s.y, box.size.z * s.z]
	var long := 0
	for i in 3:
		if dims[i] > dims[long]:
			long = i
	var others := []
	for i in 3:
		if i != long:
			others.append(dims[i])
	var axis: Vector3 = mesh.global_basis[long].normalized()
	return [mesh.global_transform * box.get_center(), axis, dims[long] * 0.5, minf(others[0], others[1]) * 0.5, maxf(others[0], others[1]) * 0.5]

## The wire the hand is touching (or the cursor is on), or null: the point
## under the cursor at a wire's height within its thickness + TOUCH_REACH of
## its centre line.
static func wire_touched(cam: Camera3D, mouse: Vector2) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for w in [PlayerManager.PositiveWire, PlayerManager.NegativeWire]:
		if not is_instance_valid(w) or not w.is_visible_in_tree() or not w.is_in_group("grabbable"):
			continue
		var s := wire_shape(w)
		var c: Vector3 = s[0]
		var at: Variant = Plane(Vector3.UP, c.y).intersects_ray(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))
		if at == null:
			continue
		var d: Vector3 = at as Vector3 - c
		var along := clampf(d.dot(s[1]), -s[2], s[2])
		var off: float = (d - s[1] * along).length()
		if off <= s[3] + TOUCH_REACH and off < best_d:
			best_d = off
			best = w
	return best

## ---------------------------------------------------------------------
## Poses (both hands)
## ---------------------------------------------------------------------

func _go_pose(pose_name: String, curl: Vector3) -> void:
	if _pose == pose_name:
		return
	_pose = pose_name
	if _pose_tw and _pose_tw.is_valid():
		_pose_tw.kill()
	_pose_tw = create_tween()
	_pose_tw.tween_method(_set_curl, _curl, curl, POSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _set_curl(c: Vector3) -> void:
	_curl = c
	if _model:
		_set_curl_model(c)
	else:
		_set_curl_simple(c)

## ---------------------------------------------------------------------
## The simple hand (hand space: fingers toward -Z, palm facing -Y, right
## hand so the thumb is on the -X side; metres at real size, the garage is
## about twice that)
## ---------------------------------------------------------------------
const S_SCALE := 2.0
const SKIN := Color(0.5, 0.38, 0.31)   # toned for the bright light over the battery
const SLEEVE := Color(0.16, 0.17, 0.2)
## Each finger's share of the spread (index ... little finger).
const SPREAD_SHARE := [1.5, 0.5, -0.5, -1.5]
## Finger lengths (index ... little finger). A shorter finger bends by a
## smaller angle, so they all curl round the same circle (the held wire).
const S_LENGTHS := [0.085, 0.095, 0.09, 0.07]

var _fingers: Array[Array] = []   # [knuckle joint, middle joint]
var _thumb: Array[Node3D] = []

func _build_simple() -> void:
	_scale = S_SCALE
	_grip = Vector3(0.0, -0.035, -0.105)
	_hold_grip = _grip
	_grip_curl = S_GRIP
	var skin := _mat(SKIN)
	var sleeve := _mat(SLEEVE)
	# forearm: from the wrist back toward the player and up out of view
	var arm := MeshInstance3D.new()
	var arm_mesh := CylinderMesh.new()
	arm_mesh.top_radius = 0.044      # the elbow end
	arm_mesh.bottom_radius = 0.032   # the wrist end
	arm_mesh.height = 0.5
	arm.mesh = arm_mesh
	arm.material_override = sleeve
	add_child(arm)
	# a cylinder runs along its Y: lay it from the wrist back toward the
	# player (+Z) and up, its wrist end right at the back of the hand
	var up_back := Vector3(0.0, sin(deg_to_rad(20.0)), cos(deg_to_rad(20.0)))
	var x := Vector3.RIGHT
	arm.basis = Basis(x, up_back, x.cross(up_back))
	arm.position = Vector3(0.0, 0.0, 0.015) + up_back * (arm_mesh.height * 0.5)
	_box(Vector3(0.06, 0.035, 0.05), skin)   # wrist
	var palm := _box(Vector3(0.085, 0.028, 0.095), skin)
	palm.position = Vector3(0.0, 0.0, -0.06)
	# four fingers (index on the thumb side), two joints each
	var xs := [-0.03, -0.01, 0.01, 0.03]
	var lengths: Array = S_LENGTHS
	for i in 4:
		var knuckle := Node3D.new()
		add_child(knuckle)
		knuckle.position = Vector3(xs[i], -0.002, -0.108)
		var near := _box(Vector3(0.018, 0.018, lengths[i] * 0.55), skin, knuckle)
		near.position = Vector3(0, 0, -lengths[i] * 0.275)
		var middle := Node3D.new()
		knuckle.add_child(middle)
		middle.position = Vector3(0, 0, -lengths[i] * 0.55)
		var far := _box(Vector3(0.016, 0.016, lengths[i] * 0.45), skin, middle)
		far.position = Vector3(0, 0, -lengths[i] * 0.225)
		_fingers.append([knuckle, middle])
	# thumb: from the side of the palm, angled forward and in
	var thumb_base := Node3D.new()
	add_child(thumb_base)
	thumb_base.position = Vector3(-0.045, -0.008, -0.035)
	var t1 := _box(Vector3(0.022, 0.02, 0.045), skin, thumb_base)
	t1.position = Vector3(0, 0, -0.022)
	var thumb_tip := Node3D.new()
	thumb_base.add_child(thumb_tip)
	thumb_tip.position = Vector3(0, 0, -0.045)
	var t2 := _box(Vector3(0.019, 0.018, 0.035), skin, thumb_tip)
	t2.position = Vector3(0, 0, -0.017)
	_thumb = [thumb_base, thumb_tip]

func _set_curl_simple(c: Vector3) -> void:
	for i in _fingers.size():
		var f: Array = _fingers[i]
		var k: float = S_LENGTHS[i] / S_LENGTHS[1]
		f[0].basis = Basis(Vector3.UP, deg_to_rad(c.z * SPREAD_SHARE[i])) * Basis(Vector3.RIGHT, deg_to_rad(-c.x * k))
		f[1].basis = Basis(Vector3.RIGHT, deg_to_rad(-c.y * k))
	# the thumb closes with the fingers, only as far as it fits (_fit_thumb)
	_pose_thumb(_thumb_t(c, S_OPEN.x))

func _box(size: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m

## ---------------------------------------------------------------------
## The model hand: the player's arm model (ArmMenu - a right forearm and hand
## with a finger skeleton). Its fingers curl about each bone's X and spread
## about its Z; how it faces is measured from its bones, then it's turned
## palm-down, fingers pointing into the screen, the forearm rising back
## toward the camera, at its normal size (MODEL_SCALE). When it holds a wire
## its fingers curl just enough to fit round it (as far as they reach).
## ---------------------------------------------------------------------
const ARM_SCENE := "res://Assets/Characters/Player/ArmMenu/Animation_ArmMenu.fbx"
const FINGERS := ["POINTER", "MIDDLE", "RING", "PINKY"]
## Fingers point this far down from level (degrees) - little, so the hand
## reads flat rather than hanging.
const DIP := 8.0
## Darkens the arm's texture (the light over the battery is bright).
const ARM_TINT := Color(0.42, 0.4, 0.4)
## The arm model's size in the garage.
const MODEL_SCALE := 0.8

var _arm: Node3D
var _skel: Skeleton3D
var _model_xf := Transform3D()   # arm model -> hand space (fwd -Z, palm -Y)
var _fit_radius := -1.0
var _spread_sign := 1.0          # which way round "apart" is for this rig

func _build_model() -> void:
	_scale = MODEL_SCALE
	_grip_curl = M_GRIP
	_arm = (load(ARM_SCENE) as PackedScene).instantiate()
	add_child(_arm)
	_skel = _arm.get_node("Armature/Skeleton3D")
	var ap := _arm.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap:
		ap.stop()
	for mi in _arm.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# the imported material glows (emission on) - lit like everything else
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m is StandardMaterial3D:
				var lit: StandardMaterial3D = m.duplicate()
				lit.emission_enabled = false
				# the light over the battery is strong - keep the skin from washing out
				lit.albedo_color = ARM_TINT
				mi.set_surface_override_material(s, lit)
	# which way spreads the fingers apart on this rig
	_set_curl_model(Vector3.ZERO)
	var apart := _bone_pos("POINTER tip R").distance_to(_bone_pos("PINKY tip R"))
	_set_curl_model(Vector3(0, 0, 10.0))
	if _bone_pos("POINTER tip R").distance_to(_bone_pos("PINKY tip R")) < apart:
		_spread_sign = -1.0
	# measure it, in the arm's own space: elbow -> middle fingertip is forward,
	# the way the fingertip moves as it curls is the palm side
	_set_curl_model(Vector3.ZERO)
	var elbow := _bone_pos("forearm R")
	var tip_open := _bone_pos("MIDDLE tip R")
	_set_curl_model(M_GRIP)
	var tip_shut := _bone_pos("MIDDLE tip R")
	var fwd := (tip_open - elbow).normalized()
	var palm := (tip_shut - tip_open)
	palm = (palm - fwd * palm.dot(fwd)).normalized()   # square to forward
	# hand space: forward = -Z (dipped down by DIP), palm = -Y
	var want_fwd := Vector3(0, -sin(deg_to_rad(DIP)), -cos(deg_to_rad(DIP)))
	var want_palm := Vector3(0, -cos(deg_to_rad(DIP)), sin(deg_to_rad(DIP)))
	var from := Basis(fwd, palm, fwd.cross(palm)).orthonormalized()
	var to := Basis(want_fwd, want_palm, want_fwd.cross(want_palm)).orthonormalized()
	_model_xf = Transform3D(to * from.inverse(), Vector3.ZERO)
	_arm.transform = _model_xf
	# hovering, the grip point is under the knuckles
	var grip_model := (_bone_pos("POINTER base R") + _bone_pos("PINKY base R") + tip_shut * 2.0) / 4.0
	_grip = _model_xf * grip_model
	_hold_grip = _grip

func _set_curl_model(c: Vector3) -> void:
	if _skel == null:
		return
	for i in FINGERS.size():
		var f: String = FINGERS[i]
		_bend("%s meta1 R" % f, c.x, c.z * SPREAD_SHARE[i] * _spread_sign)
		_bend("%s meta2 R" % f, c.y)
		_bend("%s tip R" % f, c.y * 0.8)
	# the thumb closes with the fingers, only as far as it fits (_fit_thumb)
	_pose_thumb(_thumb_t(c, M_OPEN.x))

func _bend(bone: String, curl: float, spread: float = 0.0) -> void:
	var i := _skel.find_bone(bone)
	if i < 0:
		return
	var q := _skel.get_bone_rest(i).basis.get_rotation_quaternion()
	q = q * Quaternion(Vector3.BACK, deg_to_rad(spread)) * Quaternion(Vector3.RIGHT, deg_to_rad(curl))
	_skel.set_bone_pose_rotation(i, q)

## A bone's position in the arm model's space.
func _bone_pos(bone: String) -> Vector3:
	var i := _skel.find_bone(bone)
	var node_path_xf := Transform3D()
	var n: Node = _skel
	while n != _arm and n != null:
		node_path_xf = (n as Node3D).transform * node_path_xf
		n = n.get_parent()
	return node_path_xf * _skel.get_bone_global_pose(i).origin

## Wrapping round the wire: the fingers are curled just enough that the
## circle their joints make (a little bigger, for the fingers' own
## thickness) fits the wire, and that circle's middle goes on the wire.
func _fit_grip(wire_r: float, half_len: float) -> void:
	var radius := wire_r + GRIP_CLEARANCE
	if absf(radius - _fit_radius) < 0.001 or (_model and _skel == null) or (not _model and _fingers.is_empty()):
		return
	_fit_radius = radius
	var saved := _curl
	var best_err := INF
	for a in range(20, 125, 3):
		var c := Vector3(a, a * 1.1, 0.0)
		_set_curl(c)
		var circ := _curl_circle() if _model else _simple_curl_circle()
		if circ.is_empty():
			continue
		# the joints are inside the fingers: the inside of the curl is smaller
		var inner: float = (circ[1] - circ[2]) * _scale
		var err := absf(inner - radius)
		if err < best_err:
			best_err = err
			_grip_curl = c
			_hold_grip = _model_xf * circ[0] if _model else circ[0]
	# then the thumb: closed as far as it goes without going into the wire
	_set_curl(_grip_curl)
	_fit_thumb(wire_r, half_len)
	_set_curl(saved)

## The circle through the middle finger's joints as curled now: [its middle
## (arm model space), its radius, the finger's half-thickness] - or [].
func _curl_circle() -> Array:
	var k := _bone_pos("MIDDLE meta1 R")
	var m := _bone_pos("MIDDLE meta2 R")
	var t := _bone_pos("MIDDLE tip R")
	var a := k - t
	var b := m - t
	var axb := a.cross(b)
	if axb.length_squared() < 1e-14:
		return []
	var centre := t + (b * a.length_squared() - a * b.length_squared()).cross(axb) / (2.0 * axb.length_squared())
	return [centre, centre.distance_to(t), k.distance_to(m) * 0.28]


## The simple hand's version of _curl_circle: the circle through the middle
## finger's knuckle, middle joint and tip as curled now (hand space) - [its
## middle, its radius, the finger's half-thickness] - or [].
func _simple_curl_circle() -> Array:
	if _fingers.size() < 2:
		return []
	var knuckle: Node3D = _fingers[1][0]
	var joint: Node3D = _fingers[1][1]
	var far_len: float = 0.095 * 0.45
	var k := knuckle.transform.origin
	var m := knuckle.transform * joint.position
	var t := knuckle.transform * joint.transform * Vector3(0, 0, -far_len)
	var a := k - t
	var b := m - t
	var axb := a.cross(b)
	if axb.length_squared() < 1e-14:
		return []
	var centre := t + (b * a.length_squared() - a * b.length_squared()).cross(axb) / (2.0 * axb.length_squared())
	return [centre, centre.distance_to(t), 0.009]

## ---------------------------------------------------------------------
## The thumb, holding a wire: it closes as far as it can while staying
## outside the wire (the wire runs along the hand's X through _hold_grip),
## so it ends up hugging the wire from the wrist side instead of going
## through it.
## ---------------------------------------------------------------------
const THUMB_HALF := 0.011                    # the thumb's half-thickness (hand space)
var _thumb_grip := 0.6                       # -1 = opened right out, 0 = open, 1 = closed (fitted)

func _fit_thumb(wire_r: float, half_len: float) -> void:
	var r_need := wire_r / _scale + THUMB_HALF + 0.004
	var reach := half_len / _scale + THUMB_HALF
	var best := -1.0
	# from opened right out (-1, away from the palm) to closed (1)
	for i in 41:
		var t := -1.0 + i / 20.0
		_pose_thumb(t)
		var clear := true
		for p in _thumb_points():
			var d: Vector3 = p - _hold_grip
			if absf(d.x) > reach:
				continue
			if Vector2(d.y, d.z).length() < r_need:
				clear = false
				break
		if clear:
			best = t
	_thumb_grip = best

## Puts the thumb at `t`: 0 open ... 1 closed (the model hand's can also
## open out, below 0, to keep clear of the wire).
func _pose_thumb(t: float) -> void:
	if _model:
		if _skel:
			# below 0 it opens out, away from the palm
			_bend("THUMB meta R", 80.0 * t if t >= 0.0 else 45.0 * t)
			_bend("THUMB tip R", 60.0 * t if t >= 0.0 else 20.0 * t)
			_bend("THUMB base R", 0.0 if t >= 0.0 else 30.0 * t)
	elif _thumb.size() == 2:
		t = maxf(t, 0.0)
		_thumb[0].basis = Basis(Vector3.UP, deg_to_rad(lerpf(35.0, 0.0, t))) * Basis(Vector3.RIGHT, deg_to_rad(lerpf(-5.0, -88.0, t)))
		_thumb[1].basis = Basis(Vector3.RIGHT, deg_to_rad(lerpf(-5.0, -40.0, t)))

## Points along the thumb (hand space), joints and in between.
func _thumb_points() -> Array:
	var out := []
	var joints: Array[Vector3] = []
	if _model:
		var meta := _model_xf * _bone_pos("THUMB meta R")
		var tip := _model_xf * _bone_pos("THUMB tip R")
		joints = [_model_xf * _bone_pos("THUMB base R"), meta, tip, tip + (tip - meta) * 0.9]
	elif _thumb.size() == 2:
		var b: Node3D = _thumb[0]
		var tipn: Node3D = _thumb[1]
		joints = [b.position, b.transform * tipn.position, b.transform * tipn.transform * Vector3(0, 0, -0.035)]
	for i in range(joints.size() - 1):
		for s in 5:
			out.append(joints[i].lerp(joints[i + 1], s / 4.0))
	return out

## How closed the thumb is for curl `c`: open with the fingers, all the way
## to its fitted grip as they close on the wire.
func _thumb_t(c: Vector3, open_x: float) -> float:
	var k := clampf(inverse_lerp(open_x, _grip_curl.x, c.x), 0.0, 1.0) if absf(_grip_curl.x - open_x) > 0.01 else 0.0
	return k * _thumb_grip
