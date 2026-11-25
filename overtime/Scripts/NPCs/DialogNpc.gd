## No Exit
## Overtime Studios
## Last updated 2/24/26 by Justin Ferreira
## DialogNPC Script
## This script is what the Janitor uses for all its
## operations such as wander and talking to player
## Updated with walking and idle animations
## - built on NPC (see NPC.gd): root, play_walk/play_idle, face_direction,
##   say_sequence come from there


extends NPC

## Rotation variables
@export var rotation_speed: float = 2.0  # Adjust this to control turn speed
var is_rotating: bool = false
var target_rotation: float = 0.0

## Wandering variables with navigation
@export var walk_speed: float = 7.5  # Walking speed when approaching player
@export var wander_speed: float = 0.5
@export var wander_range: float = 40.0  # Increased range
@export var min_wander_time: float = 3.0
@export var max_wander_time: float = 50.0  # Increased time
var is_wandering: bool = true
var is_interacting: bool = false
var is_walking_to_player: bool = false  # New state for walking to player
var wander_timer: float = 0.0
var start_position: Vector3
var nav_agent: NavigationAgent3D

## Walking to player parameters
@export var stopping_distance: float = 2.0  # Stop this far from the player

## The player's view during the talk-to-player scene: it follows the NPC
## (aiming at view_aim_height of its height - 0.75 = chest) from "Hey, wait up!"
## until the dialog ends, then eases back to where the player was looking.
@export_range(0.0, 1.0) var view_aim_height: float = 0.75
## How quickly the view keeps up with the NPC (higher = snappier).
@export var view_follow_speed: float = 6.0
var _tracking_view := false
var _saved_yaw := 0.0
var _saved_pitch := 0.0
var _aim_height := -1.0
var has_initial_dialog_played: bool = false  # Track if initial dialog played

## Animation variables
@export var animation_player_walk: AnimationPlayer
@export var animation_player_idle: AnimationPlayer
var last_position: Vector3
var current_animation: String = "idle"  # Track current animation state

@export var normal_walk_speed_scale: float = 1.0   # Normal wander speed
@export var fast_walk_speed_scale: float = 2    # Faster when walking to player

## Mop & bucket - dragged behind the janitor on an invisible "rope" instead of
## turning with him. The first name is the thing being dragged (the bucket);
## the rest stay attached to it (the mop leaning in it, its collision).
@export var dragged_prop_names: Array[String] = ["MMopBucket", "MMop", "StaticBody3D"]
## How fast the bucket swings round to trail behind him while dragged.
@export var drag_turn_speed: float = 4.0
var _drag_props: Array[Node3D] = []
var _drag_offsets: Array[Transform3D] = []   # each prop relative to the bucket
var _drag_length: float = 0.0                 # rope length (janitor -> bucket)
var _drag_yaw_offset: float = 0.0             # bucket yaw relative to "handle toward janitor"

## Path rebuilds are limited to a few a second (walking to the player used to
## rebuild the path every frame).
const REPATH_INTERVAL := 0.25
var _repath_timer := 0.0

## Cleaning up (rogue office - OfficeLife sends him: go_clean): walks to the
## mess at clean_speed, steps up onto it, takes the mop out of his bucket
## (MOP_TAKE_TIME), swishes it round over the mess for CLEAN_TIME seconds
## (the mess shrinks away under it), puts the mop back and goes back to
## wandering. Talking to the player comes first.
@export var clean_speed: float = 2.4
const CLEAN_TIME := 4.5
const MOP_TAKE_TIME := 0.7
## How far in front of him the mop head works (level units), how wide it
## swishes side to side, and how fast.
const MOP_REACH := 1.0
const MOP_SWISH := 0.75
const MOP_SWISH_SPEED := 5.0
var _clean_target: Node3D = null
var _clean_left := 0.0
## "walk" (to the mess), "approach" (the last steps onto it), "take" (mop
## out of the bucket), "mop", "stow" (mop back in)
var _clean_phase := ""
var _clean_t := 0.0
var _stand_at := Vector3.ZERO
var _mop: Node3D
var _mop_in_hand := false
var _mop_from := Transform3D()

