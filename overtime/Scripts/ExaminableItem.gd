extends Interactable
class_name ExaminableItem

# Store original position and rotation
var original_position: Vector3
var original_rotation: Vector3
var original_scale: Vector3

# Tween for smooth animations
var tween: Tween
var debug_mesh: MeshInstance3D

# Export the mesh and material to ensure they match the original object
@export var target_mesh: Mesh
@export var target_material: Material
@export var target_scale: Vector3 = Vector3.ONE

# Adjustable parameters for the focus behavior
@export var focus_distance: float = 1.2  # Distance in front of camera
@export var vertical_offset: float = -0.7  # Vertical offset from camera height (negative = lower)
@export var rotation_intensity: float = 1.0  # How much to rotate (0 = no rotation, 1 = full rotation)
@export var scale_multiplier: float = 1.5  # How much to scale the object during focus

# Track if we're currently in an interaction
var is_in_interaction: bool = false
# New bool to track if we should stay in focus mode
var should_stay_in_focus: bool = false

# Rotation speed (radians per second)
@export var rotation_speed: float = 3.0

# Current rotation angle
var current_rotation: float = 0.0

# Dialog and behavior customization
@export var player_manager_reference: String = ""  # e.g., "PictureFrame1", "Mug1A"
@export var animation_name: String = ""  # e.g., "PictureFrame1Fade", "Mug1AFade"
@export var animation_fade_player: AnimationPlayer
@export var first_time_dialog: String = "I like this item!"
@export var first_time_hint: String = "Press A or D to rotate object while examing"
@export var normal_dialog: String = "I like this item!"
@export var keys_hint_dialog: String = "I should grab my keys and get out of here"
@export var can_be_stored: bool = false  # If this item can be stored in the box

# Flash system
@export var flash_animation_manager_reference: String
@export var flash_animation_player: AnimationPlayer
@export var flash_animation_name: String
@export var flash_mesh: MeshInstance3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if flash_animation_player and flash_animation_manager_reference:
		AnimationManager.set(flash_animation_manager_reference, flash_animation_player)
		AnimationManager.ExaminItemActivation(flash_animation_name)
		flash_animation_player.play(flash_animation_name)
	# Set the PlayerManager reference if specified
	if player_manager_reference != "":
		PlayerManager.set(player_manager_reference, self)
	
	# Store original transform
	original_position = global_position
	original_rotation = global_rotation
	original_scale = scale
	
	# Create a debug mesh that looks like the original object
	_create_debug_mesh()

func _process(delta: float) -> void:
	if PlayerManager.EquippedItem == "Box" and can_be_stored and flash_mesh and not PlayerManager.examining and get_parent().visible and not PlayerManager.player.interact_ray.get_collider() == self:
		flash_mesh.visible = true
	elif flash_mesh:
		flash_mesh.visible = false

func _create_debug_mesh() -> void:
	# Remove any existing debug mesh
	for child in get_children():
		if child.name == "DebugMesh":
			child.queue_free()
	
	# Create a new debug mesh
	debug_mesh = MeshInstance3D.new()
	debug_mesh.name = "DebugMesh"
	
	# Use the exported mesh and material
	if target_mesh:
		debug_mesh.mesh = target_mesh
	else:
		# Fallback to searching for a mesh
		var found_mesh = _find_original_mesh()
		if found_mesh:
			debug_mesh.mesh = found_mesh.mesh
		else:
			# Final fallback to a box mesh
			debug_mesh.mesh = BoxMesh.new()
			debug_mesh.scale = Vector3(0.5, 0.5, 0.1)
	
	# Apply the material if provided
	if target_material:
		debug_mesh.material_override = target_material
	
	# Apply the scale if provided
	if target_scale != Vector3.ONE:
		debug_mesh.scale = target_scale
	
	# Hide the debug mesh initially
	debug_mesh.visible = false
	
	add_child(debug_mesh)

func _find_original_mesh() -> MeshInstance3D:
	# Search for a MeshInstance3D in children (including nested children)
	return _find_mesh_in_children(self)

func _find_mesh_in_children(node: Node) -> MeshInstance3D:
	# Check if this node is a MeshInstance3D
	if node is MeshInstance3D and node.name != "DebugMesh":
		return node
	
	# Recursively check children
	for child in node.get_children():
		var result = _find_mesh_in_children(child)
		if result:
			return result
	
	return null

