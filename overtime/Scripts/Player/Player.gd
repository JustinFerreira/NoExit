## No Exit
## Overtime Studios
## Player
## - The first-person player: walking/sprinting with stamina, crouch, lean
##   and look-back, head bob and footsteps, mouse look, the interact ray
##   (with aim assist), equipped-item keys, the breathing/heartbeat sounds
##   that follow the killer's distance, and dying when an enemy touches it.
## - Kill sequences call stand_up_for_kill() / standing_eye_position() so
##   every death is seen from the same height.

extends CharacterBody3D

var speed: float
const WALK_SPEED: float = 5.0
const SPRINT_SPEED: float = 7.5
var SENSITIVITY: float = PlayerManager.Sensitivity
## Mouse look is ignored until this frame (see _ready).
var _look_ready_frame: int = 0
## Gravity on (turned off while the car animation moves the player).
var gravity: bool = true


var is_sprinting: bool = false

##bob variables
const BOB_FREQ: float = 4.0 # How often you bob
const BOB_AMP: float = 0.058 # How high and low you bob (world units; scaled with the player's height)
var t_bob: float = 0.0 # Determines how far along the signwave we are for bobbing
## How out of breath from running (0-1), see _update_stamina.
var _exertion: float = 0.0
## Seconds off the floor (footsteps carry on through a brief hop).
var _air_time: float = 0.0

##Step variables
var was_moving: bool = false
var is_moving: bool = false

## ---------------------------------------------------------------------
## Terrain Step Assist
## ---------------------------------------------------------------------
## Hand-placed MeshInstances rarely line up pixel-perfect, so the floor
## can have tiny seams/lips between pieces. These give the player some
## leeway instead of getting stuck on them.

## How tall a ledge/seam can be before the player just steps up over it
## instead of getting blocked by it. Meant for small mismatches between
## floor pieces, not real stairs - keep this small. Set to 0 to disable.
@export var step_height: float = 0.36

## Godot's built-in floor snap distance, exposed here for quick tuning -
## how big a floor height DROP (a pothole/small gap) the player sticks
## to the ground through instead of catching air or stuttering.
@export var floor_snap_amount: float = 0.3

## Godot's built-in floor_max_angle, exposed here for quick tuning - the
## steepest surface still counted as "floor" (walkable) instead of
## "wall". Slightly-tilted seams get treated as a shallow slope instead
## of a stop.
@export var floor_max_angle_degrees: float = 50.0

## ---------------------------------------------------------------------
## Stamina
## ---------------------------------------------------------------------
## Sprinting (actually running, not just holding/toggling sprint while
## standing still) drains stamina. After regen_delay seconds of not
## running it refills. Hitting 0 makes the player fatigued: no sprinting,
## slower than walking, and no regen until the fatigue wears off.
@export_group("Stamina")
@export var max_stamina: float = 100.0
## Stamina lost per second while running.
@export var stamina_drain_per_second: float = 10.0
## Stamina gained per second once regen kicks in.
@export var stamina_regen_per_second: float = 15.0
## Seconds of not running before stamina starts to refill.
@export var stamina_regen_delay: float = 2.5
## How long the player is fatigued after running out.
@export var fatigue_duration: float = 10.0
## Movement speed while fatigued (walking is WALK_SPEED).
@export var fatigue_speed: float = 3.0

## ---------------------------------------------------------------------
## Crouch / Lean / Look Back
## ---------------------------------------------------------------------
## C crouches, Q / E lean left / right, hold V to look behind you.
## Looking back only turns the camera - you keep walking the way your body
## faces.
@export_group("Crouch, Lean, Look Back")
## Movement speed while crouched (no sprinting while crouched).
@export var crouch_speed: float = 2.5
## Height while crouched, as a fraction of standing height (eyes and body).
@export_range(0.3, 0.95) var crouch_height_factor: float = 0.6
## Tap C to crouch / stand instead of holding it.
@export var crouch_toggle: bool = false
## How far the view moves sideways when leaning (meters).
@export var lean_distance: float = 0.53
## How much the view tilts when leaning (degrees).
@export var lean_angle_degrees: float = 12.0
## Allow leaning while sprinting.
@export var lean_while_sprinting: bool = false
## How fast crouch and lean ease in/out (higher = snappier).
@export var move_transition_speed: float = 8.0
## How far (degrees) behind the BODY the look-back turns to - always the
## same spot over the shoulder, no matter where you were looking. People
## can't spin their head a full 180 like an owl.
@export_range(0.0, 180.0) var look_back_degrees: float = 135.0
## Up/down angle the look-back settles on (0 = level, negative = down).
@export var look_back_pitch_degrees: float = -5.0
## How fast the look-back turn happens (higher = snappier).
@export var look_back_speed: float = 4.5
@export_group("")

var is_crouching: bool = false
## 0 = standing, 1 = fully crouched / leaned / looking back (eased).
var _crouch_amount: float = 0.0
var _lean_amount: float = 0.0   # -1 = left, 1 = right
var _look_back_amount: float = 0.0
## Which way the body faces (where you walk / last walked); look-back is
## measured from this, not from where the head is looking.
var _body_forward := Vector3.ZERO
## Shoulder for the current look-back: 1 = left, -1 = right (picked on press).
var _look_back_side := -1.0
var _look_back_held := false
var _back_pitch_offset := 0.0   # pitch look-back has added on top of the mouse pitch
var _crouch_toggled: bool = false
## Standing setup, captured in _ready().
var _stand_head_y: float
var _stand_shape_transform: Transform3D
var _shape_bottom_local: float = 0.0
var _shape_top_local: float = 0.0

var stamina: float = 100.0
## Seconds since the player last ran (drives the regen delay).
var _time_since_sprint: float = 0.0
## Seconds of fatigue left. > 0 means fatigued.
var fatigue_time_left: float = 0.0
## Set by the Show Stamina Bar setting.
var show_stamina_bar: bool = true
## Set by the Tilt View When Leaning setting.
var lean_tilt_enabled: bool = true