const NpcAvoid := preload("res://Scripts/NPCs/NpcAvoid.gd")
const Dance := preload("res://Scripts/NPCs/Dance.gd")
## Dancing (the fire alarm - Dance.gd): everything else waits.
var _dance := {}

func _npc_ready() -> void:
	# The janitor's own inspector slots feed the NPC animation helpers.
	walk_animation_player = animation_player_walk
	idle_animation_player = animation_player_idle
	for p in [animation_player_walk, animation_player_idle]:
		if p and not p.animation_finished.is_connected(_on_npc_animation_finished):
			p.animation_finished.connect(_on_npc_animation_finished)
	play_walk()
	start_position = root.global_transform.origin
	last_position = root.global_transform.origin

	# Get the NavigationAgent3D - adjust the path if needed
	nav_agent = root.get_node("NavigationAgent3D")

	# Set up navigation agent
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5

	PlayerManager.janitor = self
	# ready to stop the player at the elevator button - in rogue mode only on
	# the first round (RogueRun.janitor_talks_this_round)
	PlayerManager.talkToJanitor = RogueRun.active and not RogueRun.janitor_talks_this_round()

	set_new_wander_target()
	root.add_to_group("npc_body")   # (NPCs walk round him - NpcAvoid)
	add_to_group("office_dancer")   # (the fire alarm party - Dance.gd)
	_setup_dragged_props.call_deferred()

func _process(delta: float) -> void:
	if not _dance.is_empty():
		_update_dragged_props(delta)
		return
	if is_rotating:
		# Smoothly rotate toward target rotation
		var current_rotation = root.rotation.y
		root.rotation.y = lerp_angle(current_rotation, target_rotation, rotation_speed * delta)

		# Check if we're close enough to the target rotation
		if abs(angle_difference(current_rotation, target_rotation)) < 0.05:
			root.rotation.y = target_rotation
			is_rotating = false

	# Handle walking to player if in that state
	if is_walking_to_player and PlayerManager.player:
		# Check if we're already close enough before walking
		var player_position = PlayerManager.player.global_transform.origin
		var npc_position = root.global_transform.origin
		var distance_to_player = npc_position.distance_to(player_position)

		if distance_to_player <= stopping_distance:
			is_walking_to_player = false
			rotate_to_player()
			start_multi_dialog_with_camera()
		else:
			walk_to_player(delta)

	# Cleaning up a mess (OfficeLife sent him)
	elif _clean_target != null and not is_interacting and not PlayerManager.multiDialog:
		_clean_step(delta)

	# Handle wandering if not interacting AND not in dialog
	elif is_wandering and not is_interacting and not is_walking_to_player and not PlayerManager.multiDialog:
		wander(delta)

	# Walk while moving, idle otherwise (play_walk/play_idle stop the other
	# player, so the two animations never fight over the skeleton).
	if is_walking_to_player:
		play_walk(fast_walk_speed_scale)
	elif _clean_target != null:
		if _clean_phase in ["walk", "approach"]:
			play_walk(fast_walk_speed_scale * 0.7)
		else:
			play_idle()
	elif is_wandering:
		play_walk(normal_walk_speed_scale)
	else:
		play_idle()
	_repath_timer -= delta

	_update_dragged_props(delta)
	if _tracking_view:
		_follow_with_view(delta)

