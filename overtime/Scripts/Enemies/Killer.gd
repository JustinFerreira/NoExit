## No Exit
## Overtime Studios
## Last updated 10/19/26 by Justin Ferreira
## Killer Scipt
## - controls killer movement and actions
## - built on Enemy (see Enemy.gd for the shared movement/vision/kill parts)

extends Enemy


var SPEED: float = 2.0

var follow_distance_enabled: bool = true
var follow_distance: float = 20.0  # Units away from target the killer will stop

@onready var WalkingAnimator: AnimationPlayer = $AnimationPlayer
@onready var StabbingAnimator: AnimationPlayer = $StabbingAnimation

var was_animation_playing: bool = false

var paused_animation_time: float = 1.3

var teleports: Array

# Stalking mode variables
var stalking_mode: bool = false
var stalking_distance: float = 15.0
var original_speed: float
var is_silent: bool = false

# For maintaining distance
var is_stalking: bool = false
var stalk_target_position: Vector3
var stalk_around_player: bool = true

# Timers for stalking behavior
var stalk_direction_change_timer: float = 0.0
var stalk_direction_change_interval: float = 3.0
var current_stalk_angle: float = 0.0

var fadingout: bool = true

# Visual/Audio references
@onready var visibility_timer: Timer = $VisibilityTimer  # You'll need to add this Timer node
@onready var original_material: Material = $Armature/Skeleton3D/M_Killer_LowUV.get_surface_override_material(0)  # Adjust path as needed

func _enemy_ready():
	$FadeAnimation.connect("animation_finished", _on_Fade_animation_finished)
	PlayerManager.Enemy = self
	PlayerManager.no_enemy = false
	WalkingAnimator.speed_scale = 2.0
	$Armature.visible = true
	nav.path_desired_distance = 1.0  # Increase for smoother turns
	nav.target_desired_distance = 1.5  # Distance to consider target reached
	nav.path_max_distance = 3.0  # Max distance to recalculate path
	StabbingAnimator.connect("animation_finished", _on_animation_finished)
	if not PlayerManager.OpeningCutscene:
		teleports = get_tree().get_nodes_in_group("teleport_target")
	if PlayerManager.Loop0:
		find_teleport_target("OutOfBoundsTeleport")


func _enemy_physics(delta: float) -> void:
	if PlayerManager.teleportEnemy && teleports:
		if PlayerManager.Loop0:
			find_teleport_target("NearCarTeleport")
		else:
			find_teleport_target("FarTeleport")
		PlayerManager.teleportEnemy = false

	if not PlayerManager.dying && not stalking_mode:
		WalkingAnimator.play("Scene")

	# Handle stalking mode behavior
	if stalking_mode and PlayerManager.player:
		handle_stalking_behavior(delta)
	else:
		SPEED = 4.0 if PlayerManager.MinigameMode else 2.0
		var stop := follow_distance_enabled and global_position.distance_to(get_nav_target()) <= follow_distance
		if stop:
			move_along_nav(0.0)
		else:
			move_along_nav(SPEED)

	# Calculate path distance to target
	PlayerManager.scaredDistance = path_distance()


## target_position
## Called by the level every frame with the player's position. The path
## itself is only rebuilt a few times a second (see Enemy.set_nav_target).
func target_position(target: Vector3) -> void:
	if stalking_mode:
		face_point(target)
		return
	if position == target:
		return

	if follow_distance_enabled:
		# Calculate a point follow_distance units short of the target
		var direction_to_target = (target - global_transform.origin).normalized()
		var stopped_position = target - direction_to_target * follow_distance
		set_nav_target(stopped_position)
	else:
		set_nav_target(target)

func find_teleport_target(targetname):
	for target in teleports:
		if target.name == targetname:
			self.global_position = target.global_position

# Kept for anything that still calls it - same as Enemy.path_distance().
func calculate_path_distance() -> float:
	return path_distance()

## Turn the killer to face the player before the view turns to it.
func _before_kill_turn() -> void:
	$Armature.visible = false
	$Skeleton3D.visible = true
	$Skeleton3D/killer_UV_unwrapped.visible = true
	face_point(PlayerManager.player.global_position)

## Play the stabbing animation; _on_animation_finished takes it from there.
func _play_kill() -> void:
	StabbingAnimator.play("Stabbing")
	AudioManager.KillerShutUp = true
	AudioManager.play_sound_loop(AudioManager.SkullCrush, "Kill")

func _on_animation_finished(anim_name: String):

	if anim_name == "Stabbing":
		AudioManager.stop_loop("Kill")
		if PlayerManager.OpeningCutscene:
			PlayerManager.OpeningCutscene = false
			get_tree().change_scene_to_file("res://Levels/Office.tscn")
			PlayerManager.Loop0 = true
			return
		elif PlayerManager.Loop0:
			PlayerManager.Loop0 = false

			#EventManager Function fix
			SettingsManager.Loop0Pass = true
			SettingsManager.save_settings()

			get_tree().change_scene_to_file("res://Levels/Office.tscn")
			return
		UiManager.show_game_over()