var breathing_volume: float = -80  # Adjust as needed
var heartbeat_volume: float = -20  # Adjust as needed

#settings

var TbobON: bool = true
var Incar: bool = false
var trapped: bool = false

var is_exiting: bool = false

const WireHand = preload("res://Scripts/Minigames/WireHand.gd")
@onready var HEAD: Node3D = $Head
@onready var CAMERA: Camera3D = $Head/Camera3D
@onready var FLASHLIGHT: SpotLight3D = $Head/Camera3D/FlashLight
@onready var FREEROAMHEAD: Node3D = $FreeRoamHead
@onready var FREEROAMCAMERA:Camera3D  = $FreeRoamHead/Camera3D
@onready var INTERACT_RAY: RayCast3D = $Head/Camera3D/InteractRay
@onready var AREA3D: Area3D = $Player
@onready var COLLISIONSHAPE3D: CollisionShape3D = $CollisionShape3D
@onready var CURSOR: Control = $CenterContainer/Cursor
## Looked up once - these were found by path every physics frame.
@onready var _crosshair: CanvasItem = $CenterContainer/Cursor/Crosshair
@onready var _hand: CanvasItem = $CenterContainer/Cursor/Hand
@onready var _arms: Node3D = $arms
@onready var _body: Node3D = $body
@onready var DIALOG: Control = $DialogControl
@onready var GAMEOVER: CanvasLayer  = $GameOverScreen

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $"Head/Camera3D/InteractRay"

## Grabbing Objects Variables
var grabbed_object: Node3D  = null
var mouse: Vector2 = Vector2()
var original_mouse_pos: Vector2 = Vector2()  # Store initial mouse position
var original_object_pos: Vector3 = Vector3()  # Store initial object position
var _grab_plane_y := 0.0          # height a dragged object slides at
var _grab_offset := Vector3.ZERO  # object - the point under the cursor

## Outline help
var last_collider: CollisionObject3D = null

var pre_free_roam_head_transform: Transform3D
var pre_free_roam_camera_transform: Transform3D


## Function that starts as soon as Player in in the scene
func _ready() -> void:
	# New level: UiManager starts fresh and shows this player's crosshair.
	UiManager.on_player_ready(self)
	# the aim ray also sees the "Clickable" layer (7): hiding spots under the
	# cars live there, so they can be clicked without anyone walking into them
	INTERACT_RAY.collision_mask |= 1 << 6
	SettingsManager.PlayerShader = $ps1_graphics
	if SettingsManager.settings.video.shader:
		$ps1_graphics.visible = true
	else:
		$ps1_graphics.visible = false
	floor_snap_length = floor_snap_amount
	floor_max_angle = deg_to_rad(floor_max_angle_degrees)
	stamina = max_stamina
	_stand_head_y = head.position.y
	_stand_shape_transform = COLLISIONSHAPE3D.transform
	if COLLISIONSHAPE3D.shape:
		var shape_box := COLLISIONSHAPE3D.shape.get_debug_mesh().get_aabb()
		_shape_bottom_local = shape_box.position.y
		_shape_top_local = shape_box.end.y
	# If we got here through GameState.change_level(), put the player on
	# their spawn marker and restore what carried over. Right away, not
	# deferred: the level's first frame is drawn before deferred calls run,
	# which flashed one frame of the level from the scene's default spot.
	GameState.place_player(self)
	# FOV, crouch toggle, text speed, etc. from the settings menu.
	SettingsManager.apply_player_settings(self)

	PlayerManager.player = self
	CAMERA.current = true
	CameraManager.FPCamera = CAMERA
	FLASHLIGHT.visible = false
	PlayerManager.equipped_item_changed.connect(_on_equipped_item_changed)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# mouse movement that piled up while the level was loading would land
	# all at once and jerk the view - ignore it for the first few frames
	_look_ready_frame = Engine.get_process_frames() + 5

	if not PlayerManager.Loop0 and not PlayerManager.OpeningCutscene:
			AudioManager.play_sound_loop(AudioManager.breathing, "breathing", 1.0, breathing_volume)
			AudioManager.play_sound_loop(AudioManager.heartbeat, "heartbeat", 1.0 , heartbeat_volume)

# Any input that is detected automatically calls this function

