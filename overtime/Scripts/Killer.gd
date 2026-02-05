## No Exit
## Overtime Studios
##

extends CharacterBody3D


var SPEED = 2.0

@onready var nav: NavigationAgent3D = get_node("NavigationAgent3D")
@onready var WalkingAnimator = $AnimationPlayer
@onready var StabbingAnimator = $StabbingAnimation

var teleports

func _ready():
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
	

func _physics_process(delta: float) -> void:
	if PlayerManager.teleportEnemy && teleports:
		if PlayerManager.Loop0:
			find_teleport_target("NearCarTeleport")
		else: 
			find_teleport_target("FarTeleport")
		PlayerManager.teleportEnemy = false
	
	if not PlayerManager.dying:
		WalkingAnimator.play("Scene")
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y -= 2
	
	if PlayerManager.MinigameMode:
		SPEED = 4.0
	else:
		SPEED = 2.0
	
	var next_location = nav.get_next_path_position()
	var current_location = global_transform.origin
	var new_velocity = (next_location - current_location).normalized() * SPEED

	# Make the enemy face the direction it's moving
	if new_velocity.length() > 0:
		look_at(global_transform.origin - new_velocity, Vector3.UP)

	velocity = velocity.move_toward(new_velocity, 0.25)
	move_and_slide()
	
	# Calculate path distance to target
	PlayerManager.scaredDistance = calculate_path_distance()
	
	
	
func target_position(target):
	if position == target:
		return
	nav.target_position = target
	move_and_slide()
	
func find_teleport_target(targetname):
	for target in teleports:
		if target.name == targetname:
			self.global_position = target.global_position

func calculate_path_distance() -> float:
	# Get the full navigation path
	var path = nav.get_current_navigation_path()
	var total_distance = 0.0
	
	# Sum the distances between each point in the path
	for i in range(path.size() - 1):
		total_distance += path[i].distance_to(path[i + 1])
	
	return total_distance
	
func kill():
	$Armature.visible = false
	$Skeleton3D.visible = true
	$Skeleton3D/killer_UV_unwrapped.visible = true
	PlayerManager.HideDialog()
	PlayerManager.dying = true
	PlayerManager.InAnimation = true
	if PlayerManager.minigameTwo:
		PlayerManager.minigameTwo = false
		PlayerManager.gasIntakeUI.visible = false
		PlayerManager.Gas_Canister.visible = false
		PlayerManager.gasIntakeSweetSpot.visible = false
	if PlayerManager.minigameThree:
		PlayerManager.hoodUI.visible = false
	# Make the player's camera face the enemy before stabbing
	if PlayerManager.player and PlayerManager.player.CAMERA:
		PlayerManager.player.CAMERA.current = true
		PlayerManager.MiniGameModeOff()
		PlayerManager.player.CURSOR.visible = false
		var camera = PlayerManager.player.CAMERA
	
		
		# Get the positions - raise enemy position to look at upper body/head
		var enemy_pos = global_transform.origin + Vector3(0, 1.5, 0)  # Raise by 1.5 meters
		var camera_pos = camera.global_transform.origin
		
		# Calculate the direction from camera to enemy
		var direction = (enemy_pos - camera_pos).normalized()
		
		# Create a transform that looks at the enemy
		var look_transform = camera.global_transform.looking_at(enemy_pos, Vector3.UP)
		
		# Get the target rotation for the camera
		var target_rotation = look_transform.basis.get_euler()
		
		# Get current camera rotation
		var current_rotation = camera.global_rotation
		
		# Calculate the shortest rotation path
		var shortest_target_rotation = Vector3()
		shortest_target_rotation.x = current_rotation.x  # Keep the same pitch
		shortest_target_rotation.y = find_shortest_y_rotation(current_rotation.y, target_rotation.y)
		shortest_target_rotation.z = current_rotation.z  # Keep the same roll
		
		# Create a tween to rotate the camera smoothly
		var tween = create_tween()
		tween.tween_property(camera, "global_rotation", shortest_target_rotation, 0.5)
		
		# Wait for rotation to complete before stabbing
		await tween.finished
	
	# Play the stabbing animation
	StabbingAnimator.play("Stabbing")
	AudioManager.KillerShutUp = true
	AudioManager.play_sound_loop(AudioManager.SkullCrush, "Kill")
	
# Helper function to find the shortest Y rotation path
func find_shortest_y_rotation(current: float, target: float) -> float:
	var difference = fmod(target - current, TAU)
	if difference > PI:
		difference -= TAU
	elif difference < -PI:
		difference += TAU
	return current + difference

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
		PlayerManager.player.GAMEOVER.visible =  true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().paused = true
	
