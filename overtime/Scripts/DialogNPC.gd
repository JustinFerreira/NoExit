## OverTime Production
## Last upadated 11/16/25 by Justin Ferreira
## DialogNPC Script
## - This script was just a place older test of what
## typical dialog interactions needed from an NPC
## this stand as the current janitor but will most likely
## be copied to the final janitor

extends Interactable

# Rotation variables
@export var rotation_speed: float = 2.0  # Adjust this to control turn speed
var is_rotating: bool = false
var target_rotation: float = 0.0

# Wandering variables with navigation
@export var wander_speed: float = 0.5
@export var wander_range: float = 40.0  # Increased range
@export var min_wander_time: float = 3.0
@export var max_wander_time: float = 50.0  # Increased time
var is_wandering: bool = true
var is_interacting: bool = false
var wander_timer: float = 0.0
var start_position: Vector3
var nav_agent: NavigationAgent3D

#Sequence of text given to multi dialog function
var text_array: Array[String] = [
	"Sup I'm the coolest janitor dude you'll ever meet. I clean, clean some more and clean again.",
	"Whats your name",
	"Thats the coolest name ive ever heard",
	"Maybe we should Kiss?",
	"JK JK JK JK",
	"Unless ;)"
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start_position = $"../..".global_transform.origin
	
	# Get the NavigationAgent3D - adjust the path if needed
	nav_agent = $"../..".get_node("NavigationAgent3D")
	
	# Set up navigation agent
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	
	set_new_wander_target()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_rotating:
		# Smoothly rotate toward target rotation
		var current_rotation = $"../..".rotation.y
		$"../..".rotation.y = lerp_angle(current_rotation, target_rotation, rotation_speed * delta)
		
		# Check if we're close enough to the target rotation
		if abs(angle_difference(current_rotation, target_rotation)) < 0.05:
			$"../..".rotation.y = target_rotation
			is_rotating = false
	
	# Handle wandering if not interacting
	if is_wandering and not is_interacting:
		wander(delta)

## wander
## this function causes npc to move
## to a random place from its starting 
## position
func wander(delta: float) -> void:
	# Update timer
	wander_timer -= delta
	
	# Move using navigation
	if nav_agent.is_navigation_finished():
		# Reached target, set a new one
		set_new_wander_target()
	else:
		# Move toward the target
		var next_location = nav_agent.get_next_path_position()
		var current_location = $"../..".global_transform.origin
		var direction = (next_location - current_location).normalized()
		
		# Move the NPC
		$"../..".global_transform.origin += direction * wander_speed * delta
		
		# Make the NPC face the direction it's moving
		if direction.length() > 0:
			var look_at_point = $"../..".global_transform.origin - direction
			$"../..".look_at(look_at_point, Vector3.UP)
	
	# Check if we need a new target (even if not finished with current path)
	if wander_timer <= 0:
		set_new_wander_target()
## set_new_wander_target
## picks a random position for the npc
## to wander to
func set_new_wander_target() -> void:
	# Generate a random position within wander range
	var random_offset = Vector3(
		randf_range(-wander_range, wander_range),
		0,
		randf_range(-wander_range, wander_range)
	)
	var target_position = start_position + random_offset
	
	# Set the navigation target
	nav_agent.target_position = target_position
	
	# Set a random timer for the next target change
	wander_timer = randf_range(min_wander_time, max_wander_time)

func _on_interacted(body: Variant) -> void:
	# Stop wandering and start interaction
	is_wandering = false
	is_interacting = true
	
	# Start the dialog
	PlayerManager.MultiDialog(text_array)
	
	# Calculate target rotation (looking away from player)
	if PlayerManager.player:
		var current_transform = $"../..".global_transform
		var target_transform = current_transform.looking_at(PlayerManager.player.global_position, Vector3.UP)
		target_transform = target_transform.rotated(Vector3.UP, PI)  # Flip 180 degrees
		
		# Get the target rotation
		target_rotation = target_transform.basis.get_euler().y
		is_rotating = true
	
	# Wait for dialog to finish
	await wait_for_dialog_completion()
	
	# Resume wandering after interaction
	is_interacting = false
	is_wandering = true
	set_new_wander_target()

## wait_for_dialog_completion
## Stops player from wandering while in dialog
func wait_for_dialog_completion():
	# Wait until the multi-dialog is finished
	while PlayerManager.multiDialog:
		await get_tree().create_timer(0.1).timeout

## angle_difference
## Helper function to calculate angle difference
func angle_difference(from: float, to: float) -> float:
	return wrapf(to - from, -PI, PI)
