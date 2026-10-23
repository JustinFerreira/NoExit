## No Exit
## Overtime Studios
## Last update 2/14/26 by Justin Ferreira
## Player Script
## - this script contains all player input logic, 
## assist with camera movements,
## show some UI,
## inventory,
## some sound volumes,
## and some player settings

extends CharacterBody3D

var speed: float
const WALK_SPEED: float = 5.0
const SPRINT_SPEED: float = 7.5
var SENSITIVITY: float = PlayerManager.Sensitivity
var gravity: bool = true


var is_sprinting: bool = false

#bob variables
const BOB_FREQ: float = 4.0 # How often you bob
const BOB_AMP: float = 0.058 # How high and low you bob (world units; scaled with the player's height)
var t_bob: float = 0.0 # Determines how far along the signwave we are for bobbing

#Step variables
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
## How far (degrees) holding look-back turns your view. People can't spin
## their head a full 180 like an owl - ~135 is a look over the shoulder.
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
# 0 = standing, 1 = fully crouched / leaned / looking back (eased).
var _crouch_amount: float = 0.0
var _lean_amount: float = 0.0   # -1 = left, 1 = right
var _look_back_amount: float = 0.0
# Which way the body faces (where you walk / last walked); look-back is
# measured from this, not from where the head is looking.
var _body_forward := Vector3.ZERO
# Shoulder for the current look-back: 1 = left, -1 = right (picked on press).
var _look_back_side := -1.0
var _look_back_held := false
var _back_pitch_offset := 0.0   # pitch look-back has added on top of the mouse pitch
var _crouch_toggled: bool = false
# Standing setup, captured in _ready().
var _stand_head_y: float
var _stand_shape_transform: Transform3D
var _shape_bottom_local: float = 0.0
var _shape_top_local: float = 0.0

var stamina: float = 100.0
# Seconds since the player last ran (drives the regen delay).
var _time_since_sprint: float = 0.0
# Seconds of fatigue left. > 0 means fatigued.
var fatigue_time_left: float = 0.0
# Set by the Show Stamina Bar setting.
var show_stamina_bar: bool = true
# Set by the Tilt View When Leaning setting.
var lean_tilt_enabled: bool = true

var breathing_volume: float = -80  # Adjust as needed
var heartbeat_volume: float = -20  # Adjust as needed

#settings

var TbobON: bool = true
var Incar: bool = false
var trapped: bool = false

var is_exiting: bool = false

@onready var HEAD: Node3D = $Head
@onready var CAMERA: Camera3D = $Head/Camera3D
@onready var FLASHLIGHT: SpotLight3D = $Head/Camera3D/FlashLight
@onready var FREEROAMHEAD: Node3D = $FreeRoamHead
@onready var FREEROAMCAMERA:Camera3D  = $FreeRoamHead/Camera3D
@onready var INTERACT_RAY: RayCast3D = $Head/Camera3D/InteractRay
@onready var AREA3D: Area3D = $Player
@onready var COLLISIONSHAPE3D: CollisionShape3D = $CollisionShape3D  
@onready var CURSOR: Control = $CenterContainer/Cursor
# Looked up once - these were found by path every physics frame.
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
var lock_axis: String = "XZ"  # Options: "XZ", "XY", "YZ", "X", "Y", "Z"

## Outline help
var last_collider: CollisionObject3D = null

var pre_free_roam_head_transform: Transform3D
var pre_free_roam_camera_transform: Transform3D
var saved_collider: CollisionObject3D = null


# Function that starts as soon as Player in in the scene
func _ready() -> void:
	# New level: UiManager starts fresh and shows this player's crosshair.
	UiManager.on_player_ready(self)
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
	# their spawn marker and restore what carried over. Deferred so the
	# level's own _ready() has run first.
	GameState.place_player.call_deferred(self)
	# FOV, crouch toggle, text speed, etc. from the settings menu.
	SettingsManager.apply_player_settings(self)

	PlayerManager.player = self
	CAMERA.current = true
	CameraManager.FPCamera = CAMERA
	FLASHLIGHT.visible = false
	PlayerManager.equipped_item_changed.connect(_on_equipped_item_changed)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if not PlayerManager.Loop0 and not PlayerManager.OpeningCutscene:
			AudioManager.play_sound_loop(AudioManager.breathing, "breathing", 1.0, breathing_volume)
			AudioManager.play_sound_loop(AudioManager.heartbeat, "heartbeat", 1.0 , heartbeat_volume)
	