func _process(_delta: float) -> void:
	if grabbed_object:
		# Update mouse position to current position
		mouse = get_viewport().get_mouse_position()
		# battery minigame: the wire slides into the hand's grip (its middle in
		# the palm) instead of hanging where it was caught
		if PlayerManager.minigameThree:
			_grab_offset = _grab_offset.lerp(Vector3.ZERO, clampf(_delta * 20.0, 0.0, 1.0))
		grabbed_object.global_position = get_grab_position()
	# battery minigame: the 3D hand in place of the mouse pointer
	WireHand.update(self)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("override"):
		if PlayerManager.DevMode:
				$DevPauseMenu.pause()
	if PlayerManager.InAnimation and  not PlayerManager.multiDialog || PlayerManager.dying:
		return
	if event.is_action_pressed("Keysound"):
		if PlayerManager.has_car_fob() && PlayerManager.EquippedItem == "Car Keys":
			PlayerManager.KeyFobSound()
		elif PlayerManager.Office && PlayerManager.EquippedItem == "Car Keys":
			PlayerManager.Hint("Can only use this in the parking garage")
		elif PlayerManager.EquippedItem == PlayerManager.STAMINA_CHARGE and not PlayerManager.MinigameMode and not PlayerManager.hiding:
			PlayerManager.use_stamina_charge()
	if event.is_action_pressed("scrollUp"):
		PlayerManager.SwitchEquippedItem(true)
	if event.is_action_pressed("scrollDown"):
		PlayerManager.SwitchEquippedItem(false)
	if event is InputEventMouseMotion:
		if Engine.get_process_frames() < _look_ready_frame:
			return
		if PlayerManager.cutscene:
			return   # the cutscene is pointing the view
		if PlayerManager.multiDialog || PlayerManager.examining:
			return
		if PlayerManager.MinigameMode == true:
			if PlayerManager.minigameThree == true:
				mouse = event.position
			return
		if Incar == false:
			head.rotate_y(-event.relative.x * SENSITIVITY)
			camera.rotation.x -= event.relative.y * SENSITIVITY * (-1.0 if PlayerManager.InvertY else 1.0)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))
		elif Incar == true:
			head.rotate_y(-event.relative.x * SENSITIVITY)
			# same direction as on foot (it was flipped, so the car view was inverted)
			camera.rotation.x -= event.relative.y * SENSITIVITY * (-1.0 if PlayerManager.InvertY else 1.0)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))
			head.rotation.y = clamp(head.rotation.y, deg_to_rad(-90), deg_to_rad(90))
	if event is InputEventMouseButton:
		if PlayerManager.minigameTwo == true:
				PlayerManager.actioning = true
	if event.is_action_released("Interact"):
		PlayerManager.actioning = false
		if DIALOG.is_typing && PlayerManager.finishedDialogAnimation == true:
			DIALOG.skip_typewriter_effect()
			return
		if not DIALOG.is_typing and not PlayerManager.multiDialog and PlayerManager.examining:
			PlayerManager.EndFocus()
			PlayerManager.HideDialog()
			PlayerManager.dialoging = false
			PlayerManager.finishedDialogAnimation = false
			PlayerManager.startMultiDialog = true
		elif PlayerManager.startMultiDialog == false && PlayerManager.multiDialog:
			PlayerManager.NextDialog()
		elif PlayerManager.startMultiDialog == true && PlayerManager.multiDialog:
			PlayerManager.startMultiDialog = false
		elif not DIALOG.is_typing and not PlayerManager.multiDialog and PlayerManager.finishedDialogAnimation and DIALOG.visible:
			PlayerManager.HideDialog()
			PlayerManager.dialoging = false
			PlayerManager.finishedDialogAnimation = false
			PlayerManager.startMultiDialog = true
	if event.is_action_pressed("Interact"):
		if not DIALOG.is_typing and PlayerManager.firstdialog:
				PlayerManager.player.DIALOG.get_node("MouseClicking").visible = false
				PlayerManager.player.DIALOG.get_node("MouseClicking").get_node("MouseClickingAnimationPlayer").stop()
		if grabbed_object == null && PlayerManager.minigameThree == true && event.is_action_released("Interact") == false && event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				get_mouse_world_pos(mouse)
		elif grabbed_object != null && PlayerManager.minigameThree == true && event.is_action_released("Interact") == false && event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				release_grabbed_object()
	if event.is_action_pressed("ui_cancel"):
		if PlayerManager.minigameOne:
			PlayerManager.minigameOne = false
			UiManager.show_panel("hotwire", false)
			AnimationManager.CarInteractRay.enabled = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			PlayerManager.MiniGameModeOff()
		elif PlayerManager.minigameTwo:
			AudioManager.stop_loop("glug")
			PlayerManager.player.CAMERA.current = true
			PlayerManager.minigameTwo = false
			UiManager.show_panel("gas_intake", false)
			PlayerManager.Gas_Canister.visible = false
			PlayerManager.gasIntakeSweetSpot.visible = false
			PlayerManager.MiniGameModeOff()
		elif PlayerManager.minigameThree:
			AnimationManager.HoodCollision.call_deferred("set_disabled", false)
			AnimationManager.CarCollision.call_deferred("set_disabled", false)
			PlayerManager.minigameThree = false
			grabbed_object = null
			CAMERA.current = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			UiManager.show_panel("hood", false)
			AnimationManager.HideResetZones()
			AnimationManager.PositiveBatteryFlash.visible = false
			AnimationManager.NegativeBatteryFlash.visible = false
			if not PlayerManager.PositiveConnected:
				AnimationManager.WirePositiveFlash.visible = true
			if not PlayerManager.NegativeConnected:
				AnimationManager.WireNegativeFlash.visible = true
			PlayerManager.HideDialog()
			PlayerManager. MiniGameModeOff()
		else:
			if PlayerManager.DevMode:
				$DevPauseMenu.pause()
			else:
				$SimplifiedPauseMenu.pause()
	# Only on the first press - holding Tab sends repeat events, which used to
	# delete and rebuild every inventory label many times a second.
	if event.is_action_pressed("Inventory") and not event.is_echo():
		UiManager.show_inventory(true)
	if event.is_action_released("Inventory"):
		UiManager.show_inventory(false)


