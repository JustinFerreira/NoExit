## No Exit
## Overtime Studios
## Last updated 10/19/26 by Justin Ferreira
## Enemy Script
## - parent class for every enemy (Killer, WanderingEnemy, WeepingAngel,
##   DisappearingEnemy). To make a new enemy: put a CharacterBody3D in a
##   scene (add a NavigationAgent3D child if it walks), attach a script that
##   starts with "extends Enemy", and override the hooks you need:
##     _enemy_ready()          - your setup (instead of _ready)
##     _enemy_physics(delta)   - your per-frame behaviour (instead of
##                               _physics_process); move_and_slide() is
##                               called for you afterwards
##     target_position(pos)    - levels call this with the player position
##     _before_kill_turn()     - runs when the enemy catches the player
##     _play_kill()            - the kill itself (default: game over)
## What you get for free:
##   player / camera           - found automatically (retried until found)
##   nav                       - the NavigationAgent3D child, if there is one
##   set_nav_target(pos)       - path-finding that only recalculates a few
##                               times a second, not every frame
##   move_along_nav(speed)     - walk along the path, facing where it goes
##   face_direction(dir)       - turn to face a direction (yaw only)
##   apply_gravity(delta)      - done for you while use_gravity is on
##   can_see_player()          - the enemy's own vision cone + line of sight
##   player_can_see_me(points) - is any of these points on the player's screen
##   kill()                    - the shared "caught the player" sequence

extends CharacterBody3D
class_name Enemy

@export_group("Movement")
## Default speed for move_along_nav().
@export var move_speed: float = 2.0
## Fall when off the floor (and stick to it when on it).
@export var use_gravity: bool = true
## How quickly velocity reaches its new value each physics tick (0-1, 1 = instant).
@export_range(0.0, 1.0) var acceleration: float = 0.25
## Seconds between path recalculations while the target keeps moving.
@export var repath_interval: float = 0.25
## Recalculate straight away if the target jumps farther than this.
@export var repath_distance: float = 2.0
## Which way the model faces: true = its +Z is the front (Mixamo/most of
## our models), false = Godot's usual -Z.
@export var model_faces_plus_z: bool = true

@export_group("Vision")
## How far the enemy can see the player (can_see_player).
@export var sight_range: float = 20.0
## Half-angle of the enemy's vision cone, in degrees.
@export var sight_fov_degrees: float = 60.0
## Height above the enemy's origin its eyes are (and the player's aim point).
@export var sight_height_offset: float = 1.0

@export_group("Kill")
## Touching the player kills them (Player calls kill()). Off = harmless.
@export var can_kill_player: bool = true
## Height of the face the player is turned to look at when caught.
@export var face_height: float = 1.8
## The player's view tilts this far below the face while being caught.
@export var kill_look_down_degrees: float = 35.0
## Default kill only: seconds after the turn before the game over screen.
@export var game_over_delay: float = 2.0

var player: Node3D = null
var camera: Camera3D = null
var nav: NavigationAgent3D = null

var _nav_target: Vector3 = Vector3.INF
var _pending_target: Vector3
var _nav_target_pending := false
var _repath_timer := 0.0

func _ready() -> void:
	add_to_group("enemy")
	for child in get_children():
		if child is NavigationAgent3D:
			nav = child
			break
	_find_player()
	_enemy_ready()

func _physics_process(delta: float) -> void:
	if player == null:
		_find_player()
	if use_gravity:
		apply_gravity(delta)
	_update_nav_target(delta)
	_enemy_physics(delta)
	move_and_slide()

## Hooks - override these in your enemy.
func _enemy_ready() -> void:
	pass

func _enemy_physics(_delta: float) -> void:
	pass

## Levels call this on every enemy with the player's position.
## Default: chase that position.
func target_position(target: Vector3) -> void:
	set_nav_target(target)

func _find_player() -> void:
	if PlayerManager.player and is_instance_valid(PlayerManager.player):
		player = PlayerManager.player
		camera = player.CAMERA

## ---------------------------------------------------------------------
## Movement
## ---------------------------------------------------------------------

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y -= 2.0

## set_nav_target
## Where to walk to. Safe to call every frame: the path is only rebuilt
## every repath_interval seconds, or right away if the target jumped.
func set_nav_target(target: Vector3) -> void:
	if nav == null:
		return
	if _nav_target == Vector3.INF or target.distance_to(_nav_target) > repath_distance:
		_apply_nav_target(target)
	else:
		_pending_target = target
		_nav_target_pending = true

func _update_nav_target(delta: float) -> void:
	_repath_timer -= delta
	if _nav_target_pending and _repath_timer <= 0.0:
		_apply_nav_target(_pending_target)

func _apply_nav_target(target: Vector3) -> void:
	_nav_target = target
	_nav_target_pending = false
	_repath_timer = repath_interval
	nav.target_position = target

## The target the path is (or soon will be) heading to.
func get_nav_target() -> Vector3:
	if _nav_target_pending:
		return _pending_target
	return nav.target_position if nav else global_position

## move_along_nav
## Steers velocity along the current path and faces the way it's going.
## Returns false if there's nowhere left to go.
func move_along_nav(speed: float = move_speed) -> bool:
	if nav == null or nav.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0.0, acceleration * speed)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * speed)
		return false
	var direction := nav.get_next_path_position() - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.000001:
		return true
	direction = direction.normalized()
	face_direction(direction)
	var target_velocity := direction * speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * maxf(speed, 1.0))
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * maxf(speed, 1.0))
	return true

