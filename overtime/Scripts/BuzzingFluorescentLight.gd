## No Exit
## Overtime Studios
## Last upadated 1/19/26 by Justin Ferreira
## BuzzingFlurescentLight Script
## - Script for a 3D noise node
## this sound can only be heard from a certain distance

extends AudioStreamPlayer3D

#editable field for sound strength
@export var max_hearing_distance: float = 10.0
@export var min_volume_db: float = -80.0
@export var max_volume_db: float = -20.0  # Maximum volume when close
@export var target_volume_db: float = -30.0  # Desired volume level

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	max_distance = max_hearing_distance
	volume_db = clamp(target_volume_db, min_volume_db, max_volume_db)
	finished.connect(_on_finished)
	play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Called when the sound finishes playing
func _on_finished():
	# Immediately restart the sound
	play()
