## No Exit
## Overtime Studios
## Last updated 2/24/26 by Justin Ferreira
## DialogNPC Script
## This script is what the Janitor uses for all its 
## operations such as wander and talking to player
## Updated with walking and idle animations
## - built on NPC (see NPC.gd): root, play_walk/play_idle, face_direction,
##   say_sequence come from there


extends NPC

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

# Animation variables
@export var animation_player_walk: AnimationPlayer 
@export var animation_player_idle: AnimationPlayer
var last_position: Vector3
var current_animation: String = "idle"  # Track current animation state

var current_tween: Tween = null

@export var normal_walk_speed_scale: float = 1.0   # Normal wander speed
@export var fast_walk_speed_scale: float = 2    # Faster when walking to player

var has_stored_transform: bool = false

# Mop & bucket - dragged behind the janitor on an invisible "rope" instead of
# turning with him. The first name is the thing being dragged (the bucket);
# the rest stay attached to it (the mop leaning in it, its collision).
@export var dragged_prop_names: Array[String] = ["MMopBucket", "MMop", "StaticBody3D"]
## How fast the bucket swings round to trail behind him while dragged.
@export var drag_turn_speed: float = 4.0
var _drag_props: Array[Node3D] = []
var _drag_offsets: Array[Transform3D] = []   # each prop relative to the bucket
var _drag_length: float = 0.0                 # rope length (janitor -> bucket)
var _drag_yaw_offset: float = 0.0             # bucket yaw relative to "handle toward janitor"

# Path rebuilds are limited to a few a second (walking to the player used to
# rebuild the path every frame).
const REPATH_INTERVAL := 0.25
var _repath_timer := 0.0

func _npc_ready() -> void:
	# The janitor's own inspector slots feed the NPC animation helpers.
	walk_animation_player = animation_player_walk
	idle_animation_player = animation_player_idle
	for p in [animation_player_walk, animation_player_idle]:
		if p and not p.animation_finished.is_connected(_on_npc_animation_finished):
			p.animation_finished.connect(_on_npc_animation_finished)
	play_walk()
	start_position = root.global_transform.origin
	last_position = root.global_transform.origin
	
	# Get the NavigationAgent3D - adjust the path if needed
	nav_agent = root.get_node("NavigationAgent3D")
	
	# Set up navigation agent
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	
	PlayerManager.janitor = self
	PlayerManager.talkToJanitor = false

	set_new_wander_target()
	_setup_dragged_props.call_deferred()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:	
	if is_rotating:
		# Smoothly rotate toward target rotation
		var current_rotation = root.rotation.y
		root.rotation.y = lerp_angle(current_rotation, target_rotation, rotation_speed * delta)
		
		# Check if we're close enough to the target rotation
		if abs(angle_difference(current_rotation, target_rotation)) < 0.05:
			root.rotation.y = target_rotation
			is_rotating = false
	
	# Handle walking to player if in that state
	if is_walking_to_player and PlayerManager.player:
		# Check if we're already close enough before walking
		var player_position = PlayerManager.player.global_transform.origin
		var npc_position = root.global_transform.origin
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
		
	# Walk while moving, idle otherwise (play_walk/play_idle stop the other
	# player, so the two animations never fight over the skeleton).
	if is_walking_to_player:
		play_walk(fast_walk_speed_scale)
	elif is_wandering:
		play_walk(normal_walk_speed_scale)
	else:
		play_idle()
	_repath_timer -= delta

	_update_dragged_props(delta)

## _setup_dragged_props
## Detaches the mop & bucket from the janitor's rotation (top_level keeps
## them in world space) and remembers how they sit relative to each other.
func _setup_dragged_props() -> void:
	var npc: Node3D = root
	for prop_name in dragged_prop_names:
		var n = npc.get_node_or_null(NodePath(prop_name))
		if n is Node3D:
			_drag_props.append(n)
	if _drag_props.is_empty():
		return
	var bucket_gt: Transform3D = _drag_props[0].global_transform
	for n in _drag_props:
		_drag_offsets.append(bucket_gt.affine_inverse() * n.global_transform)
	for n in _drag_props:
		var gt := n.global_transform
		n.top_level = true
		n.global_transform = gt
	var to_npc := npc.global_position - bucket_gt.origin
	to_npc.y = 0.0
	_drag_length = to_npc.length()
	_drag_yaw_offset = bucket_gt.basis.get_euler().y - atan2(to_npc.x, to_npc.z)

## _update_dragged_props
## Rope behaviour: the bucket only moves when the janitor walks farther away
## than the rope allows, then it's pulled along behind him and swings so its
## handle points at him. Turning on the spot doesn't move it at all.
func _update_dragged_props(delta: float) -> void:
	if _drag_props.is_empty() or not is_instance_valid(_drag_props[0]):
		return
	var npc: Node3D = root
	var bucket: Node3D = _drag_props[0]
	var gt := bucket.global_transform
	var to_npc := npc.global_position - gt.origin
	to_npc.y = 0.0
	var dist := to_npc.length()
	if dist <= _drag_length or dist < 0.001:
		return   # rope is slack - leave the bucket where it is
	# Pull the bucket to rope length behind him (keep its height).
	var dir := to_npc / dist
	var pos := gt.origin + dir * (dist - _drag_length)
	# Swing toward trailing straight behind.
	var target_yaw := atan2(dir.x, dir.z) + _drag_yaw_offset
	var yaw := lerp_angle(gt.basis.get_euler().y, target_yaw, clampf(drag_turn_speed * delta, 0.0, 1.0))
	var bucket_scale := gt.basis.get_scale()
	gt = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(bucket_scale), pos)
	for i in _drag_props.size():
		if is_instance_valid(_drag_props[i]):
			_drag_props[i].global_transform = gt * _drag_offsets[i]