## face_direction
## Turns to face a world direction, yaw only (never tilts, never fails
## on straight up/down directions).
func face_direction(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.000001:
		return
	flat = flat.normalized()
	# look_at() points -Z at the target; flip it for models whose front is +Z.
	var look_point := global_position + (-flat if model_faces_plus_z else flat)
	look_at(look_point, Vector3.UP)

## face_point
## Turns (yaw only) to face a world position.
func face_point(point: Vector3) -> void:
	face_direction(point - global_position)

## Length of the current navigation path (how far the enemy has to walk).
func path_distance() -> float:
	if nav == null:
		return 0.0
	var path := nav.get_current_navigation_path()
	var total := 0.0
	for i in range(path.size() - 1):
		total += path[i].distance_to(path[i + 1])
	return total

## ---------------------------------------------------------------------
## Vision
## ---------------------------------------------------------------------

## can_see_player
## The enemy's own eyes: player in range, inside the vision cone, and not
## behind a wall.
func can_see_player() -> bool:
	if not is_instance_valid(player):
		return false
	var eye := global_position + Vector3.UP * sight_height_offset
	var aim := player.global_position + Vector3.UP * sight_height_offset
	if eye.distance_to(aim) > sight_range:
		return false
	var forward := global_basis.z if model_faces_plus_z else -global_basis.z
	forward.y = 0.0
	var to_player := aim - eye
	to_player.y = 0.0
	if forward.length_squared() > 0.0 and to_player.length_squared() > 0.0:
		if rad_to_deg(forward.angle_to(to_player)) > sight_fov_degrees:
			return false
	var query := PhysicsRayQueryParameters3D.create(eye, aim, 0xFFFFFFFF, [get_rid()])
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == player

## player_can_see_me
## True if any of the given world points is inside the player's view cone
## (half-angle fov_degrees, within max_range) with nothing in between.
## Pass several points (feet ... head) so peeking round a corner counts.
func player_can_see_me(points: Array, fov_degrees: float = 80.0, max_range: float = INF) -> bool:
	if not is_instance_valid(camera):
		return false
	var cam_pos := camera.global_position
	var cam_forward := -camera.global_basis.z
	var cos_fov := cos(deg_to_rad(fov_degrees))
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if player is CollisionObject3D:
		exclude.append(player.get_rid())
	for p in points:
		var to_point: Vector3 = p - cam_pos
		if to_point.length() > max_range:
			continue
		if to_point.normalized().dot(cam_forward) < cos_fov:
			continue
		var query := PhysicsRayQueryParameters3D.create(cam_pos, p, 0xFFFFFFFF, exclude)
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.collider == self:
			return true
	return false

## Points up the enemy's body (fractions of face_height), for player_can_see_me.
func body_points(fractions: Array = [0.17, 0.4, 0.55, 0.8, 0.95]) -> Array:
	var scale_y := global_basis.get_scale().y
	var out := []
	for f in fractions:
		out.append(global_position + Vector3.UP * (face_height * f * scale_y))
	return out

## ---------------------------------------------------------------------
## Catching the player
## ---------------------------------------------------------------------

## kill
## Called by the Player when this enemy touches them. Freezes the player,
## closes any minigame, turns their view to this enemy's face, then runs
## _play_kill().
func kill() -> void:
	if not can_kill_player:
		return
	PlayerManager.deaths += 1
	AudioManager.play_sound(AudioManager.StringStinger)
	PlayerManager.HideDialog()
	PlayerManager.dying = true
	PlayerManager.InAnimation = true
	if PlayerManager.minigameTwo:
		PlayerManager.minigameTwo = false
		UiManager.show_panel("gas_intake", false)
		PlayerManager.Gas_Canister.visible = false
		PlayerManager.gasIntakeSweetSpot.visible = false
	if PlayerManager.minigameThree:
		UiManager.show_panel("hood", false)
	if PlayerManager.player and PlayerManager.player.CAMERA:
		PlayerManager.player.CAMERA.current = true
		PlayerManager.MiniGameModeOff()
		UiManager.set_cursor_visible(false)
		_before_kill_turn()
		await _turn_player_to_face()
	_play_kill()

## Runs just before the player's view turns. Default: nothing.
func _before_kill_turn() -> void:
	pass

## The kill itself. Default: wait, then show the game over screen.
func _play_kill() -> void:
	await get_tree().create_timer(game_over_delay).timeout
	UiManager.show_game_over()

func _turn_player_to_face() -> void:
	var head: Node3D = PlayerManager.player.HEAD
	var cam: Camera3D = PlayerManager.player.CAMERA
	var face_pos := global_position + Vector3.UP * (face_height * global_basis.get_scale().y)
	var to_face := (face_pos - cam.global_position).normalized()
	var h_dist := Vector2(to_face.x, to_face.z).length()
	var target_yaw := HelperManager.find_shortest_y_rotation(head.rotation.y, atan2(-to_face.x, -to_face.z))
	var target_pitch := clampf(atan2(to_face.y, h_dist) - deg_to_rad(kill_look_down_degrees), deg_to_rad(-60), deg_to_rad(60))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(head, "rotation:y", target_yaw, 0.5)
	tween.tween_property(cam, "rotation:x", target_pitch, 0.5)
	await tween.finished
