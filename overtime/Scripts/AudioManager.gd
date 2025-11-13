extends Node

var MusicAudio = AudioStreamPlayer.new()
var OfficeMusicAudio = AudioStreamPlayer.new()
var looping_players: Dictionary = {}
var OfficeMusicOn: bool = false

## MUSIC
var MainMenuMusic = load("res://Assets/Audio/Music/NoExitMenu_v1.mp3")

var OfficeWhiteNoise = load("res://Assets/Audio/SFX/WhiteNoise.mp3")

var ElevatorMusic = load("res://Assets/Audio/Music/elevator_wip3.mp3")

## SFX

var step = load("res://Assets/Audio/SFX/Footsteps/SoftStep1.wav")

var heartbeat = load("res://Assets/Audio/SFX/heartbeat-single-383748.mp3")

var breathing = load("res://Assets/Audio/SFX/breathing_dev.wav")

var keys = load("res://Assets/Audio/SFX/Keys2.wav")

var elevator_whitenoise = load("res://Assets/Audio/SFX/elevator_WhiteNoise.mp3")

var keypress1 = load("res://Assets/Audio/SFX/Keyboard/Single/KeyboardSingle1.wav")
var keypress2 = load("res://Assets/Audio/SFX/Keyboard/Single/KeyboardSingle2.wav")
var keypress3 = load("res://Assets/Audio/SFX/Keyboard/Single/KeyboardSingle3.wav")
var keypress4 = load("res://Assets/Audio/SFX/Keyboard/Single/KeyboardSingle4.wav")
var keypress5 = load("res://Assets/Audio/SFX/Keyboard/Single/KeyboardSingle5.wav")

func _ready() -> void:
	MusicAudio.bus = "Music"
	add_child(MusicAudio)
	


func play_sound(sound_stream: AudioStream, volume_db: float = 24.0, pitch_scale: float = 1):
	var new_player = AudioStreamPlayer.new()
	new_player.volume_db = volume_db
	new_player.pitch_scale = pitch_scale
	new_player.bus = "SFX"
	new_player.stream = sound_stream
	add_child(new_player)
	new_player.play()
	# Automatically remove after playback
	await new_player.finished
	new_player.queue_free()
	
func play_music(sound_stream: AudioStream):
	if sound_stream == OfficeWhiteNoise:
		add_child(OfficeMusicAudio)
		OfficeMusicAudio.volume_db = -12
		OfficeMusicAudio.stream = sound_stream
		OfficeMusicAudio.play()
	else:
		MusicAudio.stream = sound_stream
		MusicAudio.play()
	
func play_sound_loop(sound_stream: AudioStream, sound_name: String, pitch_scale: float = 1.0, volume_db: float = 1.0, wait: float = 0.0):
	if looping_players.has(sound_name):
		looping_players[sound_name].pitch_scale = pitch_scale
		looping_players[sound_name].volume_db = volume_db
		return
	
	var new_player = AudioStreamPlayer.new()
	if sound_name == "heartbeat" || sound_name == "breathing":
		new_player.bus = "PitchShiftSFX"
	else:
		new_player.bus = "SFX"
	new_player.stream = sound_stream
	new_player.pitch_scale = pitch_scale  # Add pitch control
	new_player.volume_db = volume_db
	
	
	
	
	if wait > 0:
		new_player.finished.connect(_on_player_finished.bind(new_player, wait))
	else:
		new_player.finished.connect(_on_player_finished.bind(new_player))
	
	add_child(new_player)
	new_player.play()
	
	# Store reference if you want to control it later
	if sound_name!= "":
		looping_players[sound_name] = new_player
	
	return new_player

func set_loop_pitch(sound_name: String, pitch: float):
	if looping_players.has(sound_name) && pitch > 0.0:
		looping_players[sound_name].pitch_scale = pitch

func stop_loop(sound_name: String):
	if looping_players.has(sound_name):
		var player = looping_players[sound_name]
		player.stop()
		player.queue_free()
		looping_players.erase(sound_name)

func _on_player_finished(player: AudioStreamPlayer, wait: float = 0.0):

	# Restart the same player instead of creating a new one
	if wait > 0 && player:
		 # Check if player already has a timer
		if player.has_meta("restart_timer") and is_instance_valid(player.get_meta("restart_timer")):
			return  # Timer already exists
		
		var timer = Timer.new()
		timer.wait_time = wait
		timer.one_shot = true
		timer.timeout.connect(
			func():
				if is_instance_valid(player):
					player.play()
				if is_instance_valid(player) && is_instance_valid(timer):
					timer.queue_free()
					if player.has_meta("restart_timer"):
						player.set_meta("restart_timer", null)
		)
		add_child(timer)
		timer.start()
		player.set_meta("restart_timer", timer)
	else:
		player.play()
	
func set_loop_volume(sound_name: String, volume_db: float):
	if looping_players.has(sound_name):
		looping_players[sound_name].volume_db = volume_db

func fade_loop_volume(sound_name: String, target_volume: float, duration: float = 1.0):
	if looping_players.has(sound_name):
		var tween = create_tween()
		tween.tween_property(looping_players[sound_name], "volume_db", target_volume, duration)
	
func cancel_music():
	if OfficeMusicOn:
		OfficeMusicAudio.playing = false
	MusicAudio.playing = false
	
func cancel_loop_sfx():
	# Collect all keys first
	var keys = []
	for loop in looping_players:
		keys.append(loop)
	
	# Then iterate over the collected keys
	for loop in keys:
		var player = looping_players[loop]
		player.stop()
		player.queue_free()
		looping_players.erase(loop)
		
		
func GetKeyPress():
	var keypress_sounds = [keypress1, keypress2, keypress3, keypress4, keypress5]
	var random_index = randi() % keypress_sounds.size()
	return keypress_sounds[random_index]
