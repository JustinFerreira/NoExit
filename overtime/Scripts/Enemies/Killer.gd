## No Exit
## Overtime Studios
## Killer
## - The main enemy. Chases the player (stopping follow_distance short until
##   it's close), teleports to scare spots, can switch to "stalking" (fades
##   out, reappears and circles the player), hunts players it saw hide, and
##   kills with a stab or a lift-and-crush (kill_style).
## - Story levels: the original killer (separate stab model, Skeleton3D).
##   Real-size levels: Killer_RealSize, whose stab, drag-out and crush all
##   play on its walking model (stab_with_walk_model).
## - built on Enemy (see Enemy.gd for the shared movement/vision/kill parts)

extends Enemy

## Current walking speed (4 during minigames, 0 while stalking).
var SPEED: float = 2.0

## Hang back follow_distance from the player (along the path) instead of walking right up.
var follow_distance_enabled: bool = true
## How far back along the path from the player it stops (levels can change this).
var follow_distance: float = 20.0

@onready var WalkingAnimator: AnimationPlayer = $AnimationPlayer
@onready var StabbingAnimator: AnimationPlayer = $StabbingAnimation

## The kill plays StabbingAnimation on the walking model (Armature) instead of
## swapping to the separate stab model (Skeleton3D). For killers whose stab
## animation was made for the walking model's skeleton (Killer_RealSize).
@export var stab_with_walk_model: bool = false

## How this killer kills. CRUSH (lift the player by the head and crush it)
## needs the "LiftCrush" animation, so only killers with stab_with_walk_model
## can do it - others always stab. RANDOM picks one each kill.
enum KillStyle { STAB, CRUSH, RANDOM }
@export var kill_style: KillStyle = KillStyle.STAB
## Distance it steps to for the crush (close enough to grab the head).
@export var crush_distance: float = 0.95
## Where the player's eyes end up while held, in the killer's space
## (forward, up) - between its claws, above its face.
@export var crush_hold_point: Vector2 = Vector2(0.9, 2.05)

var _kill_choice: KillStyle = KillStyle.STAB
var _crush_overlay: CanvasLayer

## Places it can jump to (group "teleport_target"), found by name.
var teleports: Array

## Stalking (see enter_stalking_mode)
var stalking_mode: bool = false
var stalking_distance: float = 15.0
var original_speed: float
var is_silent: bool = false
var stalk_direction_change_timer: float = 0.0
var stalk_direction_change_interval: float = 3.0
var current_stalk_angle: float = 0.0
## walk animation paused while stalking, resumed from here afterwards
var was_animation_playing: bool = false
var paused_animation_time: float = 1.3
## true while FadeAnimation is fading it out (false while fading back in)
var fadingout: bool = true

func _enemy_ready():
	$FadeAnimation.animation_finished.connect(_on_Fade_animation_finished)
	PlayerManager.Enemy = self
	PlayerManager.no_enemy = false
	WalkingAnimator.speed_scale = 2.0
	$Armature.visible = true
	nav.path_desired_distance = 0.75  # how close to a path corner before heading for the next: the navmesh floats ~0.5 above the floor, so this is ~0.5 sideways (bigger cuts corners - and walks into ramp sides)
	nav.target_desired_distance = 1.5  # Distance to consider target reached
	nav.path_max_distance = 3.0  # Max distance to recalculate path
	StabbingAnimator.animation_finished.connect(_on_animation_finished)
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
		_animate_walk()

	# Handle stalking mode behavior
	if stalking_mode and PlayerManager.player:
		handle_stalking_behavior(delta)
	elif behavior == Behavior.HUNT or _lost_player():
		_hunt(delta)
	else:
		SPEED = (4.0 if PlayerManager.MinigameMode else 2.0) * RogueRun.killer_speed_scale() * speed_mult
		# Hangs back follow_distance from the player, measured along the path
		# (so it works across floors). No hanging back while hunting or
		# searching for a hiding player.
		# Nor while they're caught in a bear trap - that's its chance.
		var trapped: bool = is_instance_valid(PlayerManager.player) and "trapped" in PlayerManager.player and PlayerManager.player.trapped
		# walk right up to it while it's hanging back and it lunges (see
		# lunge_distance) - it doesn't stop until it has them or they get away
		if _lunging and not _lunge_goes_on():
			_lunging = false
		if not _lunging and _hanging_back and _player_walked_up():
			_lunging = true
		if _lunging:
			_hanging_back = false
			move_along_nav(LUNGE_SPEED * RogueRun.killer_speed_scale())
			return
		# a player who stands still too long (rogue mode) gets closed in on
		var closing_in := RogueRun.active and RogueRun.player_still_long()
		var stop := follow_distance_enabled and not PlayerManager.hiding and not trapped and not closing_in and path_distance() <= follow_distance
		_hanging_back = stop
		if stop:
			move_along_nav(0.0)
		else:
			move_along_nav(SPEED)



