## No Exit
## Overtime Studios

extends CharacterBody3D

var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 7.5
const JUMP_VELOCITY = 4.5
var SENSITIVITY = PlayerManager.Sensitivity
var gravity = true


var is_sprinting = false

#bob variables
const BOB_FREQ = 4.0 # How often you bob
const BOB_AMP = 0.03 # How high and low you bob
var t_bob = 0.0 # Determines how far along the signwave we are for bobbing

#fov variables
#const BASE_FOV = 75.0
#const FOV_CHANGE = 1.5
#const MAX_FOV = 90.0  # Add this
#const MIN_FOV = 70.0  # Add this
#const FOV_TRANSITION_SPEED = 1.0  # Adjust this for smoother/faster transitions

#Step variables
var was_moving = false
var is_moving = false

var breathing_volume = -80  # Adjust as needed
var heartbeat_volume = -20  # Adjust as needed

#settings

var TbobON = true
var FOVON = false
var Incar = false

@onready var HEAD = $Head
@onready var CAMERA = $Head/Camera3D
@onready var INTERACT_RAY = $Head/Camera3D/InteractRay
@onready var AREA3D = $Player
@onready var COLLISIONSHAPE3D = $CollisionShape3D  
@onready var CURSOR = $Cursor
@onready var DIALOG = $DialogControl
@onready var GAMEOVER = $GameOverScreen

@onready var head = $Head
@onready var camera:Camera3D = $Head/Camera3D
@onready var interact_ray:RayCast3D = $"Head/Camera3D/InteractRay"
@onready var prompt = $Head/Camera3D/InteractRay/Prompt

## Grabbing Objects Variables
var grabbed_object = null
var mouse = Vector2()
var original_mouse_pos = Vector2()  # Store initial mouse position
var original_object_pos = Vector3()  # Store initial object position
#var grab_distance = Vector3()
#var grab_direction = Vector3()
#var grab_offset = Vector3()  # Add this to store the offset
var lock_axis = "XZ"  # Options: "XZ", "XY", "YZ", "X", "Y", "Z"

## Outline help
var last_collider = null


# Function that starts as soon as Player in in the scene
func _ready() -> void:
	PlayerManager.player = self
	CAMERA.current = true
	CameraManager.FPCamera = CAMERA
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if not PlayerManager.Loop0:
		AudioManager.play_sound_loop(AudioManager.breathing, "breathing", 1.0, breathing_volume)
		AudioManager.play_sound_loop(AudioManager.heartbeat, "heartbeat", 1.0 , heartbeat_volume)
	
# Any input that is detected automatically calls this function

func _process(delta: float) -> void:
	if grabbed_object:
		# Update mouse position to current position
		mouse = get_viewport().get_mouse_position()
		grabbed_object.position = get_grab_position()