## Premade Godot Functiuon for movement given to CharacterBody 3D
## has some added flare for this game
func _physics_process(delta: float) -> void:
	if is_exiting or not is_inside_tree():
		return
	if PlayerManager.FreeRoam:
		handle_free_roam_movement(delta)
		return

	if not PlayerManager.Loop0:
		PlayerManager.ProcessScared()   # once per frame, used by both below
	apply_breathing_effects()
	apply_heartbeat_effects()

	if PlayerManager.InAnimation || PlayerManager.MinigameMode || PlayerManager.multiDialog || PlayerManager.dying || PlayerManager.examining || PlayerManager.hiding:
		_set_footsteps(false)
		_update_stamina(delta, false)
		_update_body_moves(delta, false)
		return

	SENSITIVITY = PlayerManager.Sensitivity

	if not is_on_floor():
		if gravity == true:
			velocity += get_gravity() * delta

	# Single consolidated tree check before ANY node access
	if is_exiting or not is_inside_tree() or not is_instance_valid(interact_ray) or not interact_ray.is_inside_tree():
		return

	_handle_interact_ray()

	# Crouch / lean / look back (not while in the car or trapped)
	_update_body_moves(delta, not (Incar or trapped))

	# Handle Sprint
	if Incar == true or trapped == true:
		speed = 0
		is_sprinting = false
	else:
		handle_sprint_input()
		# No sprinting while fatigued, out of stamina or crouched.
		if is_sprinting and (is_fatigued() or stamina <= 0.0 or is_crouching):
			_cancel_sprint()
		apply_sprint_speed()

	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var running := false
	if direction and PlayerManager.firstdialog == false:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		running = is_sprinting
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	_update_stamina(delta, running)

	is_moving = Input.is_action_pressed("forward") or Input.is_action_pressed("backward") or \
			   Input.is_action_pressed("left") or Input.is_action_pressed("right")

	# footsteps while actually walking on the ground (checked every frame, so
	# anything else stopping the loop - an elevator, a minigame, a step off a
	# kerb - can't leave them silent; a moment in the air doesn't cut them)
	_air_time = 0.0 if is_on_floor() else _air_time + delta
	_set_footsteps(Vector2(velocity.x, velocity.z).length() > 0.6 and _air_time < 0.2 and not PlayerManager.firstdialog)

	was_moving = is_moving

	t_bob += delta * velocity.length() * float(is_on_floor())
	if TbobON && PlayerManager.HeadBob:
		camera.transform.origin = _headbob(t_bob)

	if velocity.length() > 0.1:
		var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
		if horizontal_velocity.length() > 0.1:
			var forward = -head.global_transform.basis.z
			var movement_direction = horizontal_velocity.normalized()
			var angle = forward.signed_angle_to(-movement_direction, Vector3.UP)
			_arms.rotation.y = angle
			_body.rotation.y = angle

	_update_body_forward()
	_apply_step_assist(delta)

	if not is_exiting and is_inside_tree() and get_world_3d() != null:
		move_and_slide()


## Checks whether this frame's horizontal movement is about to get
## blocked by something shorter than step_height and, if so, hops the
## player straight up over it before move_and_slide() runs - turns a
## small mesh seam into a smooth step instead of a wall. Does nothing if
## the player isn't grounded, isn't moving, or the "wall" ahead is
## actually tall (a real wall) or has something above it (a low ceiling).
func _apply_step_assist(delta: float) -> void:
	if step_height <= 0.0 or not is_on_floor():
		return

	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length() < 0.001:
		return

	# Nothing in the way at ground level - no step needed.
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, motion, hit):
		return
	# A slope we can walk up (a ramp) isn't a step: move_and_slide climbs it
	# smoothly. Hopping up it here made walking up ramps jitter.
	for i in hit.get_collision_count():
		if hit.get_normal(i).angle_to(Vector3.UP) <= floor_max_angle + 0.01:
			return

	# Is there room for the player at the same spot, just step_height
	# higher? If something's blocking up there too (a low ceiling), this
	# isn't a steppable lip.
	var raised_transform := global_transform
	raised_transform.origin.y += step_height
	if test_move(raised_transform, Vector3.ZERO):
		return

	# And can we actually move forward once raised? If that's still
	# blocked, whatever we hit is taller than step_height - leave it as
	# a real wall.
	if test_move(raised_transform, motion):
		return

	global_transform.origin.y += step_height


## Aim assist for interacting: when the crosshair is just off an object,
## extra rays this many degrees around it still find it (0 = exact aim only).
@export var interact_assist_degrees: float = 4.0
## Rings of assist rays, as fractions of interact_assist_degrees (inner first,
## so the object nearest the crosshair wins).
const _ASSIST_RINGS: Array[float] = [0.5, 1.0]
const _ASSIST_RAYS_PER_RING: int = 8
const _INTERACT_MAX_DISTANCE: float = 5.0

func _can_use(collider: Object, point: Vector3) -> bool:
	return is_instance_valid(collider) and collider is Interactable and collider.is_interactable \
		and interact_ray.global_position.distance_to(point) <= _INTERACT_MAX_DISTANCE

## What the player is aiming at: the exact crosshair hit if it's usable,
## otherwise the nearest usable object hit by the assist rays around it.
## Same reach as the interact ray; walls still block (the rays stop at them).
func _find_interact_target() -> Object:
	if interact_ray.is_colliding():
		var c := interact_ray.get_collider()
		if _can_use(c, interact_ray.get_collision_point()):
			return c
	# then things that claim the aim by what's seen (the flat tire)
	var claimed := _aim_claim()
	if claimed:
		return claimed
	if interact_assist_degrees <= 0.0:
		return null
	var from := interact_ray.global_position
	var reach := interact_ray.global_basis * interact_ray.target_position
	var length := reach.length()
	if length <= 0.0:
		return null
	var forward := reach / length
	var right := interact_ray.global_basis.x.normalized()
	var up := forward.cross(right).normalized()
	var space := get_world_3d().direct_space_state
	for ring in _ASSIST_RINGS:
		var angle := deg_to_rad(interact_assist_degrees * ring)
		for k in _ASSIST_RAYS_PER_RING:
			var around := TAU * k / _ASSIST_RAYS_PER_RING
			var dir := (forward * cos(angle) + (right * cos(around) + up * sin(around)) * sin(angle)).normalized()
			var query := PhysicsRayQueryParameters3D.create(from, from + dir * length, interact_ray.collision_mask, [get_rid()])
			var hit := space.intersect_ray(query)
			if hit and _can_use(hit.collider, hit.position):
				return hit.collider
	return null

## Things that pick themselves by what the player sees rather than by their
## collision (group "aim_claim", method claims_aim - e.g. the flat tire, tucked
## under the car's fender where the car's own collision covers it).
func _aim_claim() -> Object:
	var claims := get_tree().get_nodes_in_group("aim_claim")
	if claims.is_empty():
		return null
	var from := interact_ray.global_position
	var reach := interact_ray.global_basis * interact_ray.target_position
	if reach.length() <= 0.0:
		return null
	var first: Object = interact_ray.get_collider() if interact_ray.is_colliding() else null
	var first_dist := from.distance_to(interact_ray.get_collision_point()) if first else INF
	for c in claims:
		if is_instance_valid(c) and c is Interactable and c.is_interactable \
				and c.claims_aim(from, reach.normalized(), minf(reach.length(), _INTERACT_MAX_DISTANCE), first, first_dist):
			return c
	return null

