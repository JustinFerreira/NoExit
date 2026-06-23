## Weeping Angel
## Enemy that freezes when the player is looking at it

extends CharacterBody3D

@onready var NAV: NavigationAgent3D = $NavigationAgent3D

const WALK_SPEED: float = 3.0
var player: Node3D = null
var camera: Camera3D = null

func _ready() -> void:
	# Grab player and camera from your existing PlayerManager
	player = PlayerManager.player
	camera = player.CAMERA
	add_to_group("enemy")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return
	
	if _player_can_see_me():
		# Freeze — do nothing
		velocity = Vector3.ZERO
	else:
		_move_toward_player(delta)
	
	move_and_slide()

func _player_can_see_me() -> bool:
	var enemy_pos = global_position
	
	# First check if we're even in the camera's FOV
	if not camera.is_position_in_frustum(enemy_pos):
		return false
	
	# Line of sight check — are we blocked by a wall?
	var space = get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.create(
		camera.global_position, enemy_pos
	)
	params.exclude = [player]
	var result = space.intersect_ray(params)
	
	# Seen only if the ray hits us specifically
	return result and result.collider == self

func _move_toward_player(delta: float) -> void:
	NAV.target_position = player.global_position
	
	if NAV.is_navigation_finished():
		return
	
	var next_point = NAV.get_next_path_position()
	var direction = (next_point - global_position).normalized()
	
	velocity = direction * WALK_SPEED
	
	# Face the direction of movement
	if direction.length() > 0.1:
		var look_target = global_position + direction
		look_at(look_target, Vector3.UP)
