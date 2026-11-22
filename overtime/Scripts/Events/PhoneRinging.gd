## No Exit
## Overtime Studios
## Phone Ringing
## - A 3D phone ring that plays once when the level starts, then again at a
##   random moment 20-60 s after each ring ends.

extends AudioStreamPlayer3D

## How far away the ring can be heard.
@export var max_hearing_distance: float = 80.0
## Seconds between rings (random in this range).
@export var min_wait: float = 20.0
@export var max_wait: float = 60.0

func _ready() -> void:
	max_distance = max_hearing_distance
	play()
	finished.connect(_ring_again_later)

func _ring_again_later() -> void:
	get_tree().create_timer(randf_range(min_wait, max_wait)).timeout.connect(_ring)

func _ring() -> void:
	if is_inside_tree():
		play()