## walk_to_player
## Moves NPC toward the player's current position
func walk_to_player(delta: float) -> void:
	if not PlayerManager.player:
		is_walking_to_player = false
		return
	
	# Update target to player's current position
	var player_position = PlayerManager.player.global_transform.origin
	var npc_position = root.global_transform.origin
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
	
	# Set navigation target to the calculated position (a few times a second)
	if _repath_timer <= 0.0 or nav_agent.target_position.distance_to(target_position) > 2.0:
		nav_agent.target_position = target_position
		_repath_timer = REPATH_INTERVAL
	
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
			root.global_transform.origin = new_position
			
			# Make the NPC face the direction it's moving
			if direction.length() > 0:
				# FIXED: Changed from + direction to - direction
				# In Godot, look_at() makes the object's -Z axis point toward the target
				# So to face the movement direction, we need to look at a point BEHIND us
				face_direction(direction)
			
			# Animation will be updated by update_animation_state() in _process

## rotate_to_player
## Rotates NPC to face away from player (180 degrees)
func rotate_to_player() -> void:
	if PlayerManager.player:
		var current_transform = root.global_transform
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
		var current_location = root.global_transform.origin
		var direction = (next_location - current_location).normalized()
		
		# Move the NPC
		root.global_transform.origin += direction * wander_speed * delta
		
		# Make the NPC face the direction it's moving
		if direction.length() > 0:
			# FIXED: Changed from - direction to + direction
			# Wait, actually for wander we want the same logic as walk_to_player
			# Using - direction makes the NPC face forward
			face_direction(direction)
		
		# Animation will be updated by update_animation_state() in _process
	
	# Check if we need a new target (even if not finished with current path)
	if wander_timer <= 0:
		set_new_wander_target()

## set_new_wander_target
## picks a random position for the npc
## to wander to
func set_new_wander_target() -> void:
	play_walk(normal_walk_speed_scale)
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
	await say_sequence(EventManager.janitor_text_array)
	
	# If we rotated the camera, restore it
	if original_camera_rotation != Vector3.ZERO:
		restore_camera_rotation()
	
	# Resume wandering after interaction
	is_interacting = false
	is_wandering = true
	set_new_wander_target()

func _on_interacted(_body: Variant) -> void:
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
	is_wandering = false
	
	# Play initial dialog to freeze player
	if not has_initial_dialog_played:
		PlayerManager.talkToJanitor = true
		PlayerManager.InAnimation = true
		PlayerManager.CharacterDialog(EventManager.janitor_didnt_speak_text)
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
	if current_tween and current_tween.is_running():
		current_tween.kill()

	var camera = PlayerManager.player.CAMERA
	if not camera:
		return

	# Store original transforms
	if PlayerManager.player:
		original_player_transform = PlayerManager.player.global_transform
		original_player_rotation = PlayerManager.player.rotation.y
		has_stored_transform = true

	original_camera_rotation = camera.global_rotation

	var npc_pos = root.global_transform.origin + Vector3(0, 1.5, 0)
	var look_transform = camera.global_transform.looking_at(npc_pos, Vector3.UP)
	var target_camera_rotation = look_transform.basis.get_euler()
	var current_rotation = camera.global_rotation

	var shortest_target_rotation = Vector3(
		current_rotation.x,
		find_shortest_y_rotation(current_rotation.y, target_camera_rotation.y),
		current_rotation.z
	)

	# Now current_tween actually has a tweener
	current_tween = create_tween()
	current_tween.tween_property(camera, "global_rotation", shortest_target_rotation, 0.5)

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
	await say_sequence(EventManager.janitor_text_array)
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
	play_idle()
	if PlayerManager.player:
		var player = PlayerManager.player
		var npc_pos = root.global_transform.origin
		
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
			var npc_pos_for_camera = root.global_transform.origin + Vector3(0, 1.5, 0)
			
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
			if has_stored_transform:
				var player_tween = create_tween()
				player_tween.set_parallel(true)
				player_tween.tween_property(PlayerManager.player, "global_transform:basis",
					original_player_transform.basis, 0.5)
				await player_tween.finished

			if original_camera_rotation != Vector3.ZERO:
				var camera_tween = create_tween()
				camera_tween.tween_property(camera, "global_rotation",
					original_camera_rotation, 0.5)
				await camera_tween.finished

			# Reset
			original_camera_rotation = Vector3.ZERO
			original_player_rotation = 0.0
			original_player_transform = Transform3D()
			has_stored_transform = false  # ← reset flag

	PlayerManager.multiDialog = false
	PlayerManager.InAnimation = false

func find_shortest_y_rotation(current: float, target: float) -> float:
	return HelperManager.find_shortest_y_rotation(current, target)
