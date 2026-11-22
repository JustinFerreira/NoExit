## No Exit
## Overtime Studios
## Weeping Angel
## - Enemy that only moves while the player is NOT looking at it.
## Automatically inactive when the player is outside its NavigationRegion3D.
## - built on Enemy (see Enemy.gd)

extends Enemy

const WALK_SPEED: float = 3.0
## Its speed (rogue rounds vary it - a really fast angel now and then).
var walk_speed: float = WALK_SPEED
## Freezes the moment any part of it is on the player's screen (plus this
## much past the screen edge, as a fraction of the screen).
@export var screen_margin: float = 0.08
## Stays frozen this long after it leaves the player's view, so a quick
## glance away (or flicking past it) doesn't let it lunge.
@export var unfreeze_delay: float = 0.5

var _frozen_for: float = 0.0

var _map_ready: bool = false

func _enemy_ready() -> void:
	# gravity on, or it can walk up a ramp but never back down one
	use_gravity = true
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

func _enemy_physics(delta: float) -> void:
	# stand still unless it moves below (keeping velocity.y: gravity)
	velocity.x = 0.0
	velocity.z = 0.0
	if not _map_ready or not is_instance_valid(player) or not is_instance_valid(camera):
		return

	# Path rebuilt a few times a second, not every frame (see Enemy.set_nav_target)
	set_nav_target(player.global_position)
	# Do nothing if the player isn't reachable via navigation
	if not nav.is_target_reachable():
		return

	# Freeze while any part of the angel is on the player's screen, and for
	# a moment after
	if on_player_screen(body_grid_points() + bone_points(), screen_margin):
		_frozen_for = unfreeze_delay
		return
	if _frozen_for > 0.0:
		_frozen_for -= delta
		return
	move_along_nav(walk_speed)
