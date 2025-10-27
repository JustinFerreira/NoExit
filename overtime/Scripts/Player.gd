extends CharacterBody3D

var speed
const WALK_SPEED = 3.0
const SPRINT_SPEED = 4.5
const JUMP_VELOCITY = 4.5
var SENSITIVITY = PlayerManager.Sensitivity
var gravity = true


var is_sprinting = false

#bob variables
const BOB_FREQ = 4.0 # How often you bob
const BOB_AMP = 0.04 # How high and low you bob
var t_bob = 0.0 # Determines how far along the signwave we are for bobbing

#fov variables
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

#Step variables
var was_moving = false
var is_moving = false

var breathing_volume = -10  # Adjust as needed
var heartbeat_volume = -20  # Adjust as needed

#settings

var TbobON = true
var FOVON = true
var Incar = false

@onready var HEAD = $Head
@onready var CAMERA = $Head/Camera3D
@onready var INTERACT_RAY = $Head/Camera3D/InteractRay
@onready var AREA3D = $Area3D
@onready var COLLISIONSHAPE3D = $CollisionShape3D  
@onready var CURSOR = $Cursor
@onready var DIALOG = $DialogControl

@onready var head = $Head
@onready var camera:Camera3D = $Head/Camera3D
@onready var interact_ray:RayCast3D = $"Head/Camera3D/InteractRay"
@onready var prompt = $Head/Camera3D/InteractRay/Prompt

## Grabbing Objects Variables
var grabbed_object = null
var mouse = Vector2()
var original_position = Vector3()
var grab_distance = Vector3()
var grab_direction = Vector3()
var grab_offset = Vector3()  # Add this to store the offset
var lock_axis = "XZ"  # Options: "XZ", "XY", "YZ", "X", "Y", "Z"

# Function that starts as soon as Player in in the scene
func _ready() -> void:
	PlayerManager.player = self
	CAMERA.current = true
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	AudioManager.play_sound_loop(AudioManager.breathing, "breathing", 1.0, breathing_volume)
	AudioManager.play_sound_loop(AudioManager.heartbeat, "heartbeat", 1.0 , heartbeat_volume)
	
# Any input that is detected automatically calls this function

func _process(delta: float) -> void:
	if grabbed_object:
		# Update mouse position to current position
		mouse = get_viewport().get_mouse_position()
		grabbed_object.position = get_grab_position()

func _unhandled_input(event: InputEvent) -> void:
	if PlayerManager.InAnimation:
		return
	if event is InputEventMouseMotion:
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
		if grabbed_object == null && PlayerManager.minigameThree == true && event.is_action_released("Interact") == false && event.button_index == MOUSE_BUTTON_LEFT:
				get_mouse_world_pos(mouse)
		elif grabbed_object != null && PlayerManager.minigameThree == true && event.is_action_released("Interact") == false && event.button_index == MOUSE_BUTTON_LEFT:
				grabbed_object = null
	if event.is_action_pressed("ui_cancel"):
		if PlayerManager.DevMode:
			$PauseMenu.pause()
		else:
			$SimplifiedPauseMenu.pause()
	if event.is_action_pressed("Inventory"):
		$Inventory.visible = !$Inventory.visible
		#print($Inventory.visible)
		
		if $Inventory.visible:
			populate_inventory()
		
	if event.is_action("action"):
		if PlayerManager.minigameTwo == true:
			PlayerManager.actioning = true
	if event.is_action_released("action"):  
		PlayerManager.actioning = false
			
			

