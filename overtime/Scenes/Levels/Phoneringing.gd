extends AudioStreamPlayer3D

@export var max_hearing_distance: float = 50.0
@export var min_volume_db: float = -30.0
var random_play_timer: Timer = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	max_distance = max_hearing_distance
	# Start playing (optional - you can trigger it differently)
	play()
	finished.connect(play_at_random)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func play_at_random():
	if random_play_timer and is_instance_valid(random_play_timer):
		random_play_timer.stop()
		random_play_timer.queue_free()
	
	# Create a new timer
	random_play_timer = Timer.new()
	random_play_timer.wait_time = randf_range(20.0, 180.0)
	random_play_timer.one_shot = true
	
	# Connect the timeout signal
	random_play_timer.timeout.connect(_on_random_play_timeout)
	
	add_child(random_play_timer)
	random_play_timer.start()
	
	
func _on_random_play_timeout():
	play()
	
	# Clean up the timer
	if random_play_timer and is_instance_valid(random_play_timer):
		random_play_timer.queue_free()
		random_play_timer = null
