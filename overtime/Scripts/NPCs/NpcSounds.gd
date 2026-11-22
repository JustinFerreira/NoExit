## No Exit
## Overtime Studios
## Last updated 2/14/26
## Npc Sounds Script
## - For NPCs that just sit at their desk.
## so they can spit out random song on an interval
## - LEGACY: new NPCs use the Ambient Sounds settings on NPC (NPC.gd);
##   this is only still used by the flattened Fitted levels.

extends AudioStreamPlayer3D

@export var max_hearing_distance: float = 50.0

var keyboard1: AudioStream = load("res://Assets/Audio/SFX/Keyboard/Typing/Keyboard1.wav")
var keyboard2: AudioStream = load("res://Assets/Audio/SFX/Keyboard/Typing/Keyboard2.wav")
var keyboard3: AudioStream = load("res://Assets/Audio/SFX/Keyboard/Typing/Keyboard3.wav")
var keyboard4: AudioStream = load("res://Assets/Audio/SFX/Keyboard/Typing/Keyboard4.wav")
var keyboard5: AudioStream = load("res://Assets/Audio/SFX/Keyboard/Typing/Keyboard5.wav")
var keyspace1: AudioStream = load("res://Assets/Audio/SFX/Keyboard/Spacebar/KeyboardSpace1.wav")
var keyspace2: AudioStream = load("res://Assets/Audio/SFX/Keyboard/Spacebar/KeyboardSpace2.wav")


var sounds: Array[AudioStream] = []
var random_timer: Timer = null
var min_interval: float = 1.0
var max_interval: float = 20.0

func _ready() -> void:
	max_distance = max_hearing_distance
	sounds = [keyboard1, keyboard2, keyboard3, keyboard4, keyboard5, keyspace1, keyspace2]

	start_random_playback()
	# Loop the typing animation (it used to be restarted every frame).
	var anim: AnimationPlayer = get_node_or_null("../AnimationPlayer")
	if anim:
		anim.animation_finished.connect(func(_n): anim.play("mixamo_com"))
		anim.play("mixamo_com")

## Schedules the next random sound (min_interval..max_interval s).
func start_random_playback():
	# If there's already a timer running, stop it
	if random_timer and is_instance_valid(random_timer):
		random_timer.stop()
		random_timer.queue_free()

	# Create a new timer
	random_timer = Timer.new()
	random_timer.one_shot = true
	random_timer.wait_time = randf_range(min_interval, max_interval)

	# Connect the timeout signal
	random_timer.timeout.connect(_play_random_sound)

	add_child(random_timer)
	random_timer.start()

func _play_random_sound():
	if not is_inside_tree():
		return
	# Select a random sound from the array
	if sounds.size() > 0:
		var random_index = randi() % sounds.size()
		self.stream = sounds[random_index]
		self.play()
	# Schedule the next random playback
	start_random_playback()