## _setup_dragged_props
## Detaches the mop & bucket from the janitor's rotation (top_level keeps
## them in world space) and remembers how they sit relative to each other.
func _setup_dragged_props() -> void:
	var npc: Node3D = root
	for prop_name in dragged_prop_names:
		var n = npc.get_node_or_null(NodePath(prop_name))
		if n is Node3D:
			_drag_props.append(n)
	if _drag_props.is_empty():
		return
	# nobody walks into the bucket (NpcAvoid) - he steers round it himself
	_drag_props[0].add_to_group("npc_obstacle")
	_drag_props[0].set_meta("avoid_radius", 0.85)
	_drag_props[0].set_meta("avoid_owner", root)
	for n in _drag_props:
		if n.name == "MMop":
			_mop = n
	var bucket_gt: Transform3D = _drag_props[0].global_transform
	for n in _drag_props:
		_drag_offsets.append(bucket_gt.affine_inverse() * n.global_transform)
	for n in _drag_props:
		var gt := n.global_transform
		n.top_level = true
		n.global_transform = gt
	var to_npc := npc.global_position - bucket_gt.origin
	to_npc.y = 0.0
	_drag_length = to_npc.length()
	_drag_yaw_offset = bucket_gt.basis.get_euler().y - atan2(to_npc.x, to_npc.z)

## _update_dragged_props
## Rope behaviour: the bucket only moves when the janitor walks farther away
## than the rope allows, then it's pulled along behind him and swings so its
## handle points at him. Turning on the spot doesn't move it at all.
func _update_dragged_props(delta: float) -> void:
	if _drag_props.is_empty() or not is_instance_valid(_drag_props[0]):
		return
	var npc: Node3D = root
	var bucket: Node3D = _drag_props[0]
	var gt := bucket.global_transform
	var to_npc := npc.global_position - gt.origin
	to_npc.y = 0.0
	var dist := to_npc.length()
	if dist <= _drag_length or dist < 0.001:
		return   # rope is slack - leave the bucket where it is
	# Pull the bucket to rope length behind him (keep its height).
	var dir := to_npc / dist
	var pos := gt.origin + dir * (dist - _drag_length)
	# Swing toward trailing straight behind.
	var target_yaw := atan2(dir.x, dir.z) + _drag_yaw_offset
	var yaw := lerp_angle(gt.basis.get_euler().y, target_yaw, clampf(drag_turn_speed * delta, 0.0, 1.0))
	var bucket_scale := gt.basis.get_scale()
	gt = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(bucket_scale), pos)
	for i in _drag_props.size():
		if is_instance_valid(_drag_props[i]) and not (_mop_in_hand and _drag_props[i] == _mop):
			_drag_props[i].global_transform = gt * _drag_offsets[i]

## walk_to_player
## Moves NPC toward the player's current position
func walk_to_player(delta: float) -> void:
	if not PlayerManager.player:
		is_walking_to_player = false
		return

	# Update target to player's current position
	var player_position = PlayerManager.player.global_transform.origin
	var npc_position = root.global_transform.origin
	var distance_to_player = npc_position.distance_to(player_position)


	# Stop if we're close enough and start dialog
	if distance_to_player <= stopping_distance * 1.5:  # Allow 50% margin
		is_walking_to_player = false
		# Rotate to face away from player
		rotate_to_player()
		# Start the multi-dialog with camera rotation
		start_multi_dialog_with_camera()
		return

	# Calculate a target position that's exactly stopping_distance away from player
	var direction_to_player = (player_position - npc_position).normalized()
	var target_position = player_position - (direction_to_player * stopping_distance)

	# Set navigation target to the calculated position (a few times a second)
	if _repath_timer <= 0.0 or nav_agent.target_position.distance_to(target_position) > 2.0:
		nav_agent.target_position = target_position
		_repath_timer = REPATH_INTERVAL

	# Check if navigation agent has reached its target or is stuck
	if nav_agent.is_navigation_finished():
		is_walking_to_player = false
		rotate_to_player()
		start_multi_dialog_with_camera()
		return

	# Move toward the calculated position
	if not nav_agent.is_navigation_finished():
		var next_location = nav_agent.get_next_path_position()
		var direction = (next_location - npc_position).normalized()

		# Calculate how far we want to move this frame
		var move_distance = walk_speed * delta
		var new_position = npc_position + (direction * move_distance)

		# Check if new position would be too close to player
		var new_distance_to_player = new_position.distance_to(player_position)


		if new_distance_to_player <= stopping_distance * 1.5:  # Allow 50% margin
			# We're at the stopping distance, stop here
			is_walking_to_player = false
			# Rotate to face away from player
			rotate_to_player()
			# Start the multi-dialog with camera rotation
			start_multi_dialog_with_camera()
		else:
			# Move the NPC (round other NPCs and his bucket)
			direction = _avoid_dir(direction)
			root.global_transform.origin = NpcAvoid.separate(root, npc_position + direction * move_distance)

			# Make the NPC face the direction it's moving
			if direction.length() > 0:
				# FIXED: Changed from + direction to - direction
				# In Godot, look_at() makes the object's -Z axis point toward the target
				# So to face the movement direction, we need to look at a point BEHIND us
				face_direction(direction)

			# Animation will be updated by update_animation_state() in _process

