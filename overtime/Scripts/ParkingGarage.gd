## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Parking Garage Scipt
## - the parking garage is set up depending on
## this script and works differently depending on loop

extends Node3D

@onready var target = $Player
@export var fog_remover: FogVolume
@export var cars: Array[Node3D]
@export var player_car: Node3D
@export var attached_objects: Array[Node3D]

@export var orbit_distance: float = 5.0  # Distance from player to fog remover
@export var height_offset: float = 0.0   # Optional height offset


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if PlayerManager.Loop0:
		PlayerManager.Hint(EventManager.press_f_key_fob)
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
	GetCar(player_car, attached_objects)
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
	


func GetCar(player_car: Node3D, attached_objects: Array[Node3D]):
	# 1. Pick random car (keep it, don't delete)
	var random_index = randi() % cars.size()
	var selected_car = cars[random_index]
	# Optional: hide the original if needed, but not required for swapping
	
	# 2. Store offsets of attached objects relative to player_car (before swap)
	var offsets: Array[Vector3] = []
	for obj in attached_objects:
		offsets.append(obj.global_position - player_car.global_position)
	
	# 3. Swap positions of the two cars
	var player_pos = player_car.global_transform
	var selected_pos = selected_car.global_transform
	
	player_car.global_transform = selected_pos
	selected_car.global_transform = player_pos
	
	# 4. Reposition attached objects so they keep same offset relative to player_car
	for i in range(attached_objects.size()):
		var obj = attached_objects[i]
		var offset = offsets[i]
		obj.global_position = player_car.global_position + offset
		
		# 5. Call a function if the object is in relevant groups
		if obj.is_in_group("battery_minigame") and obj.is_in_group("grabbable"):
			# Replace "on_car_swapped" with whatever function you need (e.g., "reset", "update_position")
			if obj.has_method("SetOriginalPos"):
				obj.SetOriginalPos()
	
	# 6. Return the car the player is now "in"
	selected_car.queue_free()