func _handle_interact_ray() -> void:
	if not is_instance_valid(interact_ray) or not interact_ray.is_inside_tree() or not interact_ray.enabled:
		UiManager.set_cursor_hover(false)
		if last_collider != null:
			last_collider.hide_outline()
			last_collider = null
		return

	var collider = _find_interact_target()

	if collider != null:
		UiManager.set_cursor_hover(true)
		if last_collider != null && last_collider != collider:
			last_collider.hide_outline()
		if collider.show_outline():
			last_collider = collider
		if Input.is_action_just_pressed("Interact") and not UiManager.click_blocked():
			collider.interact(owner)
	else:
		UiManager.set_cursor_hover(false)
		if last_collider != null:
			last_collider.hide_outline()
			last_collider = null

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	#pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy"):
		## Stop any sounds that could be playing
		AudioManager.cancel_loop_sfx()
		body.kill()


## The heartbeat and breathing loops play all the time (silent when calm) -
## put them back if something stopped every loop (cancel_loop_sfx).
func _ensure_fear_loops() -> void:
	if PlayerManager.dying or PlayerManager.OpeningCutscene:
		return
	if not AudioManager.looping_players.has("breathing"):
		AudioManager.play_sound_loop(AudioManager.breathing, "breathing", 1.0, -80.0)
	if not AudioManager.looping_players.has("heartbeat"):
		AudioManager.play_sound_loop(AudioManager.heartbeat, "heartbeat", 1.0, -80.0)

## Starts / stops the footstep loop (only if it isn't already in that state).
func _set_footsteps(on: bool) -> void:
	var playing := AudioManager.looping_players.has("step")
	if on and not playing:
		AudioManager.play_sound_loop(AudioManager.step, "step", 1, -24, 0.2)   # its speed is set each frame (apply_sprint_speed)
	elif not on and playing:
		AudioManager.stop_loop("step")

## Breathing loop speed/volume from fear (the nearest enemy) or from
## running (_exertion), whichever is stronger (not in Loop 0).
func apply_breathing_effects():
	if PlayerManager.Loop0:
		return
	_ensure_fear_loops()
	# faster (not higher) and a little louder with fear - or from running,
	# whichever is stronger (PlayerManager.ProcessScared already ran)
	var tempo: float = maxf(PlayerManager.breathTempo, lerpf(1.0, 1.9, _exertion))
	var vol: float = PlayerManager.breathVolume
	if _exertion > 0.03:
		vol = maxf(vol, lerpf(-26.0, -11.0, _exertion))
	AudioManager.set_loop_tempo("breathing", tempo)
	AudioManager.set_loop_volume("breathing", vol)

## Heartbeat loop speed/volume from fear - the nearest enemy (not in Loop 0).
func apply_heartbeat_effects():
	if PlayerManager.Loop0:
		return
	# faster (not higher) and only a little louder as fear rises
	AudioManager.set_loop_tempo("heartbeat", PlayerManager.scaredPitch)
	AudioManager.set_loop_volume("heartbeat", PlayerManager.scaredVolume)

## Sprint key: hold-to-sprint or toggle, depending on the setting.
func handle_sprint_input():
	if PlayerManager.Hold_Shift:
		is_sprinting = Input.is_action_pressed("sprint")
	else:
		# Toggle-sprint mode
		if Input.is_action_just_pressed("sprint"):
			# Toggle sprint state when key is pressed
			is_sprinting = !is_sprinting
			PlayerManager.sprint_engaged = is_sprinting

## Picks this frame's move speed: sprint, walk, crouch or fatigued.
func apply_sprint_speed():
	if is_fatigued():
		speed = fatigue_speed
		AudioManager.set_loop_pitch("step", 1.5)
	elif is_sprinting:
		speed = SPRINT_SPEED
		AudioManager.set_loop_pitch("step", 4)
	else:
		speed = WALK_SPEED
		AudioManager.set_loop_pitch("step", 2)
	if is_crouching:
		speed = minf(speed, crouch_speed)


## ---------------------------------------------------------------------
## Crouch / Lean / Look Back
## ---------------------------------------------------------------------

## allowed = false (cutscenes, examining, in the car...) eases lean and
## look-back back to normal and keeps the crouch as it is.
func _update_body_moves(delta: float, allowed: bool) -> void:
	# In the car (or anything else that swaps in its own head/camera) none of
	# this applies - and it mustn't move that borrowed head around.
	if head != HEAD or camera != CAMERA:
		return
	var step := delta * move_transition_speed

	# Crouch
	if allowed:
		if crouch_toggle:
			if Input.is_action_just_pressed("crouch"):
				_crouch_toggled = not _crouch_toggled
			is_crouching = _crouch_toggled
		else:
			is_crouching = Input.is_action_pressed("crouch")
		# Something overhead? Stay down instead of standing into it.
		if not is_crouching and _crouch_amount > 0.0 and not _can_stand():
			is_crouching = true
	_crouch_amount = move_toward(_crouch_amount, 1.0 if is_crouching else 0.0, step)
	_apply_crouch(smoothstep(0.0, 1.0, _crouch_amount))

	# Lean
	var back_held := allowed and Input.is_action_pressed("look_back")
	var lean_target := 0.0
	# While looking back Q/E pick the shoulder instead of leaning.
	if allowed and not back_held and (lean_while_sprinting or not is_sprinting):
		lean_target = Input.get_axis("lean_left", "lean_right")
	_lean_amount = move_toward(_lean_amount, lean_target, step)

	# Look back - camera only, so movement keeps the body's direction.
	if back_held and not _look_back_held:
		_look_back_side = _pick_look_back_side()
	_look_back_held = back_held
	var back_target := 1.0 if back_held else 0.0
	_look_back_amount = move_toward(_look_back_amount, back_target, delta * look_back_speed)

	_apply_view_offsets()

