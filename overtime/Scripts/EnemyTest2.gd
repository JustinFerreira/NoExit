extends CharacterBody3D


var SPEED = 2.0

@onready var nav: NavigationAgent3D = get_node("NavigationAgent3D")
@onready var WalkingAnimator = $WalkingAnimation
@onready var StabbingAnimator = $StabbingAnimation

func _ready():
	PlayerManager.Enemy = self
	PlayerManager.no_enemy = false
	nav.path_desired_distance = 1.0  # Increase for smoother turns
	nav.target_desired_distance = 1.5  # Distance to consider target reached
	nav.path_max_distance = 3.0  # Max distance to recalculate path
	StabbingAnimator.connect("animation_finished", _on_animation_finished)

func _physics_process(delta: float) -> void:
	if PlayerManager.teleportEnemy && get_tree().get_first_node_in_group("teleport_target"):
		self.global_position = get_tree().get_first_node_in_group("teleport_target").global_position
		PlayerManager.teleportEnemy = false
		
	$Skeleton3D/killer_UV_unwrapped.visible = true
	WalkingAnimator.play_backwards("mixamo_com")
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y -= 2
	
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
	if position == target:
		return
	nav.target_position = target
	move_and_slide()

func calculate_path_distance() -> float:
	# Get the full navigation path
	var path = nav.get_current_navigation_path()
	var total_distance = 0.0
	
	# Sum the distances between each point in the path
	for i in range(path.size() - 1):
		total_distance += path[i].distance_to(path[i + 1])
	
	return total_distance
	
func kill():
	# Make the player face the enemy before stabbing
	if PlayerManager.player:
		PlayerManager.player.CAMERA.current = true
		PlayerManager.MiniGameModeOff()
		var player = PlayerManager.player
		
		# Get the positions
		var enemy_pos = global_transform.origin
		var player_pos = player.global_transform.origin
		
		# Calculate the direction from player to enemy
		var direction = (enemy_pos - player_pos).normalized()
		
		# Calculate the target angle
		var target_angle = atan2(-direction.x, -direction.z)
		
		# Get the current angle
		var current_angle = player.rotation.y
		
		# Find the shortest angle difference
		var angle_diff = fmod(target_angle - current_angle, TAU)
		if angle_diff > PI:
			angle_diff -= TAU
		elif angle_diff < -PI:
			angle_diff += TAU
		
		# Set the target angle to be the current angle plus the shortest difference
		var shortest_target_angle = current_angle + angle_diff
		
		# Create a tween to rotate the player
		var tween = create_tween()
		tween.tween_property(player, "rotation:y", shortest_target_angle, 0.5)
		
		# Wait for rotation to complete before stabbing
		await tween.finished
		
		# Debug: Print the final rotation to verify
		print("Current angle: ", current_angle)
		print("Target angle: ", target_angle)
		print("Angle difference: ", angle_diff)
		print("Shortest target angle: ", shortest_target_angle)
		print("Player rotation after tween: ", player.rotation)
		print("Enemy position: ", enemy_pos)
		print("Player position: ", player_pos)
	# Play the stabbing animation
	StabbingAnimator.play("Stabbing")

func _on_animation_finished(anim_name: String):
	
	if anim_name == "Stabbing":
		PlayerManager.player.GAMEOVER.visible =  true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().paused = true