func _unhandled_input(event: InputEvent) -> void:
	if PlayerManager.InAnimation || PlayerManager.dying:
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
			camera.rotate_x(-event.relative.y * SENSITIVITY)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))
		elif Incar == true:
			head.rotate_y(-event.relative.x * SENSITIVITY)
			camera.rotate_x(event.relative.y * SENSITIVITY)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))
			head.rotation.y = clamp(head.rotation.y, deg_to_rad(-90), deg_to_rad(90))
	if event is InputEventMouseButton:
		if PlayerManager.Office && DIALOG.is_typing == false:
			PlayerManager.EndFocus()
		if DIALOG.is_typing == false && PlayerManager.multiDialog == false && PlayerManager.finishedDialogAnimation == true && DIALOG.visible == true:
			PlayerManager.HideDialog()
			PlayerManager.dialoging = false
			PlayerManager.finishedDialogAnimation = false
			PlayerManager.startMultiDialog = true
		if PlayerManager.minigameTwo == true:
			PlayerManager.actioning = true
		if grabbed_object == null && PlayerManager.minigameThree == true && event.is_action_released("Interact") == false && event.button_index == MOUSE_BUTTON_LEFT:
				get_mouse_world_pos(mouse)
		elif grabbed_object != null && PlayerManager.minigameThree == true && event.is_action_released("Interact") == false && event.button_index == MOUSE_BUTTON_LEFT:
				release_grabbed_object()
	if event.is_action_released("Interact"):  
		PlayerManager.actioning = false
		if DIALOG.is_typing && PlayerManager.finishedDialogAnimation == true:
			DIALOG.skip_typewriter_effect()
			return
		elif PlayerManager.startMultiDialog == false && PlayerManager.multiDialog:
			PlayerManager.NextDialog()
		elif PlayerManager.startMultiDialog == true && PlayerManager.multiDialog:
			PlayerManager.startMultiDialog = false
	if event.is_action_pressed("ui_cancel"):
		#Button clikc sound
		AudioManager.play_sound(AudioManager.GetKeyPress())
		if PlayerManager.minigameOne:
			AnimationManager.SteeringWheelFlash.visible = true
			PlayerManager.minigameOne = false
			UiManager.HotWireUI.visible = false
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
			PlayerManager.gasIntakeUI.visible = false
			PlayerManager.Gas_Canister.visible = false
			PlayerManager.gasIntakeSweetSpot.visible = false
			PlayerManager.MiniGameModeOff()
		elif PlayerManager.minigameThree:
			PlayerManager.minigameThree = false
			AnimationManager.HoodFlash.visible = true
			AnimationManager.PositiveBatteryFlash.visible = false
			AnimationManager.NegativeBatteryFlash.visible = false
			if not PlayerManager.minigameOnePassed or (PlayerManager.minigameOnePassed and PlayerManager.minigameTwoPassed and PlayerManager.minigameThreePassed):
				AnimationManager.DoorFlash.visible = true
			if not PlayerManager.minigameTwoPassed and PlayerManager.has_item("Gas Canister"):
				AnimationManager.GasIntakeFlash.visible = true
			grabbed_object = null
			CAMERA.current = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			prompt.visible = true
			PlayerManager.hoodUI.visible =  false
			PlayerManager.PositiveWire.visible = false
			PlayerManager.NegativeWire.visible = false
			PlayerManager.Battery.visible = false
			PlayerManager. MiniGameModeOff()
		else:
			if PlayerManager.DevMode:
				$PauseMenu.pause()
			else:
				$SimplifiedPauseMenu.pause()
	if event.is_action("Inventory"):
		$Inventory.visible = true
		populate_inventory()
	if event.is_action_released("Inventory"):
		$Inventory.visible = false
			
			
			

# Premade Godot Functiuon for movement given to CharacterBody 3D
# has some added flare for this game
func _physics_process(delta: float) -> void:
	# Handle Heartbeat and Breathing sounds
	apply_breathing_effects()
	apply_heartbeat_effects()
	
	if PlayerManager.InAnimation || PlayerManager.MinigameMode || PlayerManager.multiDialog || PlayerManager.dying || PlayerManager.examining:
		return
	SENSITIVITY = PlayerManager.Sensitivity
	
	# Add the gravity.
	if not is_on_floor():
		if gravity == true:
			velocity += get_gravity() * delta

	##  We don't want a jump so no jumping
	#if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		#velocity.y = JUMP_VELOCITY
	
	## Interactions
	prompt.text = ""
	
	if interact_ray.is_colliding():
		var collider = interact_ray.get_collider()
		var collision_point = interact_ray.get_collision_point()
		var distance = interact_ray.global_position.distance_to(collision_point)
		
		# Only interact if within 1 meter
		if distance <= 5.0 && collider is Interactable && collider.is_interactable:
			$Cursor/Corsshair.visible = false
			$Cursor/Hand.visible = true
			
			# If we have a new collider, hide the previous one's outline
			if last_collider != null && last_collider != collider:
				last_collider.hide_outline()
			
			# Show outline for current collider
			if collider.show_outline():
				last_collider = collider
			
			if Input.is_action_just_pressed("Interact"):
				collider.interact(owner)
		else:
			$Cursor/Corsshair.visible = true
			$Cursor/Hand.visible = false
			if last_collider != null:
				last_collider.hide_outline()
				last_collider = null
	else:
		$Cursor/Corsshair.visible = true
		$Cursor/Hand.visible = false
		if last_collider != null:
			last_collider.hide_outline()
			last_collider = null
			
	
	# Handle Sprint
	if Incar == true:
		speed = 0
		is_sprinting = false
	else:
		handle_sprint_input()
		apply_sprint_speed()

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		
	# Check if player is moving (any movement key pressed)
	is_moving = Input.is_action_pressed("forward") or Input.is_action_pressed("backward") or \
			   Input.is_action_pressed("left") or Input.is_action_pressed("right")
	
	# Handle step sounds
	if is_moving and is_on_floor():
		if not was_moving:  # Just started moving
			AudioManager.play_sound_loop(AudioManager.step, "step", 1, -24, 0.2)
	elif was_moving:  # Was moving but now stopped
		AudioManager.stop_loop("step")
		
	
		
	# Update movement state for next frame
	was_moving = is_moving
	
	
	# Head Bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	if TbobON && PlayerManager.HeadBob:
		camera.transform.origin = _headbob(t_bob)
	
	## FOV - Smooth sliding between min and max
	#var target_fov = BASE_FOV