## True while it stands follow_distance back from the player (see _enemy_physics).
var _hanging_back := false

## ---------------------------------------------------------------------
## How it hunts (rogue mode sets these each round - RogueRun._setup_enemies)
##   STALK - knows where the player is and trails them (as it always did);
##           if they hide without it seeing, it has lost them and wanders
##   HUNT  - wanders the garage, drawn to the car and the parts
##           (RogueRun.points_of_interest); locks on only once it SEES the
##           player, chases them, and gives up LOSE_SIGHT_TIME after losing
##           sight of them (checking where it last saw them first)
## ---------------------------------------------------------------------
enum Behavior { STALK, HUNT }
var behavior: Behavior = Behavior.STALK
## Times its normal speed (rogue rounds vary it).
var speed_mult := 1.0
const WANDER_SPEED := 1.4
const CHASE_SPEED := 3.6
const LOSE_SIGHT_TIME := 6.0
var _locked_on := false
var _unseen_for := 0.0
var _last_seen := Vector3.INF
var _wander_to := Vector3.INF
var _wander_for := 0.0

## Something made a noise (EnemyNoise.make): a hunter that isn't chasing anyone
## goes to see what it was - or, if it was the player and close, it's onto
## them. A stalker that's lost the player goes to look too.
const HEAR_LOCK_ON := 15.0
func hear(at: Vector3, by_player: bool) -> void:
	if killing or holding or is_hunting_hidden_player():
		return
	if behavior == Behavior.HUNT and _locked_on:
		return
	if behavior == Behavior.STALK and not _lost_player():
		return
	if by_player and behavior == Behavior.HUNT and not PlayerManager.hiding and global_position.distance_to(at) < HEAR_LOCK_ON:
		_locked_on = true
		_unseen_for = 0.0
		_last_seen = at
		return
	_wander_to = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, at)
	_wander_for = 0.0

## A stalker has lost the player: they hid and it didn't see where.
func _lost_player() -> bool:
	return behavior == Behavior.STALK and PlayerManager.hiding and not is_hunting_hidden_player()

func _hunt(delta: float) -> void:
	var scale_now := RogueRun.killer_speed_scale() * speed_mult
	# it saw them hide: straight to the spot to drag them out
	if is_hunting_hidden_player():
		set_nav_target(hunting_spot.grab_position())
		move_along_nav(CHASE_SPEED * scale_now)
		return
	var sees := behavior == Behavior.HUNT and is_instance_valid(player) and not PlayerManager.hiding and can_see_player()
	if sees:
		_locked_on = true
		_unseen_for = 0.0
		_last_seen = player.global_position
	elif _locked_on:
		_unseen_for += delta
		if _unseen_for > LOSE_SIGHT_TIME or PlayerManager.hiding:
			_locked_on = false
			_wander_to = _last_seen   # check where it last saw them
			_wander_for = 0.0
	if _locked_on:
		set_nav_target(player.global_position if sees else _last_seen)
		move_along_nav(CHASE_SPEED * scale_now)
		return
	# wandering: on to the next place once there (or stuck a while)
	_wander_for += delta
	var arrived := _wander_to != Vector3.INF and Vector2(global_position.x - _wander_to.x, global_position.z - _wander_to.z).length() < 2.5
	if _wander_to == Vector3.INF or arrived or _wander_for > 25.0:
		_wander_to = RogueRun.next_wander_point(self)
		_wander_for = 0.0
	set_nav_target(_wander_to)
	move_along_nav(WANDER_SPEED * speed_mult)

