## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Killer Scipt
## - controls killer movement and actions

extends CharacterBody3D


var SPEED = 2.0

@onready var nav: NavigationAgent3D = get_node("NavigationAgent3D")
@onready var WalkingAnimator = $AnimationPlayer
@onready var StabbingAnimator = $StabbingAnimation

var teleports

# Stalking mode variables
var stalking_mode: bool = false
var stalking_distance: float = 15.0
var original_speed: float
var is_invisible: bool = false
var is_silent: bool = false

# For maintaining distance
var is_stalking: bool = false
var stalk_target_position: Vector3
var stalk_around_player: bool = true

# Timers for stalking behavior
var stalk_direction_change_timer: float = 0.0
var stalk_direction_change_interval: float = 3.0
var current_stalk_angle: float = 0.0

# Visual/Audio references
@onready var visibility_timer: Timer = $VisibilityTimer  # You'll need to add this Timer node
@onready var original_material: Material = $Armature/Skeleton3D/M_Killer_LowUV.get_surface_override_material(0)  # Adjust path as needed

func _ready():
	PlayerManager.Enemy = self
	PlayerManager.no_enemy = false
	WalkingAnimator.speed_scale = 2.0
	$Armature.visible = true
	nav.path_desired_distance = 1.0  # Increase for smoother turns
	nav.target_desired_distance = 1.5  # Distance to consider target reached
	nav.path_max_distance = 3.0  # Max distance to recalculate path
	StabbingAnimator.connect("animation_finished", _on_animation_finished)
	if not PlayerManager.OpeningCutscene:
		teleports = get_tree().get_nodes_in_group("teleport_target")
	if PlayerManager.Loop0:
		find_teleport_target("OutOfBoundsTeleport")
	

func _physics_process(delta: float) -> void:
	if PlayerManager.teleportEnemy && teleports:
		if PlayerManager.Loop0:
			find_teleport_target("NearCarTeleport")
		else: 
			find_teleport_target("FarTeleport")
		PlayerManager.teleportEnemy = false
	
	if not PlayerManager.dying:
		WalkingAnimator.play("Scene")
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y -= 2
	
	
	# Handle stalking mode behavior
	if stalking_mode and PlayerManager.player:
		handle_stalking_behavior(delta)
	else:
		if PlayerManager.MinigameMode:
			SPEED = 4.0
		else:
			SPEED = 2.0
		
		var next_location = nav.get_next_path_position()
		var current_location = global_transform.origin
		var new_velocity = (next_location - current_location).normalized() * SPEED

		# Make the enemy face the direction it's moving
		if new_velocity.length() > 0:
			look_at(global_transform.origin - new_velocity, Vector3.UP)

		velocity = velocity.move_toward(new_velocity, 0.25)
	move_and_slide()
	
	# Calculate path distance to target
	PlayerManager.scaredDistance = calculate_path_distance()
	
	
	
func target_position(target):
	if stalking_mode:
		return
	if position == target:
		return
	nav.target_position = target
	move_and_slide()
	
func find_teleport_target(targetname):
	for target in teleports:
		if target.name == targetname:
			self.global_position = target.global_position

func calculate_path_distance() -> float:
	# Get the full navigation path
	var path = nav.get_current_navigation_path()
	var total_distance = 0.0
	
	# Sum the distances between each point in the path
	for i in range(path.size() - 1):
		total_distance += path[i].distance_to(path[i + 1])
	
	return total_distance
	
func kill():
	$Armature.visible = false
	$Skeleton3D.visible = true
	$Skeleton3D/killer_UV_unwrapped.visible = true
	PlayerManager.HideDialog()
	PlayerManager.dying = true
	PlayerManager.InAnimation = true
	if PlayerManager.minigameTwo:
		PlayerManager.minigameTwo = false
		PlayerManager.gasIntakeUI.visible = false
		PlayerManager.Gas_Canister.visible = false
		PlayerManager.gasIntakeSweetSpot.visible = false
	if PlayerManager.minigameThree:
		PlayerManager.hoodUI.visible = false
	# Make the player's camera face the enemy before stabbing
	if PlayerManager.player and PlayerManager.player.CAMERA:
		PlayerManager.player.CAMERA.current = true
		PlayerManager.MiniGameModeOff()
		PlayerManager.player.CURSOR.visible = false
		var camera = PlayerManager.player.CAMERA
	
		
		# Get the positions - raise enemy position to look at upper body/head
		var enemy_pos = global_transform.origin + Vector3(0, 1.5, 0)  # Raise by 1.5 meters
		var camera_pos = camera.global_transform.origin
		
		# Calculate the direction from camera to enemy
		var direction = (enemy_pos - camera_pos).normalized()
		
		# Create a transform that looks at the enemy
		var look_transform = camera.global_transform.looking_at(enemy_pos, Vector3.UP)
		
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
		
		# Wait for rotation to complete before stabbing
		await tween.finished
	
	# Play the stabbing animation
	StabbingAnimator.play("Stabbing")
	AudioManager.KillerShutUp = true
	AudioManager.play_sound_loop(AudioManager.SkullCrush, "Kill")
	
# Helper function to find the shortest Y rotation path
func find_shortest_y_rotation(current: float, target: float) -> float:
	var difference = fmod(target - current, TAU)
	if difference > PI:
		difference -= TAU
	elif difference < -PI:
		difference += TAU
	return current + difference

