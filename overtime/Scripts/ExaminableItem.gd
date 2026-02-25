## No Exit
## Overtime Studios
## Last updated 2/24/26 by Justin Ferreira
## Examinable Item Script
## - Brings item close to camera, allows rotation
## - Darkens all layer‑1 objects (background) by 90% with a fade in/out
## - Debug mesh (layer 2) stays bright during examination
## - On exit: storable items vanish instantly; regular items animate back to place
## - UI is unaffected

extends Interactable
class_name ExaminableItem

# Store original transform
var original_position: Vector3
var original_rotation: Vector3
var original_scale: Vector3

# Tween for animations
var tween: Tween
var debug_mesh: MeshInstance3D
var _return_tween: Tween   # return animation for non‑storable items

# Export mesh/material to match original
@export var target_mesh: Mesh
@export var target_material: Material
@export var target_scale: Vector3 = Vector3.ONE

# Focus behaviour
@export var focus_distance: float = 0.99
@export var vertical_offset: float = -0.75
@export var rotation_intensity: float = 1.0
@export var scale_multiplier: float = 1.5

# Interaction state
var is_in_interaction: bool = false
var should_stay_in_focus: bool = false

# Rotation
@export var rotation_speed: float = 35.0
var current_rotation: float = 0.0

# Dialog and behaviour
@export var player_manager_reference: String = ""
@export var animation_name: String = ""
@export var animation_fade_player: AnimationPlayer
@export var first_time_hint: String = "Press A, D or the Left, Right arrow keys to rotate object while examing"
@export var normal_dialog: String = "I like this item!"
@export var keys_hint_dialog: String = "I should grab my keys and get out of here"
@export var can_be_stored: bool = false

# Darkening toggle – if false, no background darkening is applied
@export var darken_background: bool = false
@export var fade_duration: float = 1.0   # seconds for fade in/out

# Layer for the debug mesh (will not be darkened)
const EXAM_LAYER = 2

# Data for fading background objects
var background_objects: Array[MeshInstance3D] = []
var active_tweens: Array[Tween] = []              # All active tweens
var original_materials: Dictionary                 # MeshInstance3D -> original material override
var dark_materials: Dictionary                     # MeshInstance3D -> duplicated dark material
var fade_out_completed: Dictionary                  # Track which objects have finished fade-out

# Internal flag: true if the item should be stored/picked up after fade‑out
var _should_store: bool = false

func _ready() -> void:
	super._ready()
	if player_manager_reference != "":
		PlayerManager.set(player_manager_reference, self)
	
	original_position = global_position
	original_rotation = global_rotation
	original_scale = scale
	
	_create_debug_mesh()

func _process(delta: float) -> void:
	if PlayerManager.EquippedItem == "Box" and can_be_stored and not PlayerManager.examining and get_parent().visible and not PlayerManager.player.interact_ray.get_collider() == self:
		start_flashing()
	else:
		stop_flashing()

func _create_debug_mesh() -> void:
	# Remove old debug mesh
	for child in get_children():
		if child.name == "DebugMesh":
			child.queue_free()
	
	debug_mesh = MeshInstance3D.new()
	debug_mesh.name = "DebugMesh"
	
	if target_mesh:
		debug_mesh.mesh = target_mesh
	else:
		var found_mesh = _find_original_mesh()
		if found_mesh:
			debug_mesh.mesh = found_mesh.mesh
		else:
			debug_mesh.mesh = BoxMesh.new()
			debug_mesh.scale = Vector3(0.5, 0.5, 0.1)
	
	if target_material:
		debug_mesh.material_override = target_material
	
	if target_scale != Vector3.ONE:
		debug_mesh.scale = target_scale
	
	debug_mesh.layers = 1 << EXAM_LAYER
	debug_mesh.visible = false
	
	add_child(debug_mesh)

func _find_original_mesh() -> MeshInstance3D:
	return _find_mesh_in_children(self)

