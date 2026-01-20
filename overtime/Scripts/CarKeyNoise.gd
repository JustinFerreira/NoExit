## OverTime Studios
## Last upadated 1/19/26 by Justin Ferreira
## CarKeyNoise Script
## - Script for a 3D noise node
## this sound can only be heard from a certain distance

extends AudioStreamPlayer3D

#editable field for sound strength
@export var max_hearing_distance: float = 120.0
@export var min_volume_db: float = -80.0
@export var same_floor_threshold: float = 3.0

var player_node: Node3D
var original_volume: float
var nav: NavigationAgent3D
var was_audible: bool = false  # Track if sound was audible in previous frame

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerManager.car_audio_player = self
	original_volume = volume_db
	
	# Try to find the player node
	player_node = get_tree().get_first_node_in_group("player")
	# OR if your player is stored in PlayerManager:
	# player_node = PlayerManager.player
	
	# Get NavigationAgent3D
	nav = get_node_or_null("NavigationAgent3D")
	if nav:
		nav.path_desired_distance = 1.0
		nav.target_desired_distance = 1.5

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player_node:
		update_volume_based_on_distance()


## update_volume_based_on_distance
## updates the volume of this node
## according to a calculated distance
func update_volume_based_on_distance():
	var car_position = global_transform.origin
	var player_position = player_node.global_transform.origin
	
	# Calculate vertical distance
	var vertical_distance = abs(car_position.y - player_position.y)
	
	# If not on same floor, mute completely
	if vertical_distance > same_floor_threshold:
		volume_db = min_volume_db
		check_and_print_help()
		return
	
	# Calculate path distance to player
	var path_distance = calculate_path_distance()
	
	# If within hearing range
	if path_distance <= max_hearing_distance:
		# Calculate volume based on path distance
		volume_db = lerp(original_volume, min_volume_db, path_distance / max_hearing_distance)
		was_audible = true  # Sound is audible
	else:
		# Too far away to hear
		volume_db = min_volume_db
		check_and_print_help()

## calculate_path_distance
## calculate route to player so the sound
## is onlt played within a certain distance
## without this the sound can be heard from
## above when this is not wanted
func calculate_path_distance() -> float:
	if not nav or not player_node:
		return global_transform.origin.distance_to(player_node.global_transform.origin)
	
	# Update navigation target to player position
	nav.target_position = player_node.global_transform.origin
	
	# Get the full navigation path
	var path = nav.get_current_navigation_path()
	var total_distance = 0.0
	
	# Sum the distances between each point in the path
	for i in range(path.size() - 1):
		total_distance += path[i].distance_to(path[i + 1])
	
	return total_distance

## check_and_print_help
## changes was_audible to false
func check_and_print_help():
	if was_audible:
		was_audible = false

## playsound()
## function use to play sound
## or if distance to far Hint
## dialog is put on screen
func playsound():
	if !was_audible:
		PlayerManager.Hint(EventManager.car_distance)
	self.play()
	was_audible = true  # When we start playing, sound is audible