# Premade Godot Functiuon for movement given to CharacterBody 3D
# has some added flare for this game
func _physics_process(delta: float) -> void:
	if PlayerManager.InAnimation || PlayerManager.MinigameMode:
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
		
		if collider is Interactable:
			#prompt.text = collider.prompt_message
			$Cursor/Corsshair.visible = false
			$Cursor/Hand.visible = true
			
			if Input.is_action_just_pressed("Interact"):
				collider.interact(owner)
		else:
			$Cursor/Corsshair.visible = true
			$Cursor/Hand.visible = false
			
	
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
		
	# Handle Heartbeat and Breathing sounds
	apply_breathing_effects()
	apply_heartbeat_effects()
		
	# Update movement state for next frame
	was_moving = is_moving
	
	
	# Head Bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	if TbobON && PlayerManager.HeadBob:
		camera.transform.origin = _headbob(t_bob)
	
	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, speed * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	if FOVON == true:
		camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	if velocity.length() > 0.1:
		var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
		if horizontal_velocity.length() > 0.1:
			
			var forward = -transform.basis.z  # Forward direction in Godot is -Z
			var movement_direction = horizontal_velocity.normalized()
			var angle = forward.signed_angle_to(-movement_direction, Vector3.UP)
			$MeshInstance3D.rotation.y = angle
	move_and_slide()
	
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
	


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy"): 
		get_tree().paused = true
		$GameOverScreen.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		## Stop any sounds that could be playing
		AudioManager.stop_loop("step")
		AudioManager.stop_loop("heartbeat")
		AudioManager.stop_loop("breathing")


func apply_breathing_effects():
	# Adjust breathing sound based on current state
	var target_pitch = 1.0
	var target_volume = breathing_volume

	# Make breathing slightly faster when moving
	if is_moving:
		target_pitch = 1.1
	else:
		target_pitch = 0.9
		
	if PlayerManager.scared:
		target_pitch = 2
		target_volume = 10

	## Make breathing more intense when low on stamina
	#if stamina < 30:
		#target_pitch = 1.2
		#target_volume = breathing_volume + 5.0  # Louder when exhausted

	AudioManager.set_loop_pitch("breathing", target_pitch)
	AudioManager.set_loop_volume("breathing", target_volume)
	
func apply_heartbeat_effects():
	# Adjust heartbeat based on player state
	var target_pitch = 1.0
	var target_volume = heartbeat_volume

	# Make heartbeat faster when sprinting or low health
	if Input.is_action_pressed("sprint"):
		target_pitch = 1.1
		target_volume = heartbeat_volume + 2.0
		
	if PlayerManager.scared:
		target_pitch = 2
		target_volume = 10

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
	var end = start + camera.project_ray_normal(mouse) * 10

	var params = PhysicsRayQueryParameters3D.create(start, end)

	var result = space.intersect_ray(params)
	if result.collider.is_in_group("grabbable"):
		grabbed_object = result.collider
		original_position = grabbed_object.global_position
		
		# Store the distance from camera to object center
		var camera_to_object = original_position - camera.global_position
		grab_distance = camera_to_object.length()
		
		# Store the direction from camera to object
		grab_direction = camera_to_object.normalized()
		
		# Calculate the offset from object center to the grab point
		grab_offset = result.position - original_position
		
func get_grab_position():
	if not grabbed_object:
		return Vector3.ZERO
		
	var camera = get_viewport().get_camera_3d()
	
	# Get the mouse direction in world space
	var mouse_dir = camera.project_ray_normal(mouse)
	
	# Calculate a point along this direction at the original distance
	var new_pos = camera.global_position + mouse_dir * grab_distance
	
	# Apply the grab offset to maintain the relative position where the object was grabbed
	new_pos += grab_offset
	
	# Apply axis locking
	match lock_axis:
		"XZ":  # Keep original Y, use new X and Z
			return Vector3(new_pos.x, original_position.y, new_pos.z)
		"XY":  # Keep original Z, use new X and Y
			return Vector3(new_pos.x, new_pos.y, original_position.z)
		"YZ":  # Keep original X, use new Y and Z
			return Vector3(original_position.x, new_pos.y, new_pos.z)
		"X":   # Only move on X axis
			return Vector3(new_pos.x, original_position.y, original_position.z)
		"Y":   # Only move on Y axis
			return Vector3(original_position.x, new_pos.y, original_position.z)
		"Z":   # Only move on Z axis
			return Vector3(original_position.x, original_position.y, new_pos.z)
		_:     # No locking
			return new_pos
