extends CharacterBody3D

var speed
const WALK_SPEED = 3.0
const SPRINT_SPEED = 4.5
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.01
var gravity = true

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

var breathing_volume = 10.0  # Adjust as needed
var heartbeat_volume = 15.0  # Adjust as needed

#settings

var TbobON = true
var FOVON = true
var Incar = false

@onready var HEAD = $Head
@onready var CAMERA = $Head/Camera3D
@onready var INTERACT_RAY = $Head/Camera3D/InteractRay
@onready var AREA3D = $Area3D
@onready var COLLISIONSHAPE3D = $CollisionShape3D  

@onready var head = $Head
@onready var camera:Camera3D = $Head/Camera3D
@onready var interact_ray:RayCast3D = $"Head/Camera3D/InteractRay"
@onready var prompt = $Head/Camera3D/InteractRay/Prompt

# Function that starts as soon as Player in in the scene
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	AudioManager.play_sound_loop(AudioManager.breathing, "breathing", 1.0)
	AudioManager.play_sound_loop(AudioManager.heartbeat, "heartbeat", 1.0)
	
# Any input that is detected automatically calls this function
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Incar == false:
			head.rotate_y(-event.relative.x * SENSITIVITY)
			camera.rotate_x(-event.relative.y * SENSITIVITY)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))
		elif Incar == true:
			head.rotate_y(-event.relative.x * SENSITIVITY)
			camera.rotate_x(event.relative.y * SENSITIVITY)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))
			head.rotation.y = clamp(head.rotation.y, deg_to_rad(-90), deg_to_rad(90))
	if event.is_action_pressed("ui_cancel"):
		$PauseMenu.pause()
		
		
			
			

# Premade Godot Functiuon for movement given to CharacterBody 3D
# has some added flare for this game
func _physics_process(delta: float) -> void:
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
			prompt.text = collider.prompt_message
			
			if Input.is_action_just_pressed("Interact"):
				collider.interact(owner)
	
	# Handle Sprint
	if Incar == true:
		speed = 0
	elif Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
		AudioManager.set_loop_pitch("step", 4)
	else:
		speed = WALK_SPEED
		AudioManager.set_loop_pitch("step", 2)

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
			AudioManager.play_sound_loop(AudioManager.step, "step", 2)
	elif was_moving:  # Was moving but now stopped
		AudioManager.stop_loop("step")
		
	# Handle Heartbeat and Breathing sounds
	apply_breathing_effects()
	apply_heartbeat_effects()
		
	# Update movement state for next frame
	was_moving = is_moving
	
	
	# Head Bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	if TbobON == true:
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

	# Make heartbeat even more intense when very low health
	#if health < 20:
		#target_pitch = 1.3
		#target_volume = heartbeat_volume + 5.0

	AudioManager.set_loop_pitch("heartbeat", target_pitch)
	AudioManager.set_loop_volume("heartbeat", target_volume)
