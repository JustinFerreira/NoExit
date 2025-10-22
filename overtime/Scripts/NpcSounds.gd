extends AudioStreamPlayer3D

@export var max_hearing_distance: float = 50.0
@export var min_volume_db: float = 80.0

var keyboard1 = load("res://Assets/Audio/SFX/Keyboard/Typing/Keyboard1.wav") 
var keyboard2 = load("res://Assets/Audio/SFX/Keyboard/Typing/Keyboard2.wav")
var keyboard3 = load("res://Assets/Audio/SFX/Keyboard/Typing/Keyboard3.wav")
var keyboard4 = load("res://Assets/Audio/SFX/Keyboard/Typing/Keyboard4.wav")
var keyboard5 = load("res://Assets/Audio/SFX/Keyboard/Typing/Keyboard5.wav")
#var keysingle1 = load("res://Assets/Audio/SFX/Keyboard/Single/KeyboardSingle1.wav")
#var keysingle2 = load("res://Assets/Audio/SFX/Keyboard/Single/KeyboardSingle2.wav")
#var keysingle3 = load("res://Assets/Audio/SFX/Keyboard/Single/KeyboardSingle3.wav")
#var keysingle4 = load("res://Assets/Audio/SFX/Keyboard/Single/KeyboardSingle4.wav")
#var keysingle5 = load("res://Assets/Audio/SFX/Keyboard/Single/KeyboardSingle5.wav")
var keyspace1 = load("res://Assets/Audio/SFX/Keyboard/Spacebar/KeyboardSpace1.wav")
var keyspace2 = load("res://Assets/Audio/SFX/Keyboard/Spacebar/KeyboardSpace2.wav")


var sounds = []
var random_timer: Timer = null
var min_interval: float = 1.0
var max_interval: float = 20.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	max_distance = max_hearing_distance
	sounds = [keyboard1, keyboard2, keyboard3, keyboard4, keyboard5, keyspace1, keyspace2]
	
	start_random_playback()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

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
	# Select a random sound from the array
	if sounds.size() > 0:
		var random_index = randi() % sounds.size()
		self.stream = sounds[random_index]
		self.play()
	
	# Schedule the next random playback
	start_random_playback()

# Function to stop the random playback
func stop_random_playback():
	if random_timer and is_instance_valid(random_timer):
		random_timer.stop()
		random_timer.queue_free()
		random_timer = null

# Function to change the interval range
func set_interval_range(min_seconds: float, max_seconds: float):
	min_interval = min_seconds
	max_interval = max_seconds
	
	# Restart with new interval if currently playing
	if random_timer and is_instance_valid(random_timer):
		start_random_playback()