## rotate_to_player
## Rotates NPC to face away from player (180 degrees)
func rotate_to_player() -> void:
	if PlayerManager.player:
		var current_transform = root.global_transform
		var target_transform = current_transform.looking_at(PlayerManager.player.global_position, Vector3.UP)
		target_transform = target_transform.rotated(Vector3.UP, PI)  # Flip 180 degrees

		# Get the target rotation
		target_rotation = target_transform.basis.get_euler().y
		is_rotating = true

## wander
## this function causes npc to move
## to a random place from its starting
## position
func wander(delta: float) -> void:
	# Update timer
	wander_timer -= delta

	# Move using navigation
	if nav_agent.is_navigation_finished():
		# Reached target, set a new one
		set_new_wander_target()
	else:
		# Move toward the target
		var next_location = nav_agent.get_next_path_position()
		var current_location = root.global_transform.origin
		var direction = (next_location - current_location).normalized()

		# Move the NPC (round other NPCs and his bucket)
		direction = _avoid_dir(direction)
		root.global_transform.origin = NpcAvoid.separate(root, root.global_transform.origin + direction * wander_speed * delta)

		# Make the NPC face the direction it's moving
		if direction.length() > 0:
			# FIXED: Changed from - direction to + direction
			# Wait, actually for wander we want the same logic as walk_to_player
			# Using - direction makes the NPC face forward
			face_direction(direction)

		# Animation will be updated by update_animation_state() in _process

	# Check if we need a new target (even if not finished with current path)
	if wander_timer <= 0:
		set_new_wander_target()

## The fire alarm party: stops where he is (mop back in the bucket if he
## was mopping - he goes back to it after) and dances for `seconds`. Not
## while he's stopping the player at the elevator.
func dance(seconds: float) -> void:
	if not _dance.is_empty() or is_walking_to_player or _tracking_view or PlayerManager.multiDialog:
		return
	var sk := root.get_node_or_null("Skeleton3D") as Skeleton3D
	if sk == null or animation_player_walk == null:
		return
	if _clean_target != null and _clean_phase in ["take", "mop", "stow"]:
		_stow_mop_now()
		if is_instance_valid(_clean_target) and _clean_target.has_method("set_dirt"):
			_clean_target.set_dirt(1.0)
		_clean_phase = "walk"
	if animation_player_idle:
		animation_player_idle.stop()
	_dance = Dance.start(sk, animation_player_walk)
	await get_tree().create_timer(seconds).timeout
	if not is_inside_tree():
		return
	Dance.stop(_dance)
	_dance = {}

## Free to go and clean something? (Just wandering - not talking, not
## walking up to the player, not cleaning already.)
func can_clean() -> bool:
	return _clean_target == null and is_wandering and not is_interacting and not is_walking_to_player and not _tracking_view

