## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## - Interactable Script
## this is is a parent class for many objects
## having this as a parent allows for objects to have mutiple features
## which are essential for gameplay
## main feature being that the player can click on these objects adn there
## will be some sort of reaction
## there is also the ability to flash the outline of an object 

extends CollisionObject3D
class_name Interactable

# This allows for the clicking action the player takes to be sent to a function
# that is set up on the child. This is found on the node and can be accessed in
# the signals tab to easily establish this function.
signal interacted(body)

# turn on and off the objetcs interactivity
@export var is_interactable = true
# Stores materail used for the outline
@export var outline_material: Material
# The mesh that need the be outlined
@export var mesh: MeshInstance3D
# bool to be turned on when an object has the ability to be outlined
# just to make sure there is no errors if not all other fields are filled
@export var has_outline: bool

# variable to know if object is flashimg or not
var _is_flashing: bool = false
# the change between full flash and off flash
var _flash_tween: Tween
# This instance is made to make sure objects dont share the outline material since
# it is the same material for each object
# there is also different flashing and outline material so that changing between
# outlining and flashing is easier
var _instance_outline_material: Material  # Each object gets its own copy!
var _instance_flashing_material: Material  # Each object gets its own copy!
# this is more so if the object is flashing and needs to be outlined so the flash will
# be disabled
var _flash_visible: bool = false  # Controls whether flash is visible
# this is so if the object was outlined and needs to go back to flashing
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

# interact
# this function is what is called when clicked by player
# it checks if it is interactable if it is then it goes throught
# with the _on_interacted function for that object
func interact(body):
	if is_interactable == false:
		pass
	else:
		interacted.emit(body)
		
# _on_interaction_complete
# turns off interactablity for an object
func _on_interaction_complete() -> void:
	is_interactable = false
	
# show_outline
# turns on the outline for an object
func show_outline() -> bool:
	if has_outline == true and _instance_outline_material:
		# Hide flash by setting alpha to 0
		_set_flash_visible(false)
		# Show outline material
		mesh.material_overlay = _instance_outline_material
		return true
	return false
	
# hide_outline
# turns off outline for an object
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

# _initialize_flash_animation
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

# _update_flash_alpha
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

# _set_flash_visible
# Controls whether flash is visible (alpha > 0) or not (alpha = 0)
func _set_flash_visible(visible: bool) -> void:
	_flash_visible = visible
	
	# If we're setting flash to invisible, force alpha to 0 immediately
	if not visible:
		_apply_material_alpha(_instance_flashing_material, 0.0)

# start_flashing
# Starts showing the flashing effect
func start_flashing() -> void:
	if not has_outline or not _instance_flashing_material or not mesh:
		return
	
	_is_flashing = true
	_should_be_flashing = true
	_set_flash_visible(true)
	
	# Apply our flashing material
	mesh.material_overlay = _instance_flashing_material

# stop_flashing 
# Stops showing the flashing effect (but keeps animation running)
func stop_flashing() -> void:
	if not _is_flashing:
		return
	
	_is_flashing = false
	_should_be_flashing = false
	_set_flash_visible(false)
	
	# Hide the material overlay
	mesh.material_overlay = null

# _set_outline_material_alpha
# Set outline material alpha
func _set_outline_material_alpha(alpha: float) -> void:
	if not _instance_outline_material:
		return
	_apply_material_alpha(_instance_outline_material, alpha)

# _apply_material_alpha
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

# is_flashing
# Check if currently flashing
func is_flashing() -> bool:
	return _is_flashing

# _exit_tree
# Clean up when node exits
func _exit_tree() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
		
# toggle_interactable
# takes in a bool parameter and sets 
# is_interactable to that
func toggle_interactable(state: bool):
	is_interactable = state
