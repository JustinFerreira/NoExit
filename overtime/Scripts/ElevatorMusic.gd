## No Exit
## Overtime Studios
## Last upadated 1/23/26 by Justin Ferreira
## ElevatorMusic Script
## - This plays music inside the elevator

extends AudioStreamPlayer3D

#sound radius variables
@export var max_hearing_distance: float = 4.0
@export var min_volume_db: float = -80.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	max_distance = max_hearing_distance
	# Start playing (optional - you can trigger it differently)
	play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