func _find_mesh_in_children(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.name != "DebugMesh":
		return node
	for child in node.get_children():
		var result = _find_mesh_in_children(child)
		if result:
			return result
	return null

func _on_interacted(body: Variant) -> void:
	if is_in_interaction:
		# Force end current examination
		_force_end_examination()
	
	PlayerManager.ExamingItem = self
	if animation_name != "" and animation_fade_player:
		animation_fade_player.play(animation_name)
	
	if is_in_interaction:
		return
	
	PlayerManager.examining = true
	PlayerManager.player.CURSOR.visible = false
	is_in_interaction = true
	should_stay_in_focus = true
	_should_store = false   # reset
	fade_out_completed.clear()
	
	var camera = PlayerManager.player.CAMERA
	if not camera:
		is_in_interaction = false
		should_stay_in_focus = false
		return
	
	# --- Start darkening background with fade in ---
	if darken_background:
		_darken_layer1_objects_fade_in()
	
	# Hide this item's original meshes, show debug mesh
	_hide_meshes_in_children(self)
	debug_mesh.global_position = global_position
	debug_mesh.global_rotation = global_rotation
	debug_mesh.scale = scale
	debug_mesh.visible = true
	
	# Disable collision
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = true
	
	# Position debug mesh in front of camera
	var camera_transform = camera.global_transform
	var focus_offset = camera_transform.basis.z * -focus_distance
	var focus_position = camera_transform.origin + focus_offset
	focus_position.y = camera_transform.origin.y + vertical_offset
	
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(debug_mesh, "global_position", focus_position, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Face camera
	var camera_pos = camera.global_position
	var dir_to_camera = (camera_pos - focus_position).normalized()
	var target_basis = Basis()
	target_basis.z = dir_to_camera
	target_basis.y = Vector3.UP
	target_basis.x = target_basis.y.cross(target_basis.z).normalized()
	target_basis = target_basis.orthonormalized()
	var target_rotation = target_basis.get_euler()
	target_rotation.y -= PI/2
	current_rotation = target_rotation.y
	
	if rotation_intensity < 1.0:
		var current_rot = debug_mesh.global_rotation
		target_rotation = current_rot.lerp(target_rotation, rotation_intensity)
	
	tween.tween_property(debug_mesh, "global_rotation", target_rotation, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(debug_mesh, "scale", original_scale * scale_multiplier, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Dialog
	if not PlayerManager.examed:
		PlayerManager.CharacterHintDialog(normal_dialog, first_time_hint)
		PlayerManager.examed = true
	elif PlayerManager.DeskItems.size() == 3 and not PlayerManager.has_item("Car Keys"):
		PlayerManager.CharacterHintDialog(normal_dialog, keys_hint_dialog)
	else:
		PlayerManager.CharacterDialog(normal_dialog)
	
	# Wait for focus to end
	while should_stay_in_focus:
		await get_tree().create_timer(0.1).timeout
	
	# Now proceed to end sequence (fade‑out + optional return animation)
	await _end_examination()

# ------------------------------------------------------------------
# Background darkening with smooth fade in/out
# ------------------------------------------------------------------
func _darken_layer1_objects_fade_in() -> void:
	# Kill any existing background tweens
	_cleanup_background_darkening()
	
	var root = get_tree().root
	_traverse_and_create_dark_materials(root)
	
	# Now fade all dark materials to 10% brightness
	for obj in background_objects:
		var dark_mat = dark_materials.get(obj) as StandardMaterial3D
		if dark_mat:
			var tween = create_tween()
			tween.tween_property(dark_mat, "albedo_color", dark_mat.albedo_color * 0.1, fade_duration) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
			active_tweens.append(tween)

func _traverse_and_create_dark_materials(node: Node) -> void:
	if node is MeshInstance3D and (node.layers & 1):
		# Store original material override
		original_materials[node] = node.material_override
		
		# Create a dark material based on the source
		var dark_mat = _create_dark_material_from_source(node)
		if dark_mat:
			# Start at full brightness
			dark_mat.albedo_color = dark_mat.albedo_color * 1.0
			node.material_override = dark_mat
			dark_materials[node] = dark_mat
			background_objects.append(node)
	
	# Recurse children
	for child in node.get_children():
		_traverse_and_create_dark_materials(child)

func _create_dark_material_from_source(node: MeshInstance3D) -> StandardMaterial3D:
	var source_mat: Material = node.material_override
	
	# If no override, try to get material from mesh surface
	if not source_mat and node.mesh and node.mesh.get_surface_count() > 0:
		source_mat = node.mesh.surface_get_material(0)
	
	# Create appropriate dark material
	if source_mat is StandardMaterial3D:
		# Duplicate StandardMaterial3D to preserve all properties
		var dark_mat = source_mat.duplicate()
		return dark_mat
	else:
		# Create a new material that attempts to match the appearance
		var dark_mat = StandardMaterial3D.new()
		dark_mat.albedo_color = Color.WHITE
		dark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		
		# Try to extract texture if available
		if source_mat and source_mat.has_method("get_albedo_texture"):
			dark_mat.albedo_texture = source_mat.albedo_texture
		elif node.mesh and node.mesh.get_surface_count() > 0:
			var surf_mat = node.mesh.surface_get_material(0)
			if surf_mat is StandardMaterial3D:
				dark_mat.albedo_texture = surf_mat.albedo_texture
				dark_mat.albedo_color = surf_mat.albedo_color
		
		return dark_mat

func _restore_layer1_objects_fade_out() -> void:
	# Kill any remaining fade‑in tweens
	for t in active_tweens:
		if t and t.is_running():
			t.kill()
	active_tweens.clear()
	
	# Start fade‑out for each background object
	for obj in background_objects:
		if not is_instance_valid(obj):
			continue
		
		var dark_mat = dark_materials.get(obj) as StandardMaterial3D
		if not dark_mat:
			continue
		
		# Store reference to original material
		var original_mat = original_materials.get(obj)
		
		# CRITICAL FIX: Create a blend material or use modulate property if available
		# Option 1: If using shader material, we can use modulate
		if dark_mat is ShaderMaterial:
			var tween = create_tween()
			tween.tween_property(dark_mat, "shader_parameter/modulate", Color(1,1,1,1), fade_duration) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
			
			tween.finished.connect(_on_single_fade_out_complete.bind(obj, tween, original_mat), CONNECT_ONE_SHOT)
		
		# Option 2: For StandardMaterial3D, we need to interpolate between colors
		else:
			# Get original color
			var target_color: Color = Color.WHITE
			if original_mat is StandardMaterial3D:
				target_color = original_mat.albedo_color
			elif obj.mesh and obj.mesh.get_surface_count() > 0:
				var surf_mat = obj.mesh.surface_get_material(0)
				if surf_mat is StandardMaterial3D:
					target_color = surf_mat.albedo_color
			
			# Fade from current dark color to target color
			var tween = create_tween()
			tween.tween_property(dark_mat, "albedo_color", target_color, fade_duration) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
			
			# Also fade emission and other properties if needed for smoothness
			if dark_mat.emission_enabled:
				var target_emission = Color.BLACK
				if original_mat is StandardMaterial3D:
					target_emission = original_mat.emission
				tween.parallel().tween_property(dark_mat, "emission", target_emission, fade_duration)
			
			tween.finished.connect(_on_single_fade_out_complete.bind(obj, tween, original_mat), CONNECT_ONE_SHOT)
		
		active_tweens.append(tween)

func _on_single_fade_out_complete(obj: MeshInstance3D, tween: Tween, original_mat: Material) -> void:
	if not is_instance_valid(obj):
		return
	
	# Mark this object as completed
	fade_out_completed[obj] = true
	
	# Smooth transition: restore original material override
	obj.material_override = original_mat
	
	# Clean up references for this object
	dark_materials.erase(obj)
	original_materials.erase(obj)
	background_objects.erase(obj)
	active_tweens.erase(tween)

func _cleanup_background_darkening() -> void:
	# Kill all tweens
	for t in active_tweens:
		if t and t.is_running():
			t.kill()
	active_tweens.clear()
	
	# Immediately restore original overrides
	for obj in background_objects:
		if is_instance_valid(obj):
			var orig = original_materials.get(obj)
			obj.material_override = orig
	
	background_objects.clear()
	dark_materials.clear()
	original_materials.clear()
	fade_out_completed.clear()

# ------------------------------------------------------------------
# End focus
# ------------------------------------------------------------------
func end_focus() -> void:
	PlayerManager.examining = false
	PlayerManager.player.CURSOR.visible = true
	should_stay_in_focus = false
	
	# Determine if this item should be stored/picked up
	if (PlayerManager.EquippedItem == "Box" and can_be_stored) or player_manager_reference == "Keys":
		_should_store = true
		
		# Play sound immediately
		if PlayerManager.EquippedItem == "Box" and can_be_stored:
			AudioManager.play_sound(AudioManager.ItemPickup)
		elif player_manager_reference == "Keys":
			AudioManager.play_sound(AudioManager.keys)
	
	# CRITICAL FIX: Kill any existing return tween
	if _return_tween and _return_tween.is_running():
		_return_tween.kill()
	
	if _should_store:
		# Storable: debug mesh disappears instantly
		debug_mesh.visible = false
		# Hide original meshes too? Actually we want to hide the entire parent later
		if has_node("CollisionShape3D"):
			$CollisionShape3D.disabled = false
	else:
		# Regular item: start return animation for debug mesh
		_return_tween = create_tween()
		_return_tween.set_parallel(true)
		_return_tween.tween_property(debug_mesh, "global_position", original_position, 1.0) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_return_tween.tween_property(debug_mesh, "global_rotation", original_rotation, 1.0) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_return_tween.tween_property(debug_mesh, "scale", original_scale, 1.0) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_return_tween.finished.connect(_on_return_tween_finished, CONNECT_ONE_SHOT)
	
	# Start background fade‑out (if enabled)
	if darken_background:
		_restore_layer1_objects_fade_out()

# ------------------------------------------------------------------
# End examination sequence (called after focus ends)
# ------------------------------------------------------------------
func _end_examination() -> void:
	# Wait for return animation if it exists (non‑storable items)
	if _return_tween and _return_tween.is_running():
		await _return_tween.finished
	
	# Wait for all fade‑out tweens to finish
	# Instead of waiting for each tween individually, wait until all objects are restored
	while not background_objects.is_empty():
		await get_tree().process_frame
	
	# Now finalize based on item type
	if _should_store:
		# Item is being stored or picked up – hide its parent
		_show_original_object()   # though it will be hidden by parent visibility
		if has_node("CollisionShape3D"):
			$CollisionShape3D.disabled = true
		
		# Handle storage/pickup
		if PlayerManager.EquippedItem == "Box" and can_be_stored:
			_on_interaction_complete()
			PlayerManager.DeskItems.append(self)
			get_parent().visible = false
			AudioManager.play_sound(AudioManager.ItemPickup)
		elif player_manager_reference == "Keys":
			_on_interaction_complete()
			get_parent().visible = false
			AudioManager.play_sound(AudioManager.keys)
		else:
			# Fallback (should not happen)
			if animation_name != "" and animation_fade_player:
				animation_fade_player.play_backwards(animation_name)
	else:
		# Regular examination – return completed, now show original object
		debug_mesh.visible = false
		_show_original_object()
		# Re-enable collision
		if has_node("CollisionShape3D"):
			$CollisionShape3D.disabled = false
		# Play reverse animation if any
		if animation_name != "" and animation_fade_player:
			animation_fade_player.play_backwards(animation_name)
	
	is_in_interaction = false

# ------------------------------------------------------------------
# Helper functions for hiding/showing original meshes
# ------------------------------------------------------------------
func _hide_meshes_in_children(node: Node) -> void:
	if node is MeshInstance3D and node.name != "DebugMesh":
		node.visible = false
	for child in node.get_children():
		_hide_meshes_in_children(child)

func _show_original_object() -> void:
	_show_meshes_in_children(self)

func _show_meshes_in_children(node: Node) -> void:
	if node is MeshInstance3D and node.name != "DebugMesh":
		node.visible = true
	for child in node.get_children():
		_show_meshes_in_children(child)

# Rotation functions
func rotate_right() -> void:
	if not is_in_interaction or not debug_mesh.visible:
		return
	current_rotation += rotation_speed * get_process_delta_time()
	_apply_rotation()

func rotate_left() -> void:
	if not is_in_interaction or not debug_mesh.visible:
		return
	current_rotation -= rotation_speed * get_process_delta_time()
	_apply_rotation()

func _apply_rotation() -> void:
	if debug_mesh and debug_mesh.visible:
		var current_rot = debug_mesh.global_rotation
		debug_mesh.global_rotation = Vector3(current_rot.x, current_rotation, current_rot.z)

func _force_end_examination() -> void:
	# Force cleanup of current examination
	should_stay_in_focus = false
	
	# Kill all tweens
	if tween and tween.is_running():
		tween.kill()
	if _return_tween and _return_tween.is_running():
		_return_tween.kill()
	
	# Clean up background darkening
	_cleanup_background_darkening_immediate()
	
	# Hide debug mesh and show original
	if debug_mesh:
		debug_mesh.visible = false
	_show_original_object()
	
	# Re-enable collision
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = false
	
	is_in_interaction = false

func _cleanup_background_darkening_immediate() -> void:
	# Kill all tweens
	for t in active_tweens:
		if t and t.is_running():
			t.kill()
	active_tweens.clear()
	
	# IMMEDIATELY restore original overrides without fade
	for obj in background_objects:
		if is_instance_valid(obj):
			var orig = original_materials.get(obj)
			obj.material_override = orig
	
	background_objects.clear()
	dark_materials.clear()
	original_materials.clear()
	fade_out_completed.clear()

func _on_return_tween_finished() -> void:
	# Only hide debug mesh if we're still in a valid state
	if not _should_store and is_instance_valid(debug_mesh):
		debug_mesh.visible = false
