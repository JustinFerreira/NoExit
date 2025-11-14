extends AudioStreamPlayer3D

@export var max_hearing_distance: float = 80.0
@export var min_volume_db: float = -50.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	max_distance = max_hearing_distance
	# Start playing (optional - you can trigger it differently)
	finished.connect(_on_finished)
	play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Called when the sound finishes playing
func _on_finished():
	# Immediately restart the sound
	play()
