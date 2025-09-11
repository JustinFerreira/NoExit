extends CharacterBody3D


const SPEED = 2.0

@onready var nav: NavigationAgent3D = get_node("NavigationAgent3D")

func _physics_process(delta: float) -> void:
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
		look_at(global_transform.origin + new_velocity, Vector3.UP)

	velocity = velocity.move_toward(new_velocity, 0.25)
	move_and_slide()
	
func target_position(target):
	nav.target_position = target
	move_and_slide()