#
	#if FOVON:
		## When FOVON is true, slide to maximum FOV
		#target_fov = MAX_FOV
	#else:
		## When FOVON is false, slide to minimum FOV  
		#target_fov = MIN_FOV
#
	## Add slight FOV change based on velocity (optional - keep this if you want the speed effect)
	#var velocity_clamped = clamp(velocity.length(), 0.5, speed * 2)
	#target_fov += FOV_CHANGE * velocity_clamped
#
	## Apply smooth FOV transition
	#if FOVON:
		#camera.fov = lerp(camera.fov, target_fov, delta * FOV_TRANSITION_SPEED)
	#else:
		#camera.fov = lerp(camera.fov, target_fov, delta * FOV_TRANSITION_SPEED)

	if velocity.length() > 0.1:
		var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
		if horizontal_velocity.length() > 0.1:
			
			var forward = -transform.basis.z  # Forward direction in Godot is -Z
			var movement_direction = horizontal_velocity.normalized()
			var angle = forward.signed_angle_to(-movement_direction, Vector3.UP)
			$arms.rotation.y = angle
			$body.rotation.y = angle
	move_and_slide()
	
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	#pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
	


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy"): 
		## Stop any sounds that could be playing
		AudioManager.cancel_loop_sfx()
		
		PlayerManager.EnemyKill()
		
		


func apply_breathing_effects():
	if PlayerManager.Loop0:
		return
	# Adjust breathing sound based on current state
	PlayerManager.ProcessScared()
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
	# Adjust heartbeat based on player state
	PlayerManager.ProcessScared()
	var target_pitch = PlayerManager.scaredPitch
	var target_volume = PlayerManager.scaredVolume

	# Make heartbeat even more intense when very low health
	#if health < 20:
		#target_pitch = 1.3
		#target_volume = heartbeat_volume + 5.0

	AudioManager.set_loop_pitch("heartbeat", target_pitch)
	AudioManager.set_loop_volume("heartbeat", target_volume)
	
func populate_inventory():
	# Clear existing items
	for child in $Inventory/ColorRect/HBoxContainer.get_children():
		child.queue_free()

	# Create labels for each item
	for item in PlayerManager.Inventory:
		var label = Label.new()
		label.text = item.name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Set color based on whether this item is equipped
		if item.name == PlayerManager.EquippedItem:
			label.add_theme_color_override("font_color", Color("#990404"))
		else:
			label.add_theme_color_override("font_color", Color.WHITE)
		
		$Inventory/ColorRect/HBoxContainer.add_child(label)
		
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
	if is_sprinting:
		speed = SPRINT_SPEED
		AudioManager.set_loop_pitch("step", 4)
	else:
		speed = WALK_SPEED
		AudioManager.set_loop_pitch("step", 2)
		
		
func get_mouse_world_pos(mouse: Vector2):
	var space = get_world_3d().direct_space_state
	var camera = get_viewport().get_camera_3d()
	var start = camera.project_ray_origin(mouse)
	var end = start + camera.project_ray_normal(mouse) * 10.0

	var params = PhysicsRayQueryParameters3D.create(start, end)
	var result = space.intersect_ray(params)

	if result and result.collider and result.collider.is_in_group("grabbable"):
		grabbed_object = result.collider
		original_object_pos = grabbed_object.global_transform.origin
		original_mouse_pos = mouse  # Store the initial mouse position
		
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

	var camera = get_viewport().get_camera_3d()
	
	# Calculate mouse movement delta
	var mouse_delta = mouse - original_mouse_pos
	
	# Convert mouse delta to world space movement
	var sensitivity = 0.005  # Adjust this value to control movement sensitivity
	
	# Get camera's right and up vectors (ignoring rotation for simplicity)
	var camera_right = camera.global_transform.basis.x
	var camera_up = camera.global_transform.basis.y
	
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
