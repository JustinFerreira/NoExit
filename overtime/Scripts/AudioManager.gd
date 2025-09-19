extends Node

var MusicAudio = AudioStreamPlayer.new()
var looping_players: Dictionary = {}

## MUSIC
var MainMenuMusic = load("res://Assets/Audio/Music/NoExitMenu_v1.mp3")

var GamePlayMusic = load("res://Assets/Audio/Music/chief-keef-save-me-official-audio-128-ytshorts.savetube.me.mp3")

## SFX

var step = load("res://Assets/Audio/SFX/step_dev.wav")

var heartbeat = load("res://Assets/Audio/SFX/heartbeat_dev.wav")

var breathing = load("res://Assets/Audio/SFX/breathing_dev.wav")

func _ready() -> void:
	MusicAudio.bus = "Music"
	add_child(MusicAudio)
	


func play_sound(sound_stream: AudioStream):
	var new_player = AudioStreamPlayer.new()
	new_player.bus = "SFX"
	new_player.stream = sound_stream
	add_child(new_player)
	new_player.play()
	# Automatically remove after playback
	await new_player.finished
	new_player.queue_free()
	
func play_music(sound_stream: AudioStream):
	MusicAudio.stream = sound_stream
	MusicAudio.play()
	
func play_sound_loop(sound_stream: AudioStream, sound_name: String, pitch_scale: float = 1.0):
	if looping_players.has(sound_name):
		looping_players[sound_name].pitch_scale = pitch_scale
		return
	
	var new_player = AudioStreamPlayer.new()
	new_player.bus = "SFX"
	new_player.stream = sound_stream
	new_player.autoplay = true
	new_player.pitch_scale = pitch_scale  # Add pitch control
	
	new_player.finished.connect(_on_player_finished.bind(new_player))
	
	add_child(new_player)
	new_player.play()
	
	# Store reference if you want to control it later
	if sound_name!= "":
		looping_players[sound_name] = new_player
	
	return new_player
	
func set_loop_pitch(sound_name: String, pitch: float):
	if looping_players.has(sound_name):
		looping_players[sound_name].pitch_scale = pitch

func stop_loop(sound_name: String):
	if looping_players.has(sound_name):
		var player = looping_players[sound_name]
		player.stop()
		player.queue_free()
		looping_players.erase(sound_name)

func _on_player_finished(player: AudioStreamPlayer):
	# Restart the same player instead of creating a new one
	player.play()
	
func set_loop_volume(sound_name: String, volume_db: float):
	if looping_players.has(sound_name):
		looping_players[sound_name].volume_db = volume_db

func fade_loop_volume(sound_name: String, target_volume: float, duration: float = 1.0):
	if looping_players.has(sound_name):
		var tween = create_tween()
		tween.tween_property(looping_players[sound_name], "volume_db", target_volume, duration)
	
func cancel_music():
	MusicAudio.playing = false