func _apply_crouch(t: float) -> void:
	var height := lerpf(1.0, crouch_height_factor, t)
	head.position.y = _stand_head_y * height
	# Shrink the collision from the top, keeping the feet where they are.
	var stand := _stand_shape_transform
	var stand_scale_y := stand.basis.y.length()
	var bottom := stand.origin.y + stand_scale_y * _shape_bottom_local
	var new_scale_y := stand_scale_y * height
	var xform := stand
	xform.basis.y = stand.basis.y * height
	xform.origin.y = bottom - new_scale_y * _shape_bottom_local
	COLLISIONSHAPE3D.transform = xform

## Enemy.kill() calls this so every death is seen from the same height:
## drops look-back at once, then eases out of crouch and lean over `time`.
func stand_up_for_kill(time: float = 0.5) -> void:
	is_crouching = false
	_crouch_toggled = false
	_look_back_held = false
	_look_back_amount = 0.0
	camera.rotation.y = 0.0
	camera.rotation.x -= _back_pitch_offset
	_back_pitch_offset = 0.0
	var from_crouch := _crouch_amount
	var from_lean := _lean_amount
	var from_head := Vector2(head.position.x, head.position.z)
	var from_tilt := camera.rotation.z
	var tw := create_tween()
	tw.tween_method(func(t: float):
		_crouch_amount = from_crouch * (1.0 - t)
		_lean_amount = from_lean * (1.0 - t)
		_apply_crouch(smoothstep(0.0, 1.0, _crouch_amount))
		head.position.x = from_head.x * (1.0 - t)
		head.position.z = from_head.y * (1.0 - t)
		camera.rotation.z = from_tilt * (1.0 - t),
		0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Where the camera will be once fully stood up (no crouch, no lean).
func standing_eye_position() -> Vector3:
	return global_transform * Vector3(0.0, _stand_head_y + camera.position.y, 0.0)

## Is there room above to stand back up from the current crouch?
func _can_stand() -> bool:
	var stand_scale_y := _stand_shape_transform.basis.y.length()
	var current_scale_y := COLLISIONSHAPE3D.transform.basis.y.length()
	var missing := (stand_scale_y - current_scale_y) * (_shape_top_local - _shape_bottom_local)
	if missing <= 0.001:
		return true
	missing *= global_basis.get_scale().y
	return not test_move(global_transform, Vector3.UP * missing)

func _apply_view_offsets() -> void:
	var lean_t := _lean_amount
	var lean_eased := signf(lean_t) * smoothstep(0.0, 1.0, absf(lean_t))

	# Slide the head sideways, but stop short of walls.
	var side_world := lean_distance * lean_eased
	if absf(side_world) > 0.001:
		var right := head.global_basis.x.normalized()
		var from := global_transform * Vector3(0.0, head.position.y, 0.0)
		var query := PhysicsRayQueryParameters3D.create(from, from + right * (side_world + signf(side_world) * 0.2))
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit:
			var room := maxf(from.distance_to(hit.position) - 0.2, 0.0)
			side_world = signf(side_world) * minf(absf(side_world), room)
	var body_scale := global_basis.get_scale().x
	var right_in_body := (head.basis.x.normalized()) * (side_world / body_scale)
	head.position.x = right_in_body.x
	head.position.z = right_in_body.z

	# Tilt into the lean; turn the camera around to look back.
	camera.rotation.z = (-deg_to_rad(lean_angle_degrees) * lean_eased) if lean_tilt_enabled else 0.0
	_apply_look_back(smoothstep(0.0, 1.0, _look_back_amount))

## Keeps track of which way the body faces: it turns to where you walk
## (forward or sideways, not backward), and when the head turns more than
## 90 degrees away while standing, the body turns to follow like a person.
func _update_body_forward() -> void:
	var head_f := -head.global_basis.z
	head_f.y = 0.0
	head_f = head_f.normalized()
	var move := Vector3(velocity.x, 0.0, velocity.z)
	if move.length() > 0.1 and move.normalized().dot(head_f) > -0.2:
		_body_forward = move.normalized()
	elif _body_forward.length_squared() < 0.0001:
		_body_forward = head_f
	var a := _body_forward.signed_angle_to(head_f, Vector3.UP)
	var max_turn := deg_to_rad(90.0)
	if absf(a) > max_turn:
		_body_forward = _body_forward.rotated(Vector3.UP, a - signf(a) * max_turn)

## The body's facing on the ground (falls back to the head's if it hasn't
## walked yet).
func _body_dir() -> Vector3:
	if _body_forward.length_squared() > 0.0001:
		return _body_forward
	var f := -head.global_basis.z
	f.y = 0.0
	return f.normalized()

static func _yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)

## Which shoulder to look back over (1 = left, -1 = right), decided when V
## is pressed: Q/E if held; otherwise whichever way the head is already
## turned from the body; otherwise the same side as last time.
func _pick_look_back_side() -> float:
	var lean := Input.get_axis("lean_left", "lean_right")
	if absf(lean) > 0.1:
		return -signf(lean)
	var head_f := -head.global_basis.z
	head_f.y = 0.0
	var turn := _body_dir().cross(head_f.normalized()).y   # > 0 = head turned left
	if absf(turn) > sin(deg_to_rad(10.0)):
		return signf(turn)
	return _look_back_side

