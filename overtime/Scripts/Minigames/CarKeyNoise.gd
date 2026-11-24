## No Exit
## Overtime Studios
## Car Key Noise
## - The car's lock "chirp" when the player presses the key fob. It fades with
##   distance like real sound; with a clear line (open floor, through the
##   bars) it's heard straight across, otherwise it goes round along the
##   walking route (up a ramp, round a wall) and is quieter for it - never
##   straight through the concrete (SoundReach.reach).
## - Pressing it also flashes the car's headlights twice and lights its tail
##   lights, so the car can be spotted too (_flash_lights).

extends AudioStreamPlayer3D
const EnemyNoise = preload("res://Scripts/Enemies/EnemyNoise.gd")

const SoundReach = preload("res://Scripts/Audio/SoundReach.gd")

## How far it carries (garage units): past this it can't be heard at all, and
## it fades out to silence over the last FADE_SHARE of it. Shared by every
## car and kept between levels, so the dev menu can tune it live (Dev Tools:
## "Fob range" / "falloff").
static var max_hearing_distance: float = 120.0
## Full volume out to this far (garage units)...
const REF_DISTANCE := 8.0
## ... then this much quieter (dB) every time the distance doubles.
static var rolloff_db: float = 10.0
const FADE_SHARE := 0.3
@export var min_volume_db: float = -80.0

var original_volume: float
var was_audible: bool = false
var _reach := {"distance": INF, "db": -60.0}
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
		_reach = SoundReach.reach(get_world_3d(), global_position, ears, _exclude())
	var d: float = _reach.distance
	if d > max_hearing_distance or _reach.db <= SoundReach.BLOCKED_DB:
		volume_db = min_volume_db
		was_audible = false
		return
	# fades like real sound: rolloff_db quieter every time the distance
	# doubles (past ref_distance) - plus what it loses on the way
	volume_db = original_volume - rolloff_db * log(maxf(d, REF_DISTANCE) / REF_DISTANCE) / log(2.0) + _reach.db
	# and dies away to nothing over the last stretch of its range
	var fade_from := max_hearing_distance * (1.0 - FADE_SHARE)
	if d > fade_from:
		volume_db = lerpf(volume_db, min_volume_db, clampf((d - fade_from) / (max_hearing_distance - fade_from), 0.0, 1.0))
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
	EnemyNoise.make(get_tree(), global_position, EnemyNoise.KEY_FOB)

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