## Go and clean up `mess` (an OfficeMess). False if he's busy.
func go_clean(mess: Node3D) -> bool:
	if not can_clean() or not is_instance_valid(mess):
		return false
	_clean_target = mess
	_clean_phase = "walk"
	_clean_t = 0.0
	is_wandering = false
	nav_agent.target_position = mess.global_position
	return true

## The way he's heading, bent round other NPCs (NpcAvoid) and round his own
## bucket if it's in front of him.
func _avoid_dir(dir: Vector3) -> Vector3:
	dir.y = 0.0
	if dir.length() < 0.0001:
		return dir
	var out := NpcAvoid.steer(root, root.global_position, dir.normalized())
	if not _drag_props.is_empty() and is_instance_valid(_drag_props[0]):
		var to_b: Vector3 = _drag_props[0].global_position - root.global_position
		to_b.y = 0.0
		if to_b.length() < 2.2 and to_b.length() > 0.001 and out.dot(to_b.normalized()) > 0.3:
			out = (out + out.cross(Vector3.UP).normalized() * 1.2).normalized()
	return out

func _clean_step(delta: float) -> void:
	if not is_instance_valid(_clean_target):
		_stow_mop_now()
		_stop_cleaning()
		return
	var here := root.global_position
	var at := _clean_target.global_position
	var flat_to := Vector3(at.x - here.x, 0.0, at.z - here.z)
	match _clean_phase:
		"walk":
			if flat_to.length() < 3.0 or nav_agent.is_navigation_finished():
				# the last steps: up onto the mess, the mop's reach short of its middle
				var back := -flat_to.normalized() if flat_to.length() > 0.01 else root.global_transform.basis.z
				_stand_at = Vector3(at.x, here.y, at.z) + back * MOP_REACH
				_clean_phase = "approach"
				return
			var next := nav_agent.get_next_path_position()
			var dir := next - here
			dir.y = 0.0
			if dir.length() > 0.001:
				dir = _avoid_dir(dir.normalized())
				root.global_position = NpcAvoid.separate(root, here + dir * clean_speed * delta)
				face_direction(dir)
		"approach":
			var to := Vector3(_stand_at.x - here.x, 0.0, _stand_at.z - here.z)
			var step := clean_speed * 0.6 * delta
			if to.length() <= step:
				root.global_position = Vector3(_stand_at.x, here.y, _stand_at.z)
				face_point(at)
				_start_take()
			else:
				root.global_position += to.normalized() * step
				face_direction(to)
		"take":
			_clean_t += delta
			face_point(at)
			if is_instance_valid(_mop):
				var k := clampf(_clean_t / MOP_TAKE_TIME, 0.0, 1.0)
				_mop.global_transform = _mop_from.interpolate_with(_mop_pose(0.0), ease(k, -1.8))
			if _clean_t >= MOP_TAKE_TIME:
				_clean_phase = "mop"
				_clean_t = 0.0
		"mop":
			_clean_t += delta
			if is_instance_valid(_mop):
				_mop.global_transform = _mop_pose(_clean_t)
			if _clean_target.has_method("set_dirt"):
				_clean_target.set_dirt(1.0 - _clean_t / CLEAN_TIME)
			if _clean_t >= CLEAN_TIME:
				_clean_target.clean()
				_clean_phase = "stow"
				_clean_t = 0.0
				if is_instance_valid(_mop):
					_mop_from = _mop.global_transform
		"stow":
			_clean_t += delta
			if is_instance_valid(_mop):
				var k := clampf(_clean_t / MOP_TAKE_TIME, 0.0, 1.0)
				_mop.global_transform = _mop_from.interpolate_with(_mop_in_bucket(), ease(k, -1.8))
			if _clean_t >= MOP_TAKE_TIME:
				_stow_mop_now()
				_stop_cleaning()