## While it hangs back, walking up closer than this to it (metres, a clear
## line between them) makes it lunge: it rushes them and kills them. It gives
## up only if they get twice as far away again or hide.
@export var lunge_distance: float = 7.0
const LUNGE_SPEED := 9.0
var _lunging := false

func _player_walked_up() -> bool:
	if not is_instance_valid(player) or PlayerManager.hiding or PlayerManager.dying or PlayerManager.cutscene:
		return false
	if not RogueRun.kill_allowed():
		return false   # rogue mode's early rounds: it looms instead (Enemy.HOLD_OFF)
	if global_position.distance_to(player.global_position) > lunge_distance:
		return false
	var eye := global_position + Vector3.UP * sight_height_offset
	var aim: Vector3 = player.global_position + Vector3.UP * sight_height_offset
	var q := PhysicsRayQueryParameters3D.create(eye, aim, 0xFFFFFFFF, [get_rid()])
	q.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.collider == player

func _lunge_goes_on() -> bool:
	return is_instance_valid(player) and not PlayerManager.hiding and not PlayerManager.cutscene \
		and global_position.distance_to(player.global_position) <= lunge_distance * 2.0

## Walk cycle matched to how fast it's really moving (and its size - a
## scaled-up killer takes longer strides), so its feet don't slide. Standing
## still it doesn't walk in place: hanging back at follow_distance it waits
## with its hands steepled under its chin, tapping its fingertips together
## ("WaitClasped" - the evil "excellent"), otherwise it idles.
func _animate_walk() -> void:
	if not stab_with_walk_model:
		WalkingAnimator.play("Scene")   # story killer: as it always was
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.3:
		# hanging back: waits for the player, fingertips steepled, tapping
		var still := "WaitClasped" if _hanging_back and WalkingAnimator.has_animation("WaitClasped") else "Idle"
		if WalkingAnimator.has_animation(still):
			WalkingAnimator.speed_scale = 1.0
			WalkingAnimator.play(still, 0.5)
			return
	# 2.0 = the walk's playback speed at 2 m/s for the real-size model
	WalkingAnimator.speed_scale = maxf(speed, 0.6) / global_basis.get_scale().y
	WalkingAnimator.play("Scene", 0.3)

## target_position
## Called by the level every frame with the player's position. The path
## itself is only rebuilt a few times a second (see Enemy.set_nav_target).
func target_position(target: Vector3) -> void:
	if stalking_mode:
		face_point(target)
		return
	# a hunter finds the player with its own eyes, and a stalker that lost
	# them wanders - neither uses the level's feed (see _hunt)
	if behavior == Behavior.HUNT or _lost_player():
		return
	# A hiding player: go for the spot it saw them use, or search where it lost them.
	if PlayerManager.hiding:
		set_nav_target(chase_target(target))
		return
	# Always path to the player itself; _enemy_physics stops it
	# follow_distance short along that path.
	set_nav_target(target)

## Jumps to the teleport target with this name (group "teleport_target").
func find_teleport_target(targetname: String) -> void:
	for target in teleports:
		if target.name == targetname:
			global_position = target.global_position

## Turn the killer to face the player before the view turns to it.
func _before_kill_turn() -> void:
	_kill_choice = KillStyle.STAB
	var can_crush := stab_with_walk_model and StabbingAnimator.has_animation("LiftCrush")
	if can_crush and (kill_style == KillStyle.CRUSH or (kill_style == KillStyle.RANDOM and randf() < 0.5)):
		_kill_choice = KillStyle.CRUSH
	# somewhere too cramped for the stab (a narrow ramp, a corner): it would
	# be played right against the camera, so grab them instead
	if _kill_choice == KillStyle.STAB and can_crush and kill_distance > 0.0:
		var stab_room := kill_distance * global_basis.get_scale().y
		if _kill_side(stab_room).room < stab_room + 0.4:
			_kill_choice = KillStyle.CRUSH
	if stab_with_walk_model:
		# the stab is retargeted onto the walking model: keep it, stop walking
		WalkingAnimator.stop()
	else:
		$Armature.visible = false
		$Skeleton3D.visible = true
		$Skeleton3D/killer_UV_unwrapped.visible = true
	face_point(PlayerManager.player.global_position)

