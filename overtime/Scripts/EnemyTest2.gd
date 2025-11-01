extends CharacterBody3D


const SPEED = 2.0

##stuck variables
var is_stuck = false
var stuck_timer = 0.0


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
	
		
	
	
	
func target_position(target):
	if position == target:
		return
	nav.target_position = target
	move_and_slide()
	
	var overlaps = $Area3D.get_overlapping_areas()
	if overlaps.size() > 0:
		for overlap in overlaps:
			if overlap.name == "Player":
				PlayerManager.playerInRange = true
			else:
				PlayerManager.playerInRange = false
	
	var distance = global_position.distance_to(target)
	PlayerManager.scaredPitch = distance

	
