extends CharacterBody3D


const SPEED = 2.0

@onready var nav: NavigationAgent3D = get_node("NavigationAgent3D")

func _ready():
	PlayerManager.no_enemy = false
	nav.path_desired_distance = 1.0  # Increase for smoother turns
	nav.target_desired_distance = 1.5  # Distance to consider target reached
	nav.path_max_distance = 3.0  # Max distance to recalculate path

func _physics_process(delta: float) -> void:
	if PlayerManager.teleportEnemy:
		self.global_position = get_tree().get_first_node_in_group("teleport_target").global_position
		PlayerManager.teleportEnemy = false
	$MeshInstance3D.visible = false
	$Skeleton3D.visible = true
	$AnimationPlayer.play("mixamo_com")
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y -= 2
	
	
	var next_location = nav.get_next_path_position()
	var current_location = global_transform.origin
	var new_velocity = (next_location - current_location).normalized() * SPEED

	# Make the enemy face the direction it's moving
	if new_velocity.length() > 0:
		look_at(global_transform.origin - new_velocity, Vector3.UP)

	velocity = velocity.move_toward(new_velocity, 0.25)
	move_and_slide()
	
	# Calculate path distance to target
	var path_distance = calculate_path_distance()
	PlayerManager.scaredPitch = path_distance
	
	# Update player detection
	update_player_detection()
	
	
	
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

func update_player_detection():
	$ShapeCast3D.force_shapecast_update()
	
	# Check if the ShapeCast3D is colliding with anything
	if $ShapeCast3D.is_colliding():
		var collider = $ShapeCast3D.get_collider(0)  # Get the first collider
		if collider and collider.name == "Player":
			PlayerManager.playerInRange = true
		else:
			PlayerManager.playerInRange = false
	else:
		PlayerManager.playerInRange = false