# Any input that is detected automatically calls this function

func _process(_delta: float) -> void:
	if grabbed_object:
		# Update mouse position to current position
		mouse = get_viewport().get_mouse_position()
		grabbed_object.position = get_grab_position()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("override"):
		if PlayerManager.DevMode:
				$DevPauseMenu.pause()
	if PlayerManager.InAnimation and  not PlayerManager.multiDialog || PlayerManager.dying:
		return
	if event.is_action_pressed("Keysound"):
		if PlayerManager.car_audio_player && PlayerManager.EquippedItem == "Car Keys":
			PlayerManager.KeyFobSound()
		elif PlayerManager.Office && PlayerManager.EquippedItem == "Car Keys":
			PlayerManager.Hint("Can only use this in the parking garage")
	if event.is_action("left"):
		if PlayerManager.examining:
			PlayerManager.ExamingItem.rotate_left()
			return
	if event.is_action("right"):
		if PlayerManager.examining:
			PlayerManager.ExamingItem.rotate_right()
			return
	if event.is_action_pressed("scrollUp"):
		PlayerManager.SwitchEquippedItem(true)
	if event.is_action_pressed("scrollDown"):
		PlayerManager.SwitchEquippedItem(false)
	if event is InputEventMouseMotion:
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
			camera.rotation.x += event.relative.y * SENSITIVITY * (-1.0 if PlayerManager.InvertY else 1.0)
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
		if grabbed_object == null && PlayerManager.minigameThree == true && event.is_action_released("Interact") == false && event.button_index == MOUSE_BUTTON_LEFT:
				get_mouse_world_pos(mouse)
		elif grabbed_object != null && PlayerManager.minigameThree == true && event.is_action_released("Interact") == false && event.button_index == MOUSE_BUTTON_LEFT:
				release_grabbed_object()
	if event.is_action_pressed("ui_cancel"):
		if PlayerManager.minigameOne:
			AnimationManager.SteeringWheelFlash.start_flashing()
			PlayerManager.minigameOne = false
			UiManager.show_panel("hotwire", false)
			AnimationManager.CarInteractRay.enabled = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			PlayerManager.MiniGameModeOff()
		elif PlayerManager.minigameTwo:
			AudioManager.stop_loop("glug")
			AnimationManager.GasIntakeFlash.visible = true
			if not PlayerManager.minigameOnePassed or (PlayerManager.minigameOnePassed and PlayerManager.minigameTwoPassed and PlayerManager.minigameThreePassed):
				AnimationManager.DoorFlash.visible = true
			if not PlayerManager.minigameThreePassed and PlayerManager.has_item("Battery"):
				AnimationManager.HoodFlash.visible = true
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
			AnimationManager.HoodFlash.start_flashing()
			
			
			if not PlayerManager.minigameOnePassed or (PlayerManager.minigameOnePassed and PlayerManager.minigameTwoPassed and PlayerManager.minigameThreePassed):
				AnimationManager.DoorFlash.start_flashing()
				pass
			if not PlayerManager.minigameTwoPassed and PlayerManager.has_item("Gas Canister"):
				AnimationManager.GasIntakeFlash.start_flashing()
			
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
			
			
			

# Premade Godot Functiuon for movement given to CharacterBody 3D
# has some added flare for this game
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
	
	if PlayerManager.InAnimation || PlayerManager.MinigameMode || PlayerManager.multiDialog || PlayerManager.dying || PlayerManager.examining:
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
	
	if is_moving and is_on_floor() and PlayerManager.firstdialog == false:
		if not was_moving:
			AudioManager.play_sound_loop(AudioManager.step, "step", 1, -24, 0.2)
	elif was_moving:
		AudioManager.stop_loop("step")
	
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


