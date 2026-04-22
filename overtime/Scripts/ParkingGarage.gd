## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Parking Garage Scipt
## - the parking garage is set up depending on
## this script and works differently depending on loop

extends Node3D

@onready var target = $Player
@export var fog_remover: FogVolume

@export var orbit_distance: float = 5.0  # Distance from player to fog remover
@export var height_offset: float = 0.0   # Optional height offset


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if PlayerManager.Loop1:
		AudioManager.play_sound(AudioManager.GetBassStinger())
	if PlayerManager.sprint_engaged:
		PlayerManager.player.is_sprinting = PlayerManager.sprint_engaged
	PlayerManager.Office = false
	PlayerManager.ParkingGarage = true
	PlayerManager.player = get_tree().current_scene.get_node("Player") 
	PlayerManager.examed = true
	HelperManager.fog_remover = fog_remover
	HelperManager.killer_eyes = $WorldEnvironment/FogRemover/KillerEyes
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if fog_remover:
		# Get the camera's forward direction but flatten it to ignore vertical tilt
		var camera_forward = -target.CAMERA.global_transform.basis.z
		camera_forward.y = 0  # Remove Y component to prevent up/down movement
		camera_forward = camera_forward.normalized()  # Re-normalize the vector
		
		# Calculate the position horizontally in front of the player
		var target_position = target.global_position + (camera_forward * orbit_distance)
		target_position.y += height_offset  # Apply height offset if needed
		
		# Set fog remover position
		fog_remover.global_position = target_position
		
		# Make fog remover face the camera (optional)
		var camera_position = target.CAMERA.global_position
		camera_position.y = target_position.y  # Keep fog remover looking at same height
		fog_remover.look_at(camera_position)
	if SettingsManager.KillerDisabled:
		return
	get_tree().call_group("enemy" , "target_position" , target.global_transform.origin)
	
