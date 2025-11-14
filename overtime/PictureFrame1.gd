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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Store original transform
	original_position = global_position
	original_rotation = global_rotation  # Use global_rotation instead of rotation
	original_scale = scale
	print("Stored original position: ", original_position)
	
	# Print some debug info about the node
	print("Node name: ", name)
	print("Node type: ", get_class())
	print("Parent: ", get_parent().name if get_parent() else "None")
	
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
		print("Debug mesh created with exported mesh")
	else:
		# Fallback to searching for a mesh
		var found_mesh = _find_original_mesh()
		if found_mesh:
			debug_mesh.mesh = found_mesh.mesh
			print("Debug mesh created with found mesh")
		else:
			# Final fallback to a box mesh
			debug_mesh.mesh = BoxMesh.new()
			debug_mesh.scale = Vector3(0.5, 0.5, 0.1)
			print("Using fallback debug mesh")
	
	# Apply the material if provided
	if target_material:
		debug_mesh.material_override = target_material
		print("Applied exported material to debug mesh")
	
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
	# Prevent multiple simultaneous interactions
	if is_in_interaction:
		return
	
	is_in_interaction = true
	print("=== INTERACTION STARTED ===")
	print("Interaction started with: ", body)
	
	# Get the player's camera
	var camera = PlayerManager.player.CAMERA
	if not camera:
		print("ERROR: Could not find camera at path PlayerManager.player.CAMERA")
		is_in_interaction = false
		return
	
	print("Camera position: ", camera.global_position)
	print("Camera rotation: ", camera.rotation)
	
	# Calculate position directly in front of the camera
	var camera_transform = camera.global_transform
	var focus_offset = camera_transform.basis.z * -focus_distance  # Adjustable distance in front of camera
	var focus_position = camera_transform.origin + focus_offset
	
	# Adjust height with vertical offset
	focus_position.y = camera_transform.origin.y + vertical_offset
	
	print("Moving from: ", global_position, " to: ", focus_position)
	print("Distance: ", global_position.distance_to(focus_position))
	
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
		print("Collision disabled")
	
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
	
	# Apply rotation intensity
	if rotation_intensity < 1.0:
		var current_rotation = debug_mesh.global_rotation
		target_rotation = current_rotation.lerp(target_rotation, rotation_intensity)
	
	tween.tween_property(debug_mesh, "global_rotation", target_rotation, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Scale up the debug mesh with adjustable multiplier
	tween.tween_property(debug_mesh, "scale", original_scale * scale_multiplier, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Connect to tween for debugging
	tween.finished.connect(_on_focus_tween_finished)
	
	PlayerManager.CharacterDialog("Wow I love that picture!")
	
	# Wait for dialog and then return
	print("Waiting for dialog to finish...")
	await get_tree().create_timer(3.0).timeout
	
	# Return to original position
	await _return_to_original()
	
	is_in_interaction = false

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

func _on_focus_tween_finished():
	print("Focus tween finished - Position: ", debug_mesh.global_position, " Scale: ", debug_mesh.scale)

func _return_to_original() -> void:
	print("Returning to original position")
	
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
		print("Collision re-enabled")
	
	print("Interaction completed")
	print("Final position: ", global_position, " Final scale: ", scale)
	print("=== INTERACTION ENDED ===\n")