func _on_interacted(body: Variant) -> void:
	PlayerManager.ExamingItem = self
	if flash_mesh:
		flash_mesh.visible = false
	
	# Play animation if specified
	if animation_name != "" and animation_fade_player:
		animation_fade_player.play(animation_name)
	
	# Prevent multiple simultaneous interactions
	if is_in_interaction:
		return
	
	PlayerManager.examining = true
	PlayerManager.player.CURSOR.visible = false
	is_in_interaction = true
	should_stay_in_focus = true
	
	# Get the player's camera
	var camera = PlayerManager.player.CAMERA
	if not camera:
		is_in_interaction = false
		should_stay_in_focus = false
		return
	
	# Calculate position directly in front of the camera
	var camera_transform = camera.global_transform
	var focus_offset = camera_transform.basis.z * -focus_distance
	var focus_position = camera_transform.origin + focus_offset
	
	# Adjust height with vertical offset
	focus_position.y = camera_transform.origin.y + vertical_offset
	
	# Set up the debug mesh at the original position
	debug_mesh.global_position = global_position
	debug_mesh.global_rotation = global_rotation
	debug_mesh.scale = scale
	
	# Hide the original object immediately and show the debug mesh
	debug_mesh.visible = true
	
	# Disable collision during focus to avoid issues
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = true
	
	# Create tween for animations on the debug mesh
	tween = create_tween()
	tween.set_parallel(true)
	
	# Animate debug mesh to focus position
	tween.tween_property(debug_mesh, "global_position", focus_position, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Make debug mesh face the camera properly
	var camera_position = camera.global_position
	var direction_to_camera = (camera_position - focus_position).normalized()
	
	# Create a basis that faces the camera
	var target_basis = Basis()
	target_basis.z = direction_to_camera
	target_basis.y = Vector3.UP
	target_basis.x = target_basis.y.cross(target_basis.z).normalized()
	target_basis = target_basis.orthonormalized()
	
	# Convert to rotation
	var target_rotation = target_basis.get_euler()
	
	# Rotate 90 degrees to the right (in radians)
	target_rotation.y -= PI/2
	current_rotation = target_rotation.y
	
	# Apply rotation intensity
	if rotation_intensity < 1.0:
		var current_rot = debug_mesh.global_rotation
		target_rotation = current_rot.lerp(target_rotation, rotation_intensity)
	
	tween.tween_property(debug_mesh, "global_rotation", target_rotation, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Scale up the debug mesh with adjustable multiplier
	tween.tween_property(debug_mesh, "scale", original_scale * scale_multiplier, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Handle dialog based on game state
	if not PlayerManager.examed:
		PlayerManager.CharacterHintDialog(first_time_dialog, first_time_hint)
		PlayerManager.examed = true
	elif PlayerManager.DeskItems.size() == 3 and not PlayerManager.has_item("Car Keys"):
		PlayerManager.CharacterHintDialog(normal_dialog, keys_hint_dialog)
	else:
		PlayerManager.CharacterDialog(normal_dialog)
	
	# Wait for the second signal (should_stay_in_focus becomes false)
	while should_stay_in_focus:
		await get_tree().create_timer(0.1).timeout
	
	# Return to original position
	await _return_to_original()
	
	is_in_interaction = false

# Function to end the focus mode
func end_focus() -> void:
	PlayerManager.examining = false
	PlayerManager.player.CURSOR.visible = true
	should_stay_in_focus = false
	
	if PlayerManager.EquippedItem == "Box" and can_be_stored:
		_on_interaction_complete()
		PlayerManager.DeskItems.append(self)
		get_parent().visible = false
	else:
		# Play animation backwards if specified
		if animation_name != "" and animation_fade_player:
			animation_fade_player.play_backwards(animation_name)
		if PlayerManager.EquippedItem == "Box" and can_be_stored:
			flash_mesh.visible = false
	
func _hide_meshes_in_children(node: Node) -> void:
	# Hide if this node is a MeshInstance3D (but not our debug mesh)
	if node is MeshInstance3D and node.name != "DebugMesh":
		node.visible = false
	
	# Recursively hide in children
	for child in node.get_children():
		_hide_meshes_in_children(child)

func _show_original_object() -> void:
	# Find and show all MeshInstance3D children (including nested)
	_show_meshes_in_children(self)
	
func _show_meshes_in_children(node: Node) -> void:
	# Show if this node is a MeshInstance3D (but not our debug mesh)
	if node is MeshInstance3D and node.name != "DebugMesh":
		node.visible = true
	
	# Recursively show in children
	for child in node.get_children():
		_show_meshes_in_children(child)

func _return_to_original() -> void:
	# Create new tween for return animation
	tween = create_tween()
	tween.set_parallel(true)
	
	# Animate debug mesh back to original position, rotation and scale
	tween.tween_property(debug_mesh, "global_position", original_position, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(debug_mesh, "global_rotation", original_rotation, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(debug_mesh, "scale", original_scale, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Wait for return animation to complete
	await tween.finished
	
	# Hide debug mesh and show original object
	debug_mesh.visible = false
	_show_original_object()
	
	# Re-enable collision
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = false

# Function to rotate the debug mesh right (clockwise)
func rotate_right() -> void:
	if not is_in_interaction or not debug_mesh.visible:
		return
	
	current_rotation += rotation_speed * get_process_delta_time()
	_apply_rotation()

# Function to rotate the debug mesh left (counter-clockwise)
func rotate_left() -> void:
	if not is_in_interaction or not debug_mesh.visible:
		return
	
	current_rotation -= rotation_speed * get_process_delta_time()
	_apply_rotation()

# Apply the current rotation to the debug mesh
func _apply_rotation() -> void:
	if debug_mesh and debug_mesh.visible:
		var current_rot = debug_mesh.global_rotation
		debug_mesh.global_rotation = Vector3(current_rot.x, current_rotation, current_rot.z)
