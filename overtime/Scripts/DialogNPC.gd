## OverTime Production
## Last upadated 11/16/25 by Justin Ferreira
## DialogNPC Script

extends Interactable

# Rotation variables
@export var rotation_speed: float = 2.0  # Adjust this to control turn speed
var is_rotating: bool = false
var target_rotation: float = 0.0

# Wandering variables with navigation
@export var walk_speed: float = 7.5  # Walking speed when approaching player
@export var wander_speed: float = 0.5
@export var wander_range: float = 40.0  # Increased range
@export var min_wander_time: float = 3.0
@export var max_wander_time: float = 50.0  # Increased time
var is_wandering: bool = true
var is_interacting: bool = false
var is_walking_to_player: bool = false  # New state for walking to player
var wander_timer: float = 0.0
var start_position: Vector3
var nav_agent: NavigationAgent3D

# Walking to player parameters
@export var stopping_distance: float = 2.0  # Stop this far from the player

# Camera rotation storage
var original_camera_rotation: Vector3 = Vector3.ZERO
var original_player_rotation: float = 0.0
var original_player_transform: Transform3D  # Store complete transform
var has_initial_dialog_played: bool = false  # Track if initial dialog played

#Sequence of text given to multi dialog function
var text_array: Array[String] = [
	"Last day, right?",
	"Quite a familiar sight, watching a kid turn their back on this, and pardon my French",
	"lumpy pile of dog shit",
	"Let me guess, your heart wasn't in it? Corporate life didn't suit you?",
	"Oh, it doesn't matter. Just a quick word of advice.",
	"This life has a knack for following you.",
	"It's kinda like chronic depression or my ex-wife",
	"Once it's got its claws in you, it won't want to let go."
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start_position = $"../..".global_transform.origin
	
	# Get the NavigationAgent3D - adjust the path if needed
	nav_agent = $"../..".get_node("NavigationAgent3D")
	
	# Set up navigation agent
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	
	PlayerManager.janitor = self
	PlayerManager.talkToJanitor = false
	
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
	
	# Handle walking to player if in that state
	if is_walking_to_player and PlayerManager.player:
		# Check if we're already close enough before walking
		var player_position = PlayerManager.player.global_transform.origin
		var npc_position = $"../..".global_transform.origin
		var distance_to_player = npc_position.distance_to(player_position)
		
		if distance_to_player <= stopping_distance:
			#print("NPC already close to player! Starting dialog immediately...")
			is_walking_to_player = false
			rotate_to_player()
			start_multi_dialog_with_camera()
		else:
			walk_to_player(delta)
	
	# Handle wandering if not interacting AND not in dialog
	elif is_wandering and not is_interacting and not is_walking_to_player and not PlayerManager.multiDialog:
		wander(delta)

## walk_to_player
## Moves NPC toward the player's current position
func walk_to_player(delta: float) -> void:
	if not PlayerManager.player:
		is_walking_to_player = false
		return
	
	# Update target to player's current position
	var player_position = PlayerManager.player.global_transform.origin
	var npc_position = $"../..".global_transform.origin
	var distance_to_player = npc_position.distance_to(player_position)
	
	#print("Distance to player: ", distance_to_player, " | Stopping distance: ", stopping_distance)
	
	# Stop if we're close enough and start dialog
	if distance_to_player <= stopping_distance * 1.5:  # Allow 50% margin
		#print("NPC reached player (close enough)!")
		is_walking_to_player = false
		# Rotate to face away from player
		rotate_to_player()
		# Start the multi-dialog with camera rotation
		start_multi_dialog_with_camera()
		return
	
	# Calculate a target position that's exactly stopping_distance away from player
	var direction_to_player = (player_position - npc_position).normalized()
	var target_position = player_position - (direction_to_player * stopping_distance)
	
	# Set navigation target to the calculated position
	nav_agent.target_position = target_position
	
	# Check if navigation agent has reached its target or is stuck
	if nav_agent.is_navigation_finished():
		#print("Navigation finished but not close enough - forcing dialog start")
		is_walking_to_player = false
		rotate_to_player()
		start_multi_dialog_with_camera()
		return
	
	# Move toward the calculated position
	if not nav_agent.is_navigation_finished():
		var next_location = nav_agent.get_next_path_position()
		var direction = (next_location - npc_position).normalized()
		
		# Calculate how far we want to move this frame
		var move_distance = walk_speed * delta
		var new_position = npc_position + (direction * move_distance)
		
		# Check if new position would be too close to player
		var new_distance_to_player = new_position.distance_to(player_position)
		
		#print("Moving - New distance to player: ", new_distance_to_player)
		
		if new_distance_to_player <= stopping_distance * 1.5:  # Allow 50% margin
			# We're at the stopping distance, stop here
			#print("NPC reached player (in motion)!")
			is_walking_to_player = false
			# Rotate to face away from player
			rotate_to_player()
			# Start the multi-dialog with camera rotation
			start_multi_dialog_with_camera()
		else:
			# Move the NPC
			$"../..".global_transform.origin = new_position
			
			# Make the NPC face the direction it's moving
			if direction.length() > 0:
				var look_at_point = npc_position - direction
				$"../..".look_at(look_at_point, Vector3.UP)

## rotate_to_player
## Rotates NPC to face away from player (180 degrees)
func rotate_to_player() -> void:
	if PlayerManager.player:
		var current_transform = $"../..".global_transform
		var target_transform = current_transform.looking_at(PlayerManager.player.global_position, Vector3.UP)
		target_transform = target_transform.rotated(Vector3.UP, PI)  # Flip 180 degrees
		
		# Get the target rotation
		target_rotation = target_transform.basis.get_euler().y
		is_rotating = true

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

## start_dialog
## Starts the dialog sequence after reaching the player (for direct interactions)
func start_dialog() -> void:
	# Calculate target rotation (looking away from player)
	rotate_to_player()
	
	# Start the dialog
	PlayerManager.talkToJanitor = true
	PlayerManager.MultiDialog(text_array)
	
	# Wait for dialog to finish
	await wait_for_dialog_completion()
	
	# If we rotated the camera, restore it
	if original_camera_rotation != Vector3.ZERO:
		restore_camera_rotation()
	
	# Resume wandering after interaction
	is_interacting = false
	is_wandering = true
	set_new_wander_target()

func _on_interacted(body: Variant) -> void:
	# Stop wandering and start interaction
	is_wandering = false
	is_interacting = true
	start_dialog()

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

func talkToPlayer():
	#print("talkToPlayer called - starting interaction")
	# Start walking to player
	AudioManager.cancel_loop_sfx()
	is_walking_to_player = true
	
	# Play initial dialog to freeze player
	if not has_initial_dialog_played:
		PlayerManager.talkToJanitor = true
		PlayerManager.multiDialog = true
		PlayerManager.CharacterDialog("Hey Wait up!")
		has_initial_dialog_played = true
		
		# Store original player rotation BEFORE rotating camera
		if PlayerManager.player:
			original_player_rotation = PlayerManager.player.rotation.y
			#print("Original player rotation stored: ", original_player_rotation)
		
		# Rotate camera to look at NPC immediately
		rotate_camera_to_npc_immediately()
		#print("Initial dialog and camera rotation complete")

## rotate_camera_to_npc_immediately
## Rotates the camera to look at the NPC when "Hey Wait up!" is said
func rotate_camera_to_npc_immediately():
	var camera = PlayerManager.player.CAMERA
	if camera:
		#print("Rotating camera to NPC")
		
		# Store original player transform BEFORE any rotation
		if PlayerManager.player:
			original_player_transform = PlayerManager.player.global_transform
			original_player_rotation = PlayerManager.player.rotation.y
			#print("Original player transform stored")
		
		# Store original camera rotation
		original_camera_rotation = camera.global_rotation
		#print("Original camera rotation stored: ", original_camera_rotation)
		
		# Get the positions - raise NPC position to look at upper body/head
		var npc_pos = $"../..".global_transform.origin + Vector3(0, 1.5, 0)
		
		# Create a transform that looks at the NPC
		var look_transform = camera.global_transform.looking_at(npc_pos, Vector3.UP)
		
		# Get the target rotation for the camera
		var target_rotation = look_transform.basis.get_euler()
		
		# Get current camera rotation
		var current_rotation = camera.global_rotation
		
		# Calculate the shortest rotation path
		var shortest_target_rotation = Vector3()
		shortest_target_rotation.x = current_rotation.x  # Keep the same pitch
		shortest_target_rotation.y = find_shortest_y_rotation(current_rotation.y, target_rotation.y)
		shortest_target_rotation.z = current_rotation.z  # Keep the same roll
		
		# Create a tween to rotate the camera smoothly
		var tween = create_tween()
		tween.tween_property(camera, "global_rotation", shortest_target_rotation, 0.5)
		#print("Camera rotation tween started")
	#else:
		#print("ERROR: Camera is null in rotate_camera_to_npc_immediately!")

## start_multi_dialog_with_camera
## Starts the multi-dialog with camera rotation after reaching player
func start_multi_dialog_with_camera():
	#print("=== START_MULTI_DIALOG_WITH_CAMERA CALLED ===")
	#print("Starting multi-dialog with camera")
	
	# Set interacting flag to keep NPC still
	is_interacting = true
	is_wandering = false  # Ensure NPC doesn't wander during dialog
	
	# First, make sure the player is facing the NPC
	rotate_player_to_npc()
	
	# Wait a moment to ensure rotation is complete
	await get_tree().create_timer(0.1).timeout
	
	# Start the multi-dialog
	#print("Starting MultiDialog with text_array")
	PlayerManager.talkToJanitor = true
	PlayerManager.MultiDialog(text_array)
	#print("MultiDialog called, waiting for completion...")
	
	# Wait for dialog to finish
	await wait_for_dialog_completion()
	#print("MultiDialog completed")
	
	# If we rotated the camera, restore it
	if original_camera_rotation != Vector3.ZERO:
		#print("Restoring camera rotation")
		restore_camera_rotation()
	
	# Reset flags and resume wandering AFTER dialog is completely done
	is_interacting = false
	is_wandering = true
	set_new_wander_target()
	#print("Interaction complete, NPC resuming wandering")

## rotate_player_to_npc
## Rotates the player to face the NPC
func rotate_player_to_npc():
	if PlayerManager.player:
		var player = PlayerManager.player
		var npc_pos = $"../..".global_transform.origin
		
		# Get the direction from player to NPC
		var direction_to_npc = (npc_pos - player.global_transform.origin).normalized()
		
		# Calculate the target rotation for the player (just yaw, keep pitch and roll)
		var target_y_rotation = atan2(direction_to_npc.x, direction_to_npc.z)
		
		# Get current player rotation
		var current_rotation = player.rotation.y
		
		# Find the shortest rotation
		var shortest_target_y = find_shortest_y_rotation(current_rotation, target_y_rotation)
		
		# Create a tween to rotate the player smoothly
		var tween = create_tween()
		tween.tween_property(player, "rotation:y", shortest_target_y, 0.5)
		
		#print("Player rotation to NPC started")
		
		# Also rotate the camera to look at NPC
		var camera = PlayerManager.player.CAMERA
		if camera:
			# Get the positions - raise NPC position to look at upper body/head
			var npc_pos_for_camera = $"../..".global_transform.origin + Vector3(0, 1.5, 0)
			
			# Create a transform that looks at the NPC
			var look_transform = camera.global_transform.looking_at(npc_pos_for_camera, Vector3.UP)
			
			# Get the target rotation for the camera
			var target_rotation_camera = look_transform.basis.get_euler()
			
			# Get current camera rotation
			var current_rotation_camera = camera.global_rotation
			
			# Calculate the shortest rotation path
			var shortest_target_rotation_camera = Vector3()
			shortest_target_rotation_camera.x = current_rotation_camera.x  # Keep the same pitch
			shortest_target_rotation_camera.y = find_shortest_y_rotation(current_rotation_camera.y, target_rotation_camera.y)
			shortest_target_rotation_camera.z = current_rotation_camera.z  # Keep the same roll
			
			# Create a tween to rotate the camera smoothly
			var camera_tween = create_tween()
			camera_tween.tween_property(camera, "global_rotation", shortest_target_rotation_camera, 0.5)
			
			# Wait for both rotations to complete
			await tween.finished
			await camera_tween.finished
		else:
			# Just wait for player rotation
			await tween.finished
		
		#print("Player and camera rotation to NPC complete")

## restore_camera_rotation
## Restores the camera to its original rotation AND player to its original orientation
func restore_camera_rotation():
	PlayerManager.multiDialog = true
	if PlayerManager.player:
		var camera = PlayerManager.player.CAMERA
		if camera:
			#print("Starting complete restoration of player and camera")
			
			# First, restore player's global transform (position and rotation)
			if original_player_transform:
				var player_tween = create_tween()
				player_tween.set_parallel(true)  # Run position and rotation tweens in parallel
				
				# Restore rotation
				var target_basis = original_player_transform.basis
				player_tween.tween_property(PlayerManager.player, "global_transform:basis", 
					target_basis, 0.5)
				
				# Optionally restore position too (if you want the player to return to exact spot)
				# player_tween.tween_property(PlayerManager.player, "global_transform:origin",
				#     original_player_transform.origin, 0.5)
				
				await player_tween.finished
				#print("Player transform restored")
			
			# Then restore camera rotation
			if original_camera_rotation != Vector3.ZERO:
				var camera_tween = create_tween()
				camera_tween.tween_property(camera, "global_rotation", 
					original_camera_rotation, 0.5)
				await camera_tween.finished
				#print("Camera rotation restored")
			
			# Reset stored values
			original_camera_rotation = Vector3.ZERO
			original_player_rotation = 0.0
			original_player_transform = Transform3D()
			
			#print("Restoration complete")
		#else:
			#print("ERROR: Camera is null in restore_camera_rotation!")
	#else:
		#print("ERROR: Player is null in restore_camera_rotation!")
		
	PlayerManager.multiDialog = false

func find_shortest_y_rotation(current: float, target: float) -> float:
	var difference = fmod(target - current, TAU)
	if difference > PI:
		difference -= TAU
	elif difference < -PI:
		difference += TAU
	return current + difference
