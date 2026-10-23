## Weeping Angel
## Enemy that freezes when the player is looking at it.
## Automatically inactive when the player is outside its NavigationRegion3D.
## - built on Enemy (see Enemy.gd)

extends Enemy

const WALK_SPEED: float = 3.0
## sight_fov_degrees (Vision group) is the half-angle of the PLAYER's view
## cone that freezes the angel here (90 = everything in front of them).

var _map_ready: bool = false

func _enemy_ready() -> void:
	use_gravity = false
	model_faces_plus_z = false
	acceleration = 1.0
	# Wait for the navigation map to finish its first sync before moving
	NavigationServer3D.map_changed.connect(_on_nav_map_changed)

func _on_nav_map_changed(_map: RID) -> void:
	if NavigationServer3D.map_get_iteration_id(nav.get_navigation_map()) > 0:
		_map_ready = true
		NavigationServer3D.map_changed.disconnect(_on_nav_map_changed)

## The level calls this every frame; the angel always goes for the player
## itself, so this is ignored.
func target_position(_target: Vector3) -> void:
	pass

func _enemy_physics(_delta: float) -> void:
	velocity = Vector3.ZERO
	if not _map_ready or not is_instance_valid(player) or not is_instance_valid(camera):
		return

	# Path rebuilt a few times a second, not every frame (see Enemy.set_nav_target)
	set_nav_target(player.global_position)
	# Do nothing if the player isn't reachable via navigation
	if not nav.is_target_reachable():
		return

	# Freeze while any part of the angel is on the player's screen
	if player_can_see_me(body_points(), sight_fov_degrees):
		return
	move_along_nav(WALK_SPEED)
