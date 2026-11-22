## No Exit
## Overtime Studios
## Car Key Noise
## - The car's lock "chirp" when the player presses the key fob. Heard all
##   over the floor the car is on (quieter the further away), and from other
##   floors only through the openings - a ramp, the gaps by the barriers
##   (SoundReach) - never straight through the concrete.
## - Pressing it also flashes the car's headlights twice and lights its tail
##   lights, so the car can be spotted too (_flash_lights).

extends AudioStreamPlayer3D

const SoundReach = preload("res://Scripts/Audio/SoundReach.gd")

## Beyond this (metres) it can't be heard at all.
@export var max_hearing_distance: float = 170.0
## How much quieter it is at max_hearing_distance than right next to it (dB).
@export var falloff_db: float = 24.0
@export var min_volume_db: float = -80.0

var original_volume: float
var was_audible: bool = false
var _floor_db: float = 0.0
var _frame: int = 0

func _ready() -> void:
	PlayerManager.car_audio_player = self
	original_volume = volume_db
	# loudness is worked out here (distance + floors), not by the 3D falloff -
	# it still comes from the car's direction
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	max_distance = 0.0

func _process(_delta: float) -> void:
	var ears := SoundReach.listener()
	if ears == Vector3.INF:
		return
	_frame += 1
	if _frame % 4 == 0 or playing:
		_floor_db = SoundReach.floor_offset_db(get_world_3d(), global_position, ears, _exclude())
	var d := global_position.distance_to(ears)
	if d > max_hearing_distance or _floor_db <= SoundReach.BLOCKED_DB:
		volume_db = min_volume_db
		was_audible = false
		return
	volume_db = original_volume - falloff_db * (d / max_hearing_distance) + _floor_db
	was_audible = true

func _exclude() -> Array[RID]:
	var out: Array[RID] = []
	var p = PlayerManager.player
	if is_instance_valid(p):
		out.append(p.get_rid())
	var body := get_parent()
	while body and not (body is CollisionObject3D):
		body = body.get_parent()
	if body is CollisionObject3D:
		out.append(body.get_rid())
	return out

func playsound():
	if not is_inside_tree():
		return
	if not was_audible:
		PlayerManager.Hint(EventManager.car_distance)
	play()
	_flash_lights()

## ---------------------------------------------------------------------
## Lights: two headlights at the hood end, two red tail lights at the other,
## made the first time (sized from the car's own meshes).
## ---------------------------------------------------------------------
var _heads: Array[SpotLight3D] = []
var _head_glows: Array[OmniLight3D] = []
var _tails: Array[OmniLight3D] = []
var _flash_tween: Tween

func _flash_lights() -> void:
	if _heads.is_empty():
		_make_lights()
	if _heads.is_empty():
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	# blink, blink - tail lights on with them and a little longer
	for i in 2:
		_flash_tween.tween_callback(_set_lights.bind(true, true))
		_flash_tween.tween_interval(0.22)
		_flash_tween.tween_callback(_set_lights.bind(false, true))
		_flash_tween.tween_interval(0.16)
	_flash_tween.tween_interval(0.5)
	_flash_tween.tween_callback(_set_lights.bind(false, false))

func _set_lights(heads: bool, tails: bool) -> void:
	for l in _heads:
		l.light_energy = 9.0 if heads else 0.0
	for g in _head_glows:
		g.light_energy = 3.0 if heads else 0.0
	for t in _tails:
		t.light_energy = 2.5 if tails else 0.0

func _make_lights() -> void:
	var car := get_parent() as Node3D
	if car == null:
		return
	var inv := car.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for m in car.find_children("*", "MeshInstance3D", false, false):
		if m.mesh == null or not m.visible:
			continue
		var b: AABB = inv * m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return
	# front = toward the hood (car space), along the car's longer side
	var center := box.get_center()
	var long_x := box.size.x >= box.size.z
	var fwd := Vector3.RIGHT if long_x else Vector3.BACK
	var hood := car.get_node_or_null("Hood") as MeshInstance3D
	if hood:
		var hc: Vector3 = inv * hood.global_transform * hood.get_aabb().get_center()
		if fwd.dot(hc - center) < 0.0:
			fwd = -fwd
	var side := Vector3.BACK if long_x else Vector3.RIGHT
	var half_len: float = (box.size.x if long_x else box.size.z) * 0.5
	var half_w: float = (box.size.z if long_x else box.size.x) * 0.5
	var y := box.position.y + box.size.y * 0.38
	for s in [-1.0, 1.0]:
		var at: Vector3 = Vector3(center.x, y, center.z) + side * s * half_w * 0.65
		var head := SpotLight3D.new()
		head.light_color = Color(1.0, 0.96, 0.85)
		head.spot_range = 30.0
		head.spot_angle = 30.0
		head.light_energy = 0.0
		car.add_child(head)
		head.position = at + fwd * (half_len + 0.4)
		head.look_at(car.global_transform * (head.position + fwd * 10.0 + Vector3.DOWN * 0.6))
		_heads.append(head)
		var glow := OmniLight3D.new()
		glow.light_color = head.light_color
		glow.omni_range = 1.3
		glow.light_energy = 0.0
		car.add_child(glow)
		glow.position = at + fwd * (half_len + 0.25)
		_head_glows.append(glow)
		var tail := OmniLight3D.new()
		tail.light_color = Color(1.0, 0.08, 0.05)
		tail.omni_range = 2.2
		tail.light_energy = 0.0
		car.add_child(tail)
		tail.position = at - fwd * (half_len + 0.25)
		_tails.append(tail)

func _exit_tree() -> void:
	if PlayerManager.car_audio_player == self:
		PlayerManager.car_audio_player = null