## New function to handle stalking behavior
func handle_stalking_behavior(delta: float) -> void:
	if not PlayerManager.player:
		return

	var player_pos = PlayerManager.player.global_transform.origin
	var current_pos = global_transform.origin
	var distance_to_player = current_pos.distance_to(player_pos)

	# Update stalking direction periodically
	stalk_direction_change_timer -= delta
	if stalk_direction_change_timer <= 0:
		stalk_direction_change_timer = stalk_direction_change_interval
		# Randomly change angle to move around player
		current_stalk_angle += randf_range(-PI/4, PI/4)

	# Calculate desired position at stalking distance from player
	var direction_to_player = (player_pos - current_pos).normalized()

	# If too close, move away
	if distance_to_player < stalking_distance * 0.8:
		# Move away from player
		var away_direction = -direction_to_player
		var target_pos = current_pos + away_direction * (stalking_distance - distance_to_player) * 2

		# Add some circling movement
		var perpendicular = Vector3(-direction_to_player.z, 0, direction_to_player.x).normalized()
		target_pos += perpendicular * sin(current_stalk_angle) * 3

		set_nav_target(target_pos)

	# If too far, move closer
	elif distance_to_player > stalking_distance * 1.2:
		# Move toward player, but maintain some distance
		var approach_direction = direction_to_player
		var target_pos = player_pos - approach_direction * (stalking_distance * 0.9)

		# Add some circling movement
		var perpendicular = Vector3(-direction_to_player.z, 0, direction_to_player.x).normalized()
		target_pos += perpendicular * cos(current_stalk_angle) * 3

		set_nav_target(target_pos)

	# If at good distance, circle
	else:
		# Circle around player
		var circle_radius = stalking_distance
		var circle_center = player_pos

		# Calculate position on circle
		var circle_x = cos(current_stalk_angle) * circle_radius
		var circle_z = sin(current_stalk_angle) * circle_radius
		var target_pos = circle_center + Vector3(circle_x, 0, circle_z)

		set_nav_target(target_pos)

	# Move towards target position (faces the way it walks)
	move_along_nav(SPEED)

## Add this function to handle entering stalking mode
func enter_stalking_mode(distance: float, teleport: String, silent: bool = true) -> void:
	if stalking_mode:
		return  # Already in stalking mode

	is_silent = silent
	stalking_distance = distance

	HelperManager.fade_fog_density(8,1.5)
	make_invisible(teleport)
	stalking_mode = true


	# Store original speed
	original_speed = SPEED

	# Set speed to 0 while stalking (or very slow if you want them to reposition slowly)
	SPEED = 0

	# Stop the walking animation at the current frame
	if WalkingAnimator.is_playing():
		was_animation_playing = true
		# Store the current playback position (in seconds)
		paused_animation_time = WalkingAnimator.current_animation_position
		WalkingAnimator.stop()

		# OPTIONAL: Set to a specific frame instead of current frame
		# Uncomment the next line and set your desired time (e.g., 0.5 seconds)
		# paused_animation_time = 0.5
	else:
		was_animation_playing = false
		paused_animation_time = 0.0

	# Handle invisibility
	await get_tree().create_timer(0.5).timeout


	# Handle silence
	if is_silent:
		make_silent()

	# Initialize stalking behavior
	current_stalk_angle = randf_range(0, 2 * PI)
	stalk_direction_change_timer = stalk_direction_change_interval

## Add this function to handle exiting stalking mode
func exit_stalking_mode() -> void:
	if not stalking_mode:
		return

	stalking_mode = false

	# Restore original speed
	SPEED = original_speed

	# Restore audio
	if is_silent:
		make_audible()

	# Resume walking animation from where it was paused
	if was_animation_playing:
		WalkingAnimator.play("Scene")
		# Seek to the stored time (ensures it's within valid range)
		WalkingAnimator.seek(paused_animation_time, true)

	is_silent = false

## Make killer invisible
func make_invisible(teleport: String) -> void:
	# Hide the main model
	fadingout = true
	$FadeAnimation.play("FadeKiller")
	await get_tree().create_timer(1).timeout
	HelperManager.fade_fog_density(-8,1.5)
	find_teleport_target(teleport)
	make_visible()

## Make killer visible again
func make_visible() -> void:
	fadingout = false
	$FadeAnimation.play_backwards("FadeKiller")
	$Armature.visible = true
	$Skeleton3D.visible = true

## Make killer silent
func make_silent() -> void:
	# Stop any footstep or idle sounds
	AudioManager.stop_loop("step")  # If killer makes step sounds
	# Add any other killer audio stops here

## Make killer audible again
func make_audible() -> void:
	# Restart sounds if needed
	pass

func _on_Fade_animation_finished(_anim_name: String) -> void:
	if fadingout:
		$Armature.visible = false
		$Skeleton3D.visible = false
		HelperManager.fade_fog_density(-8, 1.5)