# _apply_step_assist
# Checks whether this frame's horizontal movement is about to get
# blocked by something shorter than step_height and, if so, hops the
# player straight up over it before move_and_slide() runs - turns a
# small mesh seam into a smooth step instead of a wall. Does nothing if
# the player isn't grounded, isn't moving, or the "wall" ahead is
# actually tall (a real wall) or has something above it (a low ceiling).
func _apply_step_assist(delta: float) -> void:
	if step_height <= 0.0 or not is_on_floor():
		return

	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length() < 0.001:
		return

	# Nothing in the way at ground level - no step needed.
	if not test_move(global_transform, motion):
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


func _handle_interact_ray() -> void:
	if not is_instance_valid(interact_ray) or not interact_ray.is_inside_tree():
		return
	
	if not interact_ray.is_colliding():
		UiManager.set_cursor_hover(false)
		if last_collider != null:
			last_collider.hide_outline()
			last_collider = null
		return
		
	var collider = interact_ray.get_collider()
	if not is_instance_valid(collider):
		return
	var collision_point = interact_ray.get_collision_point()
	var distance = interact_ray.global_position.distance_to(collision_point)
	
	if distance <= 5.0 && collider is Interactable && collider.is_interactable:
		UiManager.set_cursor_hover(true)
		if last_collider != null && last_collider != collider:
			last_collider.hide_outline()
		if collider.show_outline():
			last_collider = collider
		if Input.is_action_just_pressed("Interact"):
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
		
		


func apply_breathing_effects():
	if PlayerManager.Loop0:
		return
	# Adjust breathing sound based on current state (ProcessScared already ran)
	var target_pitch = PlayerManager.scaredPitch - 1
	var target_volume = PlayerManager.scaredVolume

	## Make breathing more intense when low on stamina
	#if stamina < 30:
		#target_pitch = 1.2
		#target_volume = breathing_volume + 5.0  # Louder when exhausted

	AudioManager.set_loop_pitch("breathing", target_pitch)
	AudioManager.set_loop_volume("breathing", target_volume)
	
func apply_heartbeat_effects():
	if PlayerManager.Loop0:
		return
	# Adjust heartbeat based on player state (ProcessScared already ran)
	var target_pitch = PlayerManager.scaredPitch
	var target_volume = PlayerManager.scaredVolume

	# Make heartbeat even more intense when very low health
	#if health < 20:
		#target_pitch = 1.3
		#target_volume = heartbeat_volume + 5.0

	AudioManager.set_loop_pitch("heartbeat", target_pitch)
	AudioManager.set_loop_volume("heartbeat", target_volume)
	
func populate_inventory():
	# The inventory strip is drawn by UiManager; refresh it if it's showing.
	UiManager.refresh_inventory()
		
func handle_sprint_input():
	if PlayerManager.Hold_Shift:
		# Hold-to-sprint mode (original behavior)
		if Input.is_action_pressed("sprint"):
			is_sprinting = true
		else:
			is_sprinting = false
	else:
		# Toggle-sprint mode
		if Input.is_action_just_pressed("sprint"):
			# Toggle sprint state when key is pressed
			is_sprinting = !is_sprinting
			PlayerManager.sprint_engaged = is_sprinting
			# Optional: Add toggle sound feedback
			# AudioManager.play_sound(AudioManager.sprint_toggle)

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

# _update_body_moves
# allowed = false (cutscenes, examining, in the car...) eases lean and
# look-back back to normal and keeps the crouch as it is.
func _update_body_moves(delta: float, allowed: bool) -> void:
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

# _can_stand
# Is there room above to stand back up from the current crouch?
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

# get_carry_state
# Everything about the player that should survive a level change.
# Inventory already lives in PlayerManager, so it isn't here.
func get_carry_state() -> Dictionary:
	return {
		"stamina": stamina,
		"fatigue_time_left": fatigue_time_left,
		"time_since_sprint": _time_since_sprint,
		"is_sprinting": is_sprinting,
		"look_pitch": camera.rotation.x,
	}

func apply_carry_state(state: Dictionary) -> void:
	stamina = state.get("stamina", stamina)
	fatigue_time_left = state.get("fatigue_time_left", fatigue_time_left)
	_time_since_sprint = state.get("time_since_sprint", _time_since_sprint)
	is_sprinting = state.get("is_sprinting", is_sprinting)
	camera.rotation.x = state.get("look_pitch", camera.rotation.x)

