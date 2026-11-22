## No Exit
## Overtime Studios
## Last updated 1/19/26 by Justin Ferreira
## Clock Ticking
## - A looping 3D clock tick, heard within max_hearing_distance.

extends AudioStreamPlayer3D

##editable field for sound strength
@export var max_hearing_distance: float = 80.0

func _ready() -> void:
	max_distance = max_hearing_distance
	# Start playing (optional - you can trigger it differently)
	finished.connect(_on_finished)
	play()

## Called when the sound finishes playing
func _on_finished():
	# Immediately restart the sound
	play()