## Swings the camera (not the head, so walking is unaffected) toward a fixed
## spot behind the body, levelling the up/down look on the way. t = 0..1.
func _apply_look_back(t: float) -> void:
	# Yaw: from where the head looks to body + side * look_back_degrees.
	var head_f := -head.global_basis.z
	head_f.y = 0.0
	var target_yaw := _yaw_of(_body_dir()) + _look_back_side * deg_to_rad(look_back_degrees)
	var offset := wrapf(target_yaw - _yaw_of(head_f.normalized()), -PI, PI)
	# Turn over the chosen shoulder, not the long way round the other one.
	if absf(offset) > PI * 0.5 and signf(offset) != _look_back_side:
		offset += _look_back_side * TAU
	camera.rotation.y = offset * t
	# Pitch: blend the mouse pitch toward look_back_pitch_degrees. The mouse
	# keeps writing to camera.rotation.x, so take our last offset back out first.
	var base := camera.rotation.x - _back_pitch_offset
	_back_pitch_offset = (deg_to_rad(look_back_pitch_degrees) - base) * t
	camera.rotation.x = base + _back_pitch_offset

## ---------------------------------------------------------------------
## Carrying the player between levels (see GameState.change_level)
## ---------------------------------------------------------------------

## Everything about the player that should survive a level change.
## Inventory already lives in PlayerManager, so it isn't here.
func get_carry_state() -> Dictionary:
	return {
		"stamina": stamina,
		"fatigue_time_left": fatigue_time_left,
		"time_since_sprint": _time_since_sprint,
		"is_sprinting": is_sprinting,
		"look_pitch": camera.rotation.x,
		# where head bob had the camera (a new level's player starts at the
		# scene default until its first bob - a visible drop otherwise)
		"cam_origin": camera.transform.origin,
		"t_bob": t_bob,
	}

## Puts back what get_carry_state() saved, after a level change.
func apply_carry_state(state: Dictionary) -> void:
	stamina = state.get("stamina", stamina)
	fatigue_time_left = state.get("fatigue_time_left", fatigue_time_left)
	_time_since_sprint = state.get("time_since_sprint", _time_since_sprint)
	is_sprinting = state.get("is_sprinting", is_sprinting)
	camera.rotation.x = state.get("look_pitch", camera.rotation.x)
	camera.transform.origin = state.get("cam_origin", camera.transform.origin)
	t_bob = state.get("t_bob", t_bob)

## get_look_yaw / set_look_yaw
## Which way the player is facing, in world space (radians around Y).
## Turning is done on the Head, so the body's own rotation is accounted for.
func get_look_yaw() -> float:
	return head.global_basis.orthonormalized().get_euler().y

## Turns the view to face a world yaw (radians around Y).
func set_look_yaw(world_yaw: float) -> void:
	var body_yaw := global_basis.orthonormalized().get_euler().y
	head.rotation.y = wrapf(world_yaw - body_yaw, -PI, PI)

## ---------------------------------------------------------------------
## Stamina
## ---------------------------------------------------------------------

## True while worn out from running out of stamina (no sprinting, slow).
func is_fatigued() -> bool:
	return fatigue_time_left > 0.0

## Turns sprint off, including toggle-sprint, so it doesn't snap back on.
func _cancel_sprint() -> void:
	is_sprinting = false
	PlayerManager.sprint_engaged = false

## running = the player is actually moving with sprint on this frame.
func _update_stamina(delta: float, running: bool) -> void:
	# out of breath: builds up over a few seconds of sprinting, settles slowly
	# after (and stays up while worn out) - see apply_breathing_effects
	var puffed := running or is_fatigued()
	_exertion = move_toward(_exertion, 1.0 if puffed else 0.0, delta * (0.25 if puffed else 0.12))
	if running:
		_time_since_sprint = 0.0
		stamina = maxf(stamina - stamina_drain_per_second * delta, 0.0)
		if stamina <= 0.0:
			# Ran dry: fatigued, no sprint, no regen until it wears off.
			fatigue_time_left = fatigue_duration
			_cancel_sprint()
	else:
		_time_since_sprint += delta

	if is_fatigued():
		fatigue_time_left = maxf(fatigue_time_left - delta, 0.0)
		if not is_fatigued():
			# Fatigue lasted longer than the regen delay - start refilling now.
			_time_since_sprint = stamina_regen_delay
	elif _time_since_sprint >= stamina_regen_delay:
		stamina = minf(stamina + stamina_regen_per_second * delta, max_stamina)

	_update_stamina_bar(delta)

## The bar itself is drawn by UiManager (top-left HUD); this just reports.
func _update_stamina_bar(_delta: float) -> void:
	var ratio := stamina / maxf(max_stamina, 0.001)
	if is_fatigued():
		# While fatigued the red bar shows the fatigue left, draining to 0.
		ratio = fatigue_time_left / maxf(fatigue_duration, 0.001)
	UiManager.update_stamina(ratio, is_fatigued(), stamina < max_stamina or is_fatigued(), show_stamina_bar)

## The world point under the mouse (for dragging objects), or null.
func get_mouse_world_pos(mouse_pos: Vector2):
	var space = get_world_3d().direct_space_state
	var _camera = get_viewport().get_camera_3d()
	var start = _camera.project_ray_origin(mouse_pos)
	var end = start + _camera.project_ray_normal(mouse_pos) * 10.0

	var params = PhysicsRayQueryParameters3D.create(start, end)
	var result = space.intersect_ray(params)
	var target: Node3D = result.collider if result and result.collider and result.collider.is_in_group("grabbable") else null
	# the battery minigame's hand: touching a wire at all is enough to take it
	if target == null and PlayerManager.minigameThree:
		target = WireHand.wire_touched(_camera, mouse_pos)

	if target:
		grabbed_object = target
		original_object_pos = grabbed_object.global_transform.origin
		# a spark snaps it back to where it was picked up from (its saved start
		# spot went stale when the round moved the car)
		if "original_position" in grabbed_object:
			grabbed_object.original_position = original_object_pos
		original_mouse_pos = mouse_pos  # Store the initial mouse position
		# it slides on the level plane at its own height; remember how far the
		# point under the cursor is from it, so that point stays under the cursor
		_grab_plane_y = original_object_pos.y
		var on_plane: Variant = _mouse_on_plane(mouse_pos, _grab_plane_y)
		_grab_offset = original_object_pos - on_plane if on_plane != null else Vector3.ZERO

		if PlayerManager.PositiveWire == grabbed_object:
			AnimationManager.WirePositiveFlash.visible = false
			AnimationManager.WireNegativeFlash.visible = false
			AnimationManager.PositiveBatteryFlash.visible = true
			AnimationManager.RevealResetZones(PlayerManager.PositiveWire)
		if PlayerManager.NegativeWire == grabbed_object:
			AnimationManager.WireNegativeFlash.visible = false
			AnimationManager.WirePositiveFlash.visible = false
			AnimationManager.NegativeBatteryFlash.visible = true
			AnimationManager.RevealResetZones(PlayerManager.NegativeWire)

		# Optional: Make the object kinematic while grabbed to prevent physics interference
		if grabbed_object is RigidBody3D:
			grabbed_object.freeze = true

