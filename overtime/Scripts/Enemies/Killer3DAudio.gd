## No Exit
## Overtime Studios
## Killer 3D Audio
## - The killer's breathing/footstep loop: alternates first_sound and
##   second_sound forever as a 3D sound on the killer, fading with distance
##   out to max_hearing_distance. From another floor it's only heard through
##   the openings (SoundReach). Fixed during the opening/Loop 0, silent while
##   AudioManager.KillerShutUp is set (e.g. during a kill).

extends AudioStreamPlayer3D

const SoundReach = preload("res://Scripts/Audio/SoundReach.gd")

## How loud it is (before distance and floors).
@export var loudness_db: float = 4.0
var _floor_db: float = 0.0
var _frame: int = 0

## How far away the killer can be heard.
@export var max_hearing_distance: float = 70.0
@export var first_sound: AudioStream
@export var second_sound: AudioStream
## Pause between the two sounds (seconds).
@export var delay_between_sounds: float = 0.1

var current_sound_index: int = 0
var timer: Timer

func _ready() -> void:
	max_distance = max_hearing_distance
	unit_size = 12.0   # carries further before it starts fading
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_play_next_sound)
	_play_next_sound()

## Plays the next sound of the pair and schedules the one after it.
func _play_next_sound() -> void:
	stream = first_sound if current_sound_index == 0 else second_sound
	current_sound_index = 1 - current_sound_index
	if stream == null:
		return
	play()
	timer.start(stream.get_length() + delay_between_sounds)

func _process(_delta: float) -> void:
	if AudioManager.KillerShutUp:
		volume_db = -100
	elif (PlayerManager.OpeningCutscene or PlayerManager.Loop0) and not PlayerManager.dying:
		volume_db = -12
	else:
		_frame += 1
		var ears := SoundReach.listener()
		if ears != Vector3.INF and _frame % 5 == 0:
			var target := SoundReach.floor_offset_db(get_world_3d(), global_position, ears, _exclude())
			_floor_db = lerpf(_floor_db, target, 0.5)
		volume_db = loudness_db + _floor_db

func _exclude() -> Array[RID]:
	var out: Array[RID] = []
	if is_instance_valid(PlayerManager.player):
		out.append(PlayerManager.player.get_rid())
	if get_parent() is CollisionObject3D:
		out.append(get_parent().get_rid())
	return out