## Reaches into the bucket for the mop.
func _start_take() -> void:
	_clean_phase = "take"
	_clean_t = 0.0
	if is_instance_valid(_mop):
		_mop_in_hand = true
		_mop_from = _mop.global_transform

## Where the mop sits in the bucket right now.
func _mop_in_bucket() -> Transform3D:
	var i := _drag_props.find(_mop)
	if i < 0 or _drag_props.is_empty():
		return _mop.global_transform
	return _drag_props[0].global_transform * _drag_offsets[i]

## The mop back in the bucket, at once (done, or interrupted).
func _stow_mop_now() -> void:
	if _mop_in_hand and is_instance_valid(_mop):
		_mop.global_transform = _mop_in_bucket()
	_mop_in_hand = false

## The mop in his hands at swish time `t`: the handle from just in front
## of his hips down to the head on the floor over the mess, swinging side
## to side (and a little to and fro).
func _mop_pose(t: float) -> Transform3D:
	var fwd := Vector3.FORWARD
	if is_instance_valid(_clean_target):
		fwd = Vector3(_clean_target.global_position.x - root.global_position.x, 0.0, _clean_target.global_position.z - root.global_position.z)
	fwd = fwd.normalized() if fwd.length() > 0.001 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP).normalized()
	var grip := _grip_point() + fwd * 0.45
	var head := root.global_position + fwd * MOP_REACH + right * sin(t * MOP_SWISH_SPEED) * MOP_SWISH + fwd * cos(t * MOP_SWISH_SPEED * 0.5) * 0.25
	head.y = 0.02
	var y := (grip - head).normalized()
	var x := (right - y * right.dot(y)).normalized()
	var z := x.cross(y).normalized()
	var sc := _mop.global_transform.basis.get_scale().x if is_instance_valid(_mop) else 1.0
	return Transform3D(Basis(x, y, z).scaled(Vector3.ONE * sc), head)

## About where his hands are (hips height, from the skeleton).
func _grip_point() -> Vector3:
	var sk := root.get_node_or_null("Skeleton3D") as Skeleton3D
	if sk:
		var i := sk.find_bone("mixamorig_Hips")
		if i >= 0:
			return sk.global_transform * sk.get_bone_global_pose(i).origin
	return root.global_position + Vector3.UP * 1.7

func _stop_cleaning() -> void:
	_clean_target = null
	_clean_phase = ""
	_clean_left = 0.0
	is_wandering = true
	set_new_wander_target()

## set_new_wander_target
## picks a random position for the npc
## to wander to
func set_new_wander_target() -> void:
	play_walk(normal_walk_speed_scale)
	# Generate a random position within wander range
	var random_offset = Vector3(
		randf_range(-wander_range, wander_range),
		0,
		randf_range(-wander_range, wander_range)
	)
	var target_position = start_position + random_offset

	# Set the navigation target
	nav_agent.target_position = target_position

	# Set a random timer for the next target change
	wander_timer = randf_range(min_wander_time, max_wander_time)

## start_dialog
## Starts the dialog sequence after reaching the player (for direct interactions)
func start_dialog() -> void:
	set_outline_blocked(true)   # no outline on him while he talks
	# Calculate target rotation (looking away from player)
	rotate_to_player()

	# Start the dialog
	PlayerManager.talkToJanitor = true
	await say_sequence(EventManager.janitor_text_array)

	# Resume wandering after interaction
	is_interacting = false
	set_outline_blocked(false)
	is_wandering = true
	set_new_wander_target()

func _on_interacted(_body: Variant) -> void:
	# Stop wandering and start interaction
	is_wandering = false
	is_interacting = true
	start_dialog()

## wait_for_dialog_completion
## Stops player from wandering while in dialog
func wait_for_dialog_completion():
	# Wait until the multi-dialog is finished
	while PlayerManager.multiDialog:
		await get_tree().create_timer(0.1).timeout