# get_look_yaw / set_look_yaw
# Which way the player is facing, in world space (radians around Y).
# Turning is done on the Head, so the body's own rotation is accounted for.
func get_look_yaw() -> float:
	return head.global_basis.orthonormalized().get_euler().y

func set_look_yaw(world_yaw: float) -> void:
	var body_yaw := global_basis.orthonormalized().get_euler().y
	head.rotation.y = wrapf(world_yaw - body_yaw, -PI, PI)

## ---------------------------------------------------------------------
## Stamina
## ---------------------------------------------------------------------

func is_fatigued() -> bool:
	return fatigue_time_left > 0.0

# _cancel_sprint
# Turns sprint off, including toggle-sprint, so it doesn't snap back on.
func _cancel_sprint() -> void:
	is_sprinting = false
	PlayerManager.sprint_engaged = false

# _update_stamina
# running = the player is actually moving with sprint on this frame.
func _update_stamina(delta: float, running: bool) -> void:
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

# _update_stamina_bar
# The bar itself is drawn by UiManager (top-left HUD); this just reports.
func _update_stamina_bar(_delta: float) -> void:
	var ratio := stamina / maxf(max_stamina, 0.001)
	if is_fatigued():
		# While fatigued the red bar shows the fatigue left, draining to 0.
		ratio = fatigue_time_left / maxf(fatigue_duration, 0.001)
	UiManager.update_stamina(ratio, is_fatigued(), stamina < max_stamina or is_fatigued(), show_stamina_bar)

func get_mouse_world_pos(mouse_pos: Vector2):
	var space = get_world_3d().direct_space_state
	var _camera = get_viewport().get_camera_3d()
	var start = _camera.project_ray_origin(mouse_pos)
	var end = start + _camera.project_ray_normal(mouse_pos) * 10.0

	var params = PhysicsRayQueryParameters3D.create(start, end)
	var result = space.intersect_ray(params)

	if result and result.collider and result.collider.is_in_group("grabbable"):
		grabbed_object = result.collider
		original_object_pos = grabbed_object.global_transform.origin
		original_mouse_pos = mouse_pos  # Store the initial mouse position
		
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
		
func get_grab_position() -> Vector3:
	if not grabbed_object:
		return Vector3.ZERO

	var _camera = get_viewport().get_camera_3d()
	
	# Calculate mouse movement delta
	var mouse_delta = mouse - original_mouse_pos
	
	# Convert mouse delta to world space movement
	var sensitivity = 0.005  # Adjust this value to control movement sensitivity
	
	# Get camera's right and up vectors (ignoring rotation for simplicity)
	var camera_right = _camera.global_transform.basis.x
	var camera_up = _camera.global_transform.basis.y
	
	# Calculate movement in world space based on mouse delta
	var world_movement = Vector3.ZERO
	world_movement += camera_right * mouse_delta.x * sensitivity
	world_movement -= camera_up * mouse_delta.y * sensitivity  # Inverted Y
	
	# Apply axis locking
	match lock_axis:
		"XZ":
			world_movement.y = 0
		"XY":
			world_movement.z = 0
		"YZ":
			world_movement.x = 0
		"X":
			world_movement.y = 0
			world_movement.z = 0
		"Y":
			world_movement.x = 0
			world_movement.z = 0
		"Z":
			world_movement.x = 0
			world_movement.y = 0
	
	# Calculate new position
	var new_position = original_object_pos + world_movement
	
	return new_position

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

func handle_free_roam_rotation() -> void:
	# Get mouse motion
	var mouse_motion = Input.get_last_mouse_velocity() * 0.01  # Adjust sensitivity
	
	# Apply rotation to FREEROAMHEAD (Y-axis - left/right)
	FREEROAMHEAD.rotate_y(-mouse_motion.x * SENSITIVITY)
	
	# Apply rotation to FREEROAMCAMERA (X-axis - up/down)
	FREEROAMCAMERA.rotate_x(-mouse_motion.y * SENSITIVITY)
	# No clamping for full 360 vertical rotation

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
		

func reset_headbob() -> void:
	t_bob = 0.0
	camera.transform.origin = Vector3.ZERO

func _on_equipped_item_changed(item_name: String) -> void:
	FLASHLIGHT.visible = (item_name == "Flash Light")
