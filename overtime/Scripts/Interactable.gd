extends CollisionObject3D
class_name Interactable

signal interacted(body)

@export var is_interactable = true
@export var outline_material: Material
@export var mesh: MeshInstance3D
@export var has_outline: bool

var _is_flashing: bool = false
var _flash_tween: Tween
var _instance_outline_material: Material  # Each object gets its own copy!
var _instance_flashing_material: Material  # Each object gets its own copy!
var _flash_visible: bool = false  # Controls whether flash is visible
var _should_be_flashing: bool = false  # Track if object should be in flashing state

func _ready():
	# Create unique instances of the outline materials for this object
	if outline_material:
		_instance_outline_material = outline_material.duplicate()
		_instance_flashing_material = outline_material.duplicate()
		# Set outline material to full visibility
		_set_outline_material_alpha(1.0)
		# Initialize flash animation (running continuously)
		_initialize_flash_animation()
		# Start with flash invisible
		_set_flash_visible(false)

func interact(body):
	if is_interactable == false:
		pass
	else:
		interacted.emit(body)
		
func _on_interaction_complete() -> void:
	is_interactable = false
	
func show_outline() -> bool:
	if has_outline == true and _instance_outline_material:
		# Hide flash by setting alpha to 0
		_set_flash_visible(false)
		# Show outline material
		mesh.material_overlay = _instance_outline_material
		return true
	return false
	
func hide_outline() -> void: 
	if has_outline == true:
		if _should_be_flashing:  # If object should be flashing
			# Make flash visible again
			_set_flash_visible(true)
			# Show flashing material
			mesh.material_overlay = _instance_flashing_material
		else:
			# Nothing to show
			mesh.material_overlay = null

# Initialize the flash animation (runs continuously from scene start)
func _initialize_flash_animation() -> void:
	if not _instance_flashing_material:
		return
	
	# Clean up any existing tween
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	
	# Create new tween
	_flash_tween = create_tween()
	_flash_tween.set_loops()  # Loop indefinitely
	
	# Start with alpha at 0 (transparent)
	_apply_material_alpha(_instance_flashing_material, 0.0)
	
	# Animate alpha from 0 to 1 and back over 2 seconds
	# This lambda function will be called by the tween with the current alpha value
	_flash_tween.tween_method(
		_update_flash_alpha, 
		0.0, 1.0, 1.0)
	
	_flash_tween.tween_method(
		_update_flash_alpha,
		1.0, 0.0, 1.0)

# Update flash alpha based on current visibility state
func _update_flash_alpha(alpha: float) -> void:
	if not _instance_flashing_material:
		return
	
	if _flash_visible:
		# If flash should be visible, apply the animated alpha
		_apply_material_alpha(_instance_flashing_material, alpha)
	else:
		# If flash should be hidden, force alpha to 0
		_apply_material_alpha(_instance_flashing_material, 0.0)

# Controls whether flash is visible (alpha > 0) or not (alpha = 0)
func _set_flash_visible(visible: bool) -> void:
	_flash_visible = visible
	
	# If we're setting flash to invisible, force alpha to 0 immediately
	if not visible:
		_apply_material_alpha(_instance_flashing_material, 0.0)

# Starts showing the flashing effect
func start_flashing() -> void:
	if not has_outline or not _instance_flashing_material or not mesh:
		return
	
	_is_flashing = true
	_should_be_flashing = true
	_set_flash_visible(true)
	
	# Apply our flashing material
	mesh.material_overlay = _instance_flashing_material

# Stops showing the flashing effect (but keeps animation running)
func stop_flashing() -> void:
	if not _is_flashing:
		return
	
	_is_flashing = false
	_should_be_flashing = false
	_set_flash_visible(false)
	
	# Hide the material overlay
	mesh.material_overlay = null

# Set outline material alpha
func _set_outline_material_alpha(alpha: float) -> void:
	if not _instance_outline_material:
		return
	_apply_material_alpha(_instance_outline_material, alpha)

# Generic function to apply alpha to any material
func _apply_material_alpha(material: Material, alpha: float) -> void:
	if not material:
		return
	
	# For StandardMaterial3D
	if material is StandardMaterial3D:
		var color = material.albedo_color
		color.a = alpha
		material.albedo_color = color
	
	# For ShaderMaterial
	elif material is ShaderMaterial:
		# Try common color parameters
		var color_params = ["albedo", "color", "tint_color", "outline_color", "line_color", "_color"]
		for param in color_params:
			var color = material.get_shader_parameter(param)
			if color is Color:
				color.a = alpha
				material.set_shader_parameter(param, color)
				break

# Check if currently flashing
func is_flashing() -> bool:
	return _is_flashing

# Clean up when node exits
func _exit_tree() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
		
func toggle_interactable(state: bool):
	is_interactable = state
