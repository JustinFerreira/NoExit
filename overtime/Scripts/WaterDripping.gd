## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Water Dripping Script
## - plays a 3D sound of water dripping in the garage 

extends AudioStreamPlayer3D

@export var max_hearing_distance: float = 50.0
@export var min_volume_db: float = -80.0

var random_timer: Timer = null
@export var min_interval: float = 1.0
@export var max_interval: float = 10.0
@export var min_pitch: float = 0.5
@export var max_pitch: float = 2.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	max_distance = max_hearing_distance
	
	# Start the random playback
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
	random_timer.timeout.connect(play_sound)
	
	add_child(random_timer)
	random_timer.start()

func play_sound():
	self.pitch_scale = randf_range(min_pitch, max_pitch)
	
	self.play()
	
	start_random_playback()
