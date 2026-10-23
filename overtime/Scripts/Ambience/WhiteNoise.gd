## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## White Noise Script
## - plays a 3D sound in Office 

extends AudioStreamPlayer3D

@export var max_hearing_distance: float = 50.0
@export var min_volume_db: float = -80.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	max_distance = max_hearing_distance
	# Start playing (optional - you can trigger it differently)
	play()
	
	finished.connect(_on_player_finished)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_player_finished():
	play()
