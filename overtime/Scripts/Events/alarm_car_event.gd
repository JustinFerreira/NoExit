## No Exit
## Overtime Studios
## Car Alarm Event (COMMON - see GarageEvent)
## - When the director allows it, the car's alarm goes off as the player
##   walks by: its sound, with its lights flashing for exactly as long
##   (sound_alarm).
## - It comes in LEVELS (picked each time it goes off):
##     1 (55%)  just this car
##     2 (30%)  this car, then the 1-2 alarm cars nearest it join in
##     3 (12%)  a chain: it spreads car to car across the nearest 3-5
##     4 (3%)   the whole garage - every alarm car, rippling outward in waves
##   The others join one after another, sooner the closer they are, so it
##   sounds like something (someone) is setting them off.

extends "res://Scripts/Events/GarageEvent.gd"

## Alarm sound (replaces the AudioStreamPlayer3D's stream if set).
@export var sound: AudioStream

## [chance, how many others join (min, max), seconds between each]
const LEVELS := [
	[0.55, Vector2i(0, 0), Vector2(0.0, 0.0)],
	[0.30, Vector2i(1, 2), Vector2(0.8, 1.8)],
	[0.12, Vector2i(3, 5), Vector2(0.6, 1.4)],
	[0.03, Vector2i(99, 99), Vector2(0.25, 0.6)],
]

## The level the last alarm went off at (dev pages / testing).
static var last_level := 0

func _init() -> void:
	tier = Tier.COMMON
	kind = "car_alarm"
	kind_cooldown = 180.0
	repeatable = true

func _ready() -> void:
	if sound != null:
		$AudioStreamPlayer3D.stream = sound

func _fire() -> void:
	fire_level(_pick_level())

func _pick_level() -> int:
	var r := randf()
	for i in LEVELS.size():
		r -= LEVELS[i][0]
		if r <= 0.0:
			return i + 1
	return 1

## Sets this car off, and (level 2+) the others after it.
func fire_level(level: int) -> void:
	last_level = level
	sound_alarm()
	var l: Array = LEVELS[clampi(level, 1, LEVELS.size()) - 1]
	var others := _other_alarm_cars()
	var count := mini(randi_range(l[1].x, l[1].y), others.size())
	if count <= 0:
		return
	var joining := others.slice(0, count)
	if level >= 4:
		# the whole garage: waves - cars at about the same distance go together
		for car in joining:
			var d: float = car.global_position.distance_to(global_position)
			var at := d / 60.0 * randf_range(1.0, 1.3) + randf_range(l[2].x, l[2].y)
			get_tree().create_timer(at).timeout.connect(car.sound_alarm)
		return
	for car in joining:
		await get_tree().create_timer(randf_range(l[2].x, l[2].y)).timeout
		if is_instance_valid(car):
			car.sound_alarm()

## Just the alarm (no rules): the sound, with the lights flashing for exactly
## as long as it plays. (The scene's "CarAlarm" animation flashed them for a
## fixed 7 s and only started the sound, so whenever the sound was shorter or
## longer the two came apart - it isn't used any more.)
const FLASH_ON := 5.0
## One on+off flash (seconds) - the flashes are stretched a touch to end
## exactly with the sound.
const FLASH_PERIOD := 0.47
var _flash: Tween

func sound_alarm() -> void:
	if not is_inside_tree():
		return
	var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D
	if audio.playing:
		return   # already going
	if has_node("AnimationPlayer"):
		$AnimationPlayer.stop()
	var length := 7.0
	if audio.stream and audio.stream.get_length() > 0.0:
		length = audio.stream.get_length() / maxf(audio.pitch_scale, 0.01)
	audio.play()
	var flashes := maxi(1, roundi(length / FLASH_PERIOD))
	var half := length / (2.0 * flashes)
	if _flash and _flash.is_valid():
		_flash.kill()
	_flash = create_tween()
	for i in flashes:
		_flash.tween_callback(_set_lights.bind(FLASH_ON))
		_flash.tween_interval(half)
		_flash.tween_callback(_set_lights.bind(0.0))
		_flash.tween_interval(half)
	if not audio.finished.is_connected(_on_sound_done):
		audio.finished.connect(_on_sound_done)

## Sound over: lights off, whatever the flashing was doing.
func _on_sound_done() -> void:
	if _flash and _flash.is_valid():
		_flash.kill()
	_set_lights(0.0)

func _set_lights(energy: float) -> void:
	for n in ["OmniLight3D", "OmniLight3D2"]:
		var l := get_node_or_null(n) as Light3D
		if l:
			l.light_energy = energy


## Every other alarm car in the level, nearest first.
func _other_alarm_cars() -> Array:
	var out := []
	var scene := get_tree().current_scene
	if scene == null:
		return out
	for n in scene.find_children("*", "Node3D", true, false):
		if n != self and n.has_method("sound_alarm") and n.has_method("fire_level"):
			out.append(n)
	out.sort_custom(func(a, b): return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	return out