## angle_difference
## Helper function to calculate angle difference
func angle_difference(from: float, to: float) -> float:
	return wrapf(to - from, -PI, PI)

## Walks up to the player, turns them to face it and runs its dialog.
func talkToPlayer():
	# Start walking to player
	set_outline_blocked(true)   # no outline on him during the scene
	mark_used()                 # nor the close-by one after it (hover still flashes)
	AudioManager.cancel_loop_sfx()
	# drop any cleaning - the mess waits for someone else (or later)
	if is_instance_valid(_clean_target) and "claimed" in _clean_target:
		_clean_target.claimed = false
		if _clean_target.has_method("set_dirt"):
			_clean_target.set_dirt(1.0)
	_stow_mop_now()
	_clean_target = null
	_clean_phase = ""
	is_walking_to_player = true
	is_wandering = false

	# Play initial dialog to freeze player
	if not has_initial_dialog_played:
		PlayerManager.talkToJanitor = true
		PlayerManager.InAnimation = true
		PlayerManager.CharacterDialog(EventManager.janitor_didnt_speak_text)
		has_initial_dialog_played = true

		# the player's view follows the NPC until its dialog is over
		_start_view_tracking()

## Turns the player's view to keep up with the NPC every frame until
## _end_view_tracking() (remembers where they were looking first).
func _start_view_tracking() -> void:
	var player = PlayerManager.player
	if not is_instance_valid(player):
		return
	_saved_yaw = player.get_look_yaw()
	_saved_pitch = player.CAMERA.rotation.x
	_tracking_view = true

## The point on the NPC the view aims at (view_aim_height of its height).
func _view_aim_point() -> Vector3:
	if _aim_height < 0.0:
		var box := AABB()
		var first := true
		for m in root.find_children("*", "MeshInstance3D", true, false):
			if not m.is_visible_in_tree():
				continue
			var a: AABB = m.global_transform * m.get_aabb()
			box = a if first else box.merge(a)
			first = false
		_aim_height = (box.size.y if not first else 1.5) * view_aim_height
	return root.global_position + Vector3.UP * _aim_height

func _follow_with_view(delta: float) -> void:
	var player = PlayerManager.player
	if not is_instance_valid(player):
		_tracking_view = false
		return
	var cam: Camera3D = player.CAMERA
	var to: Vector3 = _view_aim_point() - cam.global_position
	var target_yaw := atan2(-to.x, -to.z)
	var target_pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var t := 1.0 - exp(-view_follow_speed * delta)
	player.set_look_yaw(lerp_angle(player.get_look_yaw(), target_yaw, t))
	cam.rotation.x = lerp_angle(cam.rotation.x, target_pitch, t)

## Stops following the NPC and eases the view back to where the player was
## looking before the scene (e.g. the elevator button).
func _end_view_tracking() -> void:
	_tracking_view = false
	var player = PlayerManager.player
	if not is_instance_valid(player):
		return
	var from_yaw: float = player.get_look_yaw()
	var to_yaw := HelperManager.find_shortest_y_rotation(from_yaw, _saved_yaw)
	var cam: Camera3D = player.CAMERA
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(y: float): if is_instance_valid(player): player.set_look_yaw(y), from_yaw, to_yaw, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cam, "rotation:x", _saved_pitch, 0.6).set_trans(Tween.TRANS_SINE)
	await tw.finished

## Reached the player: face them, run the dialog with the view on the NPC,
## then hand control back.
func start_multi_dialog_with_camera() -> void:
	is_interacting = true
	is_wandering = false
	play_idle()
	PlayerManager.talkToJanitor = true
	await say_sequence(EventManager.janitor_text_array)
	PlayerManager.multiDialog = true      # keep the player still while the view eases back
	await _end_view_tracking()
	PlayerManager.multiDialog = false
	PlayerManager.InAnimation = false
	is_interacting = false
	set_outline_blocked(false)
	is_wandering = true
	set_new_wander_target()