## Dragging a hidden player out: reach in, grab, yank (if this killer has the
## hand-keyed "DragOut" for its walking model), sped to fit `time`.
func play_drag_out(time: float) -> void:
	super(time)
	if stab_with_walk_model and StabbingAnimator.has_animation("DragOut"):
		WalkingAnimator.stop()
		var length := StabbingAnimator.get_animation("DragOut").length
		StabbingAnimator.play("DragOut", 0.15, length / maxf(time, 0.05))

## The crush happens closer than the stab.
func _current_kill_distance() -> float:
	return crush_distance if _kill_choice == KillStyle.CRUSH else kill_distance

## Plays the chosen kill (stab, or the crush); _on_animation_finished takes
## it from there.
func _play_kill() -> void:
	if _kill_choice == KillStyle.CRUSH:
		_play_crush()
		return
	# blend out of the drag-out's last pose rather than snapping
	StabbingAnimator.play("Stabbing", 0.25 if StabbingAnimator.current_animation == "DragOut" or StabbingAnimator.assigned_animation == "DragOut" else -1.0)
	AudioManager.KillerShutUp = true
	AudioManager.play_sound_loop(AudioManager.SkullCrush, "Kill")

## When a kill animation ends: the opening cutscene and Loop 0 move on to the
## office; otherwise it's game over.
func _on_animation_finished(anim_name: String):
	if anim_name == "Stabbing" or anim_name == "LiftCrush":
		AudioManager.stop_loop("Kill")
		if is_instance_valid(_crush_overlay):
			_crush_overlay.queue_free()
		if PlayerManager.OpeningCutscene:
			PlayerManager.OpeningCutscene = false
			get_tree().change_scene_to_file("res://Levels/Office.tscn")
			PlayerManager.Loop0 = true
			return
		elif PlayerManager.Loop0:
			PlayerManager.Loop0 = false
			SettingsManager.Loop0Pass = true   # remembered so Loop 0 isn't replayed
			SettingsManager.save_settings()

			get_tree().change_scene_to_file("res://Levels/Office.tscn")
			return
		UiManager.show_game_over()


## ---------------------------------------------------------------------
## Crush kill: grabs the player's head, lifts them off their feet, squeezes
## (view shakes harder, red creeps in, sight narrows), then a final crunch
## and black. The killer side is the "LiftCrush" animation; this moves the
## player's view along with it.
## ---------------------------------------------------------------------
const CRUSH_GRAB := 0.35      # claws reach the head
const CRUSH_LIFTED := 0.9     # fully off the ground
const CRUSH_SQUEEZE := 1.0    # squeezing starts
const CRUSH_CRUNCH := 1.8     # the crunch: black

func _play_crush() -> void:
	StabbingAnimator.play("LiftCrush", 0.2)
	AudioManager.KillerShutUp = true
	var p = PlayerManager.player
	var cam: Camera3D = p.CAMERA
	var head: Node3D = p.HEAD
	if "COLLISIONSHAPE3D" in p and p.COLLISIONSHAPE3D:
		p.COLLISIONSHAPE3D.disabled = true   # it's held inside the killer's reach
	# red / black overlay
	_crush_overlay = CanvasLayer.new()
	_crush_overlay.layer = 50
	var red := ColorRect.new(); red.color = Color(0.45, 0.0, 0.0, 0.0)
	var black := ColorRect.new(); black.color = Color(0, 0, 0, 0)
	for r in [red, black]:
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_crush_overlay.add_child(r)
	add_child(_crush_overlay)
	var s := {
		"eye_off": cam.global_position - p.global_position,
		"start_eye": cam.global_position,
		"pitch": cam.rotation.x, "yaw": head.rotation.y, "fov": cam.fov,
		"crunched": false, "looping": false,
	}
	var length := StabbingAnimator.get_animation("LiftCrush").length
	var tw := create_tween()
	tw.tween_method(_crush_step.bind(s, red, black), 0.0, length, length)

