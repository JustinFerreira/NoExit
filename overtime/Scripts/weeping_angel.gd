## Weeping Angel
## Enemy that freezes when the player is looking at it.
## Automatically inactive when the player is outside its NavigationRegion3D.

extends CharacterBody3D

@onready var NAV: NavigationAgent3D = $NavigationAgent3D

const WALK_SPEED: float = 3.0
## Half-angle of the player's FOV cone that freezes the angel (90° = 180° total cone)
@export var sight_fov_degrees: float = 90.0

var player: Node3D = null
var camera: Camera3D = null

var _map_ready: bool = false

func _ready() -> void:
	player = PlayerManager.player
	camera = player.CAMERA
	add_to_group("enemy")
	# Wait for the navigation map to finish its first sync before moving
	NavigationServer3D.map_changed.connect(_on_nav_map_changed)

func _on_nav_map_changed(_map: RID) -> void:
	if NavigationServer3D.map_get_iteration_id(NAV.get_navigation_map()) > 0:
		_map_ready = true
		NavigationServer3D.map_changed.disconnect(_on_nav_map_changed)

func _physics_process(delta: float) -> void:
	if not _map_ready:
		return
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return

	# Do nothing if the player isn't reachable via navigation
	NAV.target_position = player.global_position
	if not NAV.is_target_reachable():
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if _player_can_see_me():
		# Freeze — do nothing
		velocity = Vector3.ZERO
	else:
		_move_toward_player(delta)

	move_and_slide()

func kill() -> void:
	PlayerManager.deaths += 1
	AudioManager.play_sound(AudioManager.StringStinger)
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
	if PlayerManager.player and PlayerManager.player.CAMERA:
		PlayerManager.player.CAMERA.current = true
		PlayerManager.MiniGameModeOff()
		PlayerManager.player.CURSOR.visible = false
		var head = PlayerManager.player.HEAD
		var playercamera = PlayerManager.player.CAMERA

		# Target the angel's face — scale 1.8 by the node's world scale so it
		# lands at eye level regardless of how large the instance is in the level
		var world_scale = global_transform.basis.x.length()
		var face_pos = global_transform.origin + Vector3(0, 1.8 * world_scale, 0)
		var to_face = (face_pos - PlayerManager.player.CAMERA.global_position).normalized()
		var h_dist = Vector2(to_face.x, to_face.z).length()

		# Yaw: rotate head horizontally toward angel
		var target_yaw = atan2(-to_face.x, -to_face.z)
		target_yaw = HelperManager.find_shortest_y_rotation(head.rotation.y, target_yaw)

		# Pitch: tilt camera vertically toward angel's face, offset 35° downward
		var target_pitch = clamp(atan2(to_face.y, h_dist) - deg_to_rad(35), deg_to_rad(-60), deg_to_rad(60))

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(head, "rotation:y", target_yaw, 0.5)
		tween.tween_property(playercamera, "rotation:x", target_pitch, 0.5)
		await tween.finished

		await get_tree().create_timer(2.0).timeout
		PlayerManager.player.GAMEOVER.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().paused = true

func _player_can_see_me() -> bool:
	# Sample several points on the angel's body — freeze if ANY are visible
	var world_scale = global_transform.basis.x.length()
	var sample_points: Array[Vector3] = [
		global_position + Vector3(0, 0.3 * world_scale, 0),  # shins
		global_position + Vector3(0, 0.7 * world_scale, 0),  # waist
		global_position + Vector3(0, 1.0 * world_scale, 0),  # chest
		global_position + Vector3(0, 1.4 * world_scale, 0),  # shoulders
		global_position + Vector3(0, 1.7 * world_scale, 0),  # head
	]

	var cam_forward = -camera.global_transform.basis.z
	var cos_fov = cos(deg_to_rad(sight_fov_degrees))
	var space = get_world_3d().direct_space_state

	for aim_pos in sample_points:
		# FOV check for this sample point
		var to_enemy = (aim_pos - camera.global_position).normalized()
		if to_enemy.dot(cam_forward) < cos_fov:
			continue

		# Line of sight check
		var params = PhysicsRayQueryParameters3D.create(
			camera.global_position, aim_pos
		)
		params.exclude = [player]
		var result = space.intersect_ray(params)

		if result and result.collider == self:
			return true

	return false

func _move_toward_player(_delta: float) -> void:
	if NAV.is_navigation_finished():
		return

	var next_point = NAV.get_next_path_position()
	var direction = (next_point - global_position).normalized()

	velocity = direction * WALK_SPEED

	# Face the direction of movement
	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)
