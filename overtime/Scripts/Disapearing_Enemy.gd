## DisappearEnemy.gd
## Visible when first seen, disappears permanently when player looks away

extends CharacterBody3D

## Maximum distance at which the enemy counts as "seen"
@export var max_sight_range: float = 80.0
## Half-angle (degrees) of the player's field of view for the seen check
@export var sight_fov_degrees: float = 80.0

var player: Node3D = null
var camera: Camera3D = null

enum State { WAITING, SEEN, GONE }
var state: State = State.WAITING

func _ready() -> void:
	player = PlayerManager.player
	camera = player.CAMERA
	visible = true  # starts visible so player can encounter it naturally

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return

	match state:
		State.WAITING:
			# Do nothing until player first sees it
			if _player_can_see_me():
				state = State.SEEN
				#print("[DisappearEnemy] First seen by player")

		State.SEEN:
			# The moment the player looks away, vanish permanently
			if not _player_can_see_me():
				state = State.GONE
				visible = false
				#print("[DisappearEnemy] Player looked away — gone forever")

		State.GONE:
			# Do nothing, enemy is permanently gone
			pass

func _player_can_see_me() -> bool:
	# Target chest height so the check doesn't clip the floor
	var aim_pos = global_position + Vector3(0, 1.0, 0)

	# 1. Must be within the player's field of view
	var to_enemy = (aim_pos - camera.global_position).normalized()
	var cam_forward = -camera.global_transform.basis.z
	var angle = rad_to_deg(to_enemy.angle_to(cam_forward))
	if angle > sight_fov_degrees:
		return false

	# 2. Must be within range
	if camera.global_position.distance_to(aim_pos) > max_sight_range:
		return false

	# 3. Line-of-sight raycast — make sure no geometry is blocking the view
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		camera.global_position,
		aim_pos,
		0xFFFFFFFF,
		[player.get_rid()]  # exclude the player's own body
	)
	query.collide_with_areas = false
	var result := space.intersect_ray(query)

	# If nothing was hit the path is clear; if the first hit IS this enemy, also clear
	if result.is_empty():
		return true
	return result["collider"] == self
