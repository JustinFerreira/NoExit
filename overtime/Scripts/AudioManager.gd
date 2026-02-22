## No Exit
## Overtime Studios
## Last upadated 11/16/25 by Justin Ferreira
## AudioManager Script
## - This Script contains functions for
## controling Music and Sound effects
## also storing many sound effects to be
## used across the project
## This does not control all sound this is
## specfically for 2D sound that plays in the
## players ears 3D sound is stored on seperately


extends Node

var MusicAudio = AudioStreamPlayer.new()
var OfficeMusicAudio = AudioStreamPlayer.new()
var looping_players: Dictionary = {}
var OfficeMusicOn: bool = false

var KillerShutUp = false

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

var CarDoorLocked = load("res://Assets/Audio/SFX/CarDoor/LockedCarDoor.mp3")

var CarDoorOpen = load("res://Assets/Audio/SFX/CarDoor/OpenCarDoor.mp3")

var CarDoorClose = load("res://Assets/Audio/SFX/CarDoor/CloseCarDoor.mp3")

var Glug = load("res://Assets/Audio/SFX/gas_glug.mp3")

var SocketFast = load("res://Assets/Audio/SFX/SocketWrench/SocketFast.mp3")

var socket1 = load("res://Assets/Audio/SFX/SocketWrench/Socket1.mp3")
var socket2 = load("res://Assets/Audio/SFX/SocketWrench/Socket2.mp3")
var socket3 = load("res://Assets/Audio/SFX/SocketWrench/Socket3.mp3")

var ItemPickup = load("res://Assets/Audio/SFX/ItemPickup.mp3")

var ElevatorDing = load("res://Assets/Audio/SFX/elevatorsounds/elevator_Ding.mp3")

var ElevatorOpenDoor = load("res://Assets/Audio/SFX/elevatorsounds/elevator_DingDoorOpen.mp3")

var ElevatorCloseDoor = load("res://Assets/Audio/SFX/elevatorsounds/elevator_DoorClose.mp3")

var SkullCrush = load("res://Assets/Audio/SFX/headcrushFinal.mp3")

var HoodOpen = load("res://Assets/Audio/SFX/car_hood-open_metalic-hollow-springy-91593.mp3")

var Thud4 = load("res://Assets/Audio/SFX/thud4.wav")

var GasCapClose = load("res://Assets/Audio/SFX/gascapdoor_close1.mp3")

var GasCapOpen = load("res://Assets/Audio/SFX/gascapdoor_open2.mp3")

var CarStartNoGas = load("res://Assets/Audio/SFX/car-engine-fail.mp3")

var CarStart = load("res://Assets/Audio/SFX/car-engine-success.mp3")

# Stingers

var ImportantItemStinger = load("res://Assets/Audio/Stingers/spookystinger.mp3")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	## At creation of project assign the MusicAudio Player to the bus Music
	MusicAudio.bus = "Music"
	## Add the MusicAudio Player to child highest level of the project
	add_child(MusicAudio)
	

## play_sound
## plays a singluar instance of a sound 
## then removes the player from queue
## also allows for volume and pitch modification
## these values do have defaults though so not nessacary for calling
func play_sound(sound_stream: AudioStream, volume_db: float = -8.0, pitch_scale: float = 1):
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

## play_music
## starts the playing of music 
## this does not loop the music
## the file used for this function
## should be an mp3 that has loopable turned on
func play_music(sound_stream: AudioStream):
	if sound_stream == OfficeWhiteNoise:
		add_child(OfficeMusicAudio)
		OfficeMusicAudio.volume_db = -12
		OfficeMusicAudio.stream = sound_stream
		OfficeMusicAudio.play()
	else:
		MusicAudio.stream = sound_stream
		MusicAudio.play()
	
## play_sound_loop
## this function plays a sound 
## and once that sound is complete
## it will immediatelt play it again
## it saves the sound with a name
## and this information is stored
## in the looping_players
## this function also allows to change the pitch
## and volume
## there is also a wait parameter that can 
## be used to give time between the last sound played
## and the next
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

## set_loop_pitch
## If a loop is already playing
## this fucntion can find that loop by name
## and chnage its pitch
func set_loop_pitch(sound_name: String, pitch: float):
	if looping_players.has(sound_name) && pitch > 0.0:
		looping_players[sound_name].pitch_scale = pitch

## stop loop
## this function will
## shut off a looping sound by name
func stop_loop(sound_name: String):
	if looping_players.has(sound_name):
		var player = looping_players[sound_name]
		player.stop()
		player.queue_free()
		looping_players.erase(sound_name)

## _on_player_finished
## this is used to either wait before 
## next sound is played when the first is finished
## or just play the next sound
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
		
## set_loop_volume
## If a loop is already playing
## this fucntion can find that loop by name
## and change its volume
func set_loop_volume(sound_name: String, volume_db: float):
	if looping_players.has(sound_name):
		looping_players[sound_name].volume_db = volume_db

## fade_loop_volume
## If a loop is already playing
## this fucntion can find that loop by name
## and fade its volume to a new value
func fade_loop_volume(sound_name: String, target_volume: float, duration: float = 1.0):
	if looping_players.has(sound_name):
		var tween = create_tween()
		tween.tween_property(looping_players[sound_name], "volume_db", target_volume, duration)
	
## cancel_music
## this function turns off all music playing
func cancel_music():
	if OfficeMusicOn:
		OfficeMusicAudio.playing = false
	MusicAudio.playing = false
	
## cancel_loop_sfx
## turns off all looping sounds
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
		

## GetKeyPress
## randomly returns a keypress sound
func GetKeyPress():
	var keypress_sounds = [keypress1, keypress2, keypress3, keypress4, keypress5]
	var random_index = randi() % keypress_sounds.size()
	return keypress_sounds[random_index]

## GetSocket
## randomly returns a socket sound
func GetSocket():
	var socket_sounds = [socket1, socket2, socket3]
	var random_index = randi() % socket_sounds.size()
	return socket_sounds[random_index]