## Where a grabbed object is held: right under the cursor. It slides on a
## level plane at the height it was picked up at, and the point that was
## clicked stays exactly under the mouse (it used to move by the mouse's
## travel times a fixed amount, which drifted away from the cursor).
func get_grab_position() -> Vector3:
	if not grabbed_object:
		return Vector3.ZERO
	var on_plane: Variant = _mouse_on_plane(mouse, _grab_plane_y)
	if on_plane == null:
		return grabbed_object.global_position
	return on_plane + _grab_offset

## Where the mouse ray meets the level plane at height `y`, or null.
func _mouse_on_plane(mouse_pos: Vector2, y: float) -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	return Plane(Vector3.UP, y).intersects_ray(cam.project_ray_origin(mouse_pos), cam.project_ray_normal(mouse_pos))

## Lets go of the object being dragged (gives it its physics back).
func release_grabbed_object():
	if grabbed_object is RigidBody3D:
		grabbed_object.freeze = false
	if PlayerManager.PositiveWire == grabbed_object:
		AnimationManager.WirePositiveFlash.visible = true
		AnimationManager.WireNegativeFlash.visible = true
		AnimationManager.PositiveBatteryFlash.visible = false
		AnimationManager.HideResetZones()
	if PlayerManager.NegativeWire == grabbed_object:
		AnimationManager.WireNegativeFlash.visible = true
		AnimationManager.WirePositiveFlash.visible = true
		AnimationManager.NegativeBatteryFlash.visible = false
		AnimationManager.HideResetZones()
	grabbed_object = null

## Free-roam (dev) camera: fly around with the move keys.
func handle_free_roam_movement(delta: float) -> void:
	# Get input direction
	var input_dir = Input.get_vector("left", "right", "forward", "backward")

	# Calculate movement direction based on where FREEROAMHEAD is looking
	# Using the camera's basis for true first-person direction
	var forward = FREEROAMCAMERA.global_transform.basis.z  # Forward is -Z in Godot
	var right = FREEROAMCAMERA.global_transform.basis.x

	# Combine input with direction vectors
	var movement = Vector3.ZERO
	movement += forward * input_dir.y  # Forward/backward
	movement += right * input_dir.x    # Left/right

	# Add vertical movement if needed (optional)
	if Input.is_action_pressed("action"):  # You can add a custom action
		movement.y += 1.0
	if Input.is_action_pressed("sprint"):  # You can add a custom action
		movement.y -= 1.0

	# Normalize to prevent faster diagonal movement
	if movement.length() > 0:
		movement = movement.normalized()

	# Apply movement speed
	var free_roam_speed = 10.0  # Adjust this value as needed
	movement *= free_roam_speed * delta

	# Move the FREEROAMHEAD node
	FREEROAMHEAD.global_translate(movement)

	# Handle rotation (full 360 degrees)
	handle_free_roam_rotation()

	# Optional: Keep the camera at the same position as FREEROAMHEAD
	# This ensures the view stays correct
	camera.global_position = FREEROAMCAMERA.global_position
	camera.global_rotation = FREEROAMCAMERA.global_rotation

## Free-roam (dev) camera: mouse look with no up/down limit.
func handle_free_roam_rotation() -> void:
	# Get mouse motion
	var mouse_motion = Input.get_last_mouse_velocity() * 0.01  # Adjust sensitivity

	# Apply rotation to FREEROAMHEAD (Y-axis - left/right)
	FREEROAMHEAD.rotate_y(-mouse_motion.x * SENSITIVITY)

	# Apply rotation to FREEROAMCAMERA (X-axis - up/down)
	FREEROAMCAMERA.rotate_x(-mouse_motion.y * SENSITIVITY)
	# No clamping for full 360 vertical rotation

## Switches to the free-roam (dev) camera.
func enter_free_roam_mode():
	# Store current transforms before entering free roam
	pre_free_roam_head_transform = head.global_transform
	pre_free_roam_camera_transform = camera.global_transform

	# Sync FreeRoam head to player position
	FREEROAMHEAD.global_transform = head.global_transform
	FREEROAMCAMERA.global_transform = camera.global_transform

	# Make FreeRoam camera current
	FREEROAMCAMERA.current = true
	PlayerManager.FreeRoam = true

## Back from the free-roam camera to the player.
func exit_free_roam_mode():
	# Restore player to pre-free roam position
	head.global_transform = pre_free_roam_head_transform
	camera.global_transform = pre_free_roam_camera_transform

	# Make player camera current
	camera.current = true
	PlayerManager.FreeRoam = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		is_exiting = true
		set_physics_process(false)
		set_process(false)
		set_process_unhandled_input(false)


## Puts the camera back where head bob started (used before teleports).
func reset_headbob() -> void:
	t_bob = 0.0
	camera.transform.origin = Vector3.ZERO

func _on_equipped_item_changed(item_name: String) -> void:
	FLASHLIGHT.visible = (item_name == "Flash Light")
