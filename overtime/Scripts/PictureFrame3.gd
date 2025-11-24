extends Interactable

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
@export var rotation_speed: float = 1.5

# Current rotation angle
var current_rotation: float = 0.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerManager.PictureFrame3 = self
	# Store original transform
	original_position = global_position
	original_rotation = global_rotation  # Use global_rotation instead of rotation
	original_scale = scale
	
	# Create a debug mesh that looks like the original object
	_create_debug_mesh()

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
	$"../../PictureFrame3Fade".play("PictureFrame3Fade")
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
	var focus_offset = camera_transform.basis.z * -focus_distance  # Adjustable distance in front of camera
	var focus_position = camera_transform.origin + focus_offset
	
	# Adjust height with vertical offset
	focus_position.y = camera_transform.origin.y + vertical_offset
	
	# Set up the debug mesh at the original position
	debug_mesh.global_position = global_position
	debug_mesh.global_rotation = global_rotation  # Use global_rotation
	debug_mesh.scale = scale
	
	# Hide the original object immediately and show the debug mesh
	_hide_original_object()
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
	# Get camera's position and forward direction
	var camera_position = camera.global_position
	var camera_forward = -camera.global_transform.basis.z
	
	# Calculate the direction from focus position to camera
	var direction_to_camera = (camera_position - focus_position).normalized()
	
	# Create a basis that faces the camera
	var target_basis = Basis()
	target_basis.z = direction_to_camera  # Forward faces camera
	target_basis.y = Vector3.UP  # Keep upright
	target_basis.x = target_basis.y.cross(target_basis.z).normalized()  # Calculate right vector
	target_basis = target_basis.orthonormalized()  # Ensure valid rotation
	
	# Convert to rotation
	var target_rotation = target_basis.get_euler()
	
	# Rotate 90 degrees to the right (in radians)
	target_rotation.y -= PI/2
	current_rotation = target_rotation.y
	
	# Apply rotation intensity
	if rotation_intensity < 1.0:
		var current_rotation = debug_mesh.global_rotation
		target_rotation = current_rotation.lerp(target_rotation, rotation_intensity)
	
	tween.tween_property(debug_mesh, "global_rotation", target_rotation, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Scale up the debug mesh with adjustable multiplier
	tween.tween_property(debug_mesh, "scale", original_scale * scale_multiplier, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	if not PlayerManager.examed:
		PlayerManager.CharacterHintDialog("This was a great day!","Press A or D to rotate object while examing")
		PlayerManager.examed = true
	elif PlayerManager.DeskItems.size() == 3 and not PlayerManager.has_item("Car Keys"):
		PlayerManager.CharacterHintDialog("This was a great day!","I should grab my keys and get out of here")
	else:
		PlayerManager.CharacterDialog("This was a great day!")
	
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
	if PlayerManager.EquippedItem == "Box":
		_on_interaction_complete()
		PlayerManager.DeskItems.append(self)
		get_parent().visible = false
	else:
		$"../../PictureFrame3Fade".play_backwards("PictureFrame3Fade")

func _hide_original_object() -> void:
	# Find and hide all MeshInstance3D children (including nested)
	_hide_meshes_in_children(self)
	
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
	_show_original_object()  # This is where the original object becomes visible again
	
	# Re-enable collision
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = false

# Function to rotate the debug mesh left (counter-clockwise)
func rotate_right() -> void:
	if not is_in_interaction or not debug_mesh.visible:
		return
	
	current_rotation += rotation_speed * get_process_delta_time()
	_apply_rotation()

# Function to rotate the debug mesh right (clockwise)
func rotate_left() -> void:
	if not is_in_interaction or not debug_mesh.visible:
		return
	
	current_rotation -= rotation_speed * get_process_delta_time()
	_apply_rotation()

# Apply the current rotation to the debug mesh
func _apply_rotation() -> void:
	if debug_mesh and debug_mesh.visible:
		# Get the current rotation and apply the Y rotation
		var current_rot = debug_mesh.global_rotation
		debug_mesh.global_rotation = Vector3(current_rot.x, current_rotation, current_rot.z)