func _crush_step(t: float, s: Dictionary, red: ColorRect, black: ColorRect) -> void:
	var p = PlayerManager.player
	if not is_instance_valid(p):
		return
	var cam: Camera3D = p.CAMERA
	var head: Node3D = p.HEAD
	var fwd := global_basis.z if model_faces_plus_z else -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var sc := global_basis.get_scale().y
	var lift := smoothstep(CRUSH_GRAB, CRUSH_LIFTED, t)
	var squeeze := smoothstep(CRUSH_SQUEEZE, CRUSH_CRUNCH, t)
	# pulled up between the claws, legs dangling (a slow sway)
	var held := global_position + fwd * crush_hold_point.x * sc + Vector3.UP * crush_hold_point.y * sc
	var eye: Vector3 = s.start_eye.lerp(held, lift)
	eye += Vector3.UP * sin(t * 7.0) * 0.015 * lift
	p.global_position = eye - s.eye_off
	# look down at the killer's face
	var face := global_position + Vector3.UP * face_height * sc + fwd * 0.1
	var to_face := face - eye
	var look_pitch := atan2(to_face.y, Vector2(to_face.x, to_face.z).length())
	# shaking: a little while lifted, violent while squeezed
	var amp := deg_to_rad(1.2) * lift + deg_to_rad(6.0) * squeeze
	cam.rotation.x = lerpf(s.pitch, look_pitch, lift) + sin(t * 61.0 + 1.0) * amp * 0.5
	cam.rotation.z = sin(t * 47.0) * amp * 0.7
	head.rotation.y = s.yaw + sin(t * 53.0 + 2.0) * amp * 0.35
	cam.fov = lerpf(s.fov, s.fov - 8.0, squeeze)
	red.color.a = 0.5 * squeeze + 0.12 * squeeze * (0.5 + 0.5 * sin(t * 22.0))
	if t >= CRUSH_SQUEEZE and not s.looping:
		s.looping = true
		AudioManager.play_sound_loop(AudioManager.SkullCrush, "Kill")
	if t >= CRUSH_CRUNCH and not s.crunched:
		s.crunched = true
		AudioManager.play_sound(AudioManager.StringStinger)
		cam.rotation.z = deg_to_rad(14.0)
	if s.crunched:
		black.color.a = 1.0
		cam.fov = s.fov

## Stalking: keeps around stalking_distance from the player - backs off when
## too close, closes in when too far, otherwise circles them.
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

## Starts stalking: fades out, reappears at the named teleport, stops walking
## (SPEED 0) and keeps `distance` from the player. silent = mute its steps.
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

	else:
		was_animation_playing = false
		paused_animation_time = 0.0

	await get_tree().create_timer(0.5).timeout


	# Handle silence
	if is_silent:
		make_silent()

	# Initialize stalking behavior
	current_stalk_angle = randf_range(0, 2 * PI)
	stalk_direction_change_timer = stalk_direction_change_interval

## Ends stalking: back to normal speed and the walk animation.
func exit_stalking_mode() -> void:
	if not stalking_mode:
		return

	stalking_mode = false

	# Restore original speed
	SPEED = original_speed


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
	AudioManager.stop_loop("step")

## Fully faded out: hide the model.
func _on_Fade_animation_finished(_anim_name: String) -> void:
	if fadingout:
		$Armature.visible = false
		$Skeleton3D.visible = false
		HelperManager.fade_fog_density(-8, 1.5)

## The kills are framed around face_height, so use that (not the head bone).
func _face_offset() -> float:
	return face_height * global_basis.get_scale().y

## Held still by a cutscene: stand idle, not walking in place (no fear
## meanwhile - PlayerManager.ProcessScared ignores enemies in a cutscene).
func _cutscene_pose() -> void:
	if stab_with_walk_model and WalkingAnimator.has_animation("Idle"):
		WalkingAnimator.speed_scale = 1.0
		WalkingAnimator.play("Idle", 0.3)