func _on_animation_finished(anim_name: String):
	
	if anim_name == "Stabbing":
		AudioManager.stop_loop("Kill")
		if PlayerManager.OpeningCutscene:
			PlayerManager.OpeningCutscene = false
			get_tree().change_scene_to_file("res://Levels/Office.tscn")
			PlayerManager.Loop0 = true
			return
		elif PlayerManager.Loop0:
			PlayerManager.Loop0 = false
			
			#EventManager Function fix
			SettingsManager.Loop0Pass = true
			SettingsManager.save_settings()
			
			get_tree().change_scene_to_file("res://Levels/Office.tscn")
			return
		PlayerManager.player.GAMEOVER.visible =  true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().paused = true
	
	
## New function to handle stalking behavior
func handle_stalking_behavior(delta: float) -> void:
	if not PlayerManager.player:
		return
	
	var player_pos = PlayerManager.player.global_transform.origin
	var current_pos = global_transform.origin
	var distance_to_player = current_pos.distance_to(player_pos)
	
	# Update stalking direction periodically
	stalk_direction_change_timer -= delta
	if stalk_direction_change_timer <= 0:
		stalk_direction_change_timer = stalk_direction_change_interval
		# Randomly change angle to move around player
		current_stalk_angle += randf_range(-PI/4, PI/4)
	
	# Calculate desired position at stalking distance from player
	var direction_to_player = (player_pos - current_pos).normalized()
	
	# If too close, move away
	if distance_to_player < stalking_distance * 0.8:
		# Move away from player
		var away_direction = -direction_to_player
		var target_pos = current_pos + away_direction * (stalking_distance - distance_to_player) * 2
		
		# Add some circling movement
		var perpendicular = Vector3(-direction_to_player.z, 0, direction_to_player.x).normalized()
		target_pos += perpendicular * sin(current_stalk_angle) * 3
		
		nav.target_position = target_pos
		
	# If too far, move closer
	elif distance_to_player > stalking_distance * 1.2:
		# Move toward player, but maintain some distance
		var approach_direction = direction_to_player
		var target_pos = player_pos - approach_direction * (stalking_distance * 0.9)
		
		# Add some circling movement
		var perpendicular = Vector3(-direction_to_player.z, 0, direction_to_player.x).normalized()
		target_pos += perpendicular * cos(current_stalk_angle) * 3
		
		nav.target_position = target_pos
		
	# If at good distance, circle
	else:
		# Circle around player
		var circle_radius = stalking_distance
		var circle_center = player_pos
		
		# Calculate position on circle
		var circle_x = cos(current_stalk_angle) * circle_radius
		var circle_z = sin(current_stalk_angle) * circle_radius
		var target_pos = circle_center + Vector3(circle_x, 0, circle_z)
		
		nav.target_position = target_pos
	
	# Move towards target position
	var next_location = nav.get_next_path_position()
	var move_direction = (next_location - current_pos).normalized()
	
	# Face movement direction
	if move_direction.length() > 0:
		look_at(global_transform.origin - move_direction, Vector3.UP)
	
	# Apply movement
	velocity = velocity.move_toward(move_direction * SPEED, 0.25)

## Add this function to handle entering stalking mode
func enter_stalking_mode(distance: float, invisible: bool = true, silent: bool = true) -> void:
	if stalking_mode:
		return  # Already in stalking mode
		
	stalking_mode = true
	stalking_distance = distance
	is_invisible = invisible
	is_silent = silent
	
	# Store original speed
	original_speed = SPEED
	
	# Set speed to 0 while stalking (or very slow if you want them to reposition slowly)
	SPEED = 0.5
	
	# Handle invisibility
	if is_invisible:
		make_invisible()
	
	# Handle silence
	if is_silent:
		make_silent()
	
	# Initialize stalking behavior
	current_stalk_angle = randf_range(0, 2 * PI)
	stalk_direction_change_timer = stalk_direction_change_interval

## Add this function to handle exiting stalking mode
func exit_stalking_mode() -> void:
	if not stalking_mode:
		return
		
	stalking_mode = false
	
	# Restore original speed
	SPEED = original_speed
	
	# Restore visibility
	if is_invisible:
		make_visible()
	
	# Restore audio
	if is_silent:
		make_audible()
	
	is_invisible = false
	is_silent = false

## Make killer invisible
func make_invisible() -> void:
	# Hide the main model
	$Armature.visible = false
	$Skeleton3D.visible = false
	
	# Option 1: Completely invisible
	# No additional code needed
	
	# Option 2: Fade out with transparency (uncomment if you want this)
	# var material = $Armature.get_surface_override_material(0)
	# if material:
	#     var new_material = material.duplicate()
	#     new_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	#     new_material.albedo_color.a = 0.0
	#     $Armature.set_surface_override_material(0, new_material)

## Make killer visible again
func make_visible() -> void:
	$Armature.visible = true
	$Skeleton3D.visible = true
	
	# Restore original material if using transparency method
	# if original_material:
	#     $Armature.set_surface_override_material(0, original_material)

## Make killer silent
func make_silent() -> void:
	# Stop any footstep or idle sounds
	AudioManager.stop_loop("step")  # If killer makes step sounds
	# Add any other killer audio stops here

## Make killer audible again
func make_audible() -> void:
	# Restart sounds if needed
	pass
