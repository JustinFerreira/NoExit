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
@export var darken_background: bool = true
@export var fade_out_duration: float = 1.0   # seconds for fade‑out

# Layer for the debug mesh (will not be darkened)
const EXAM_LAYER = 2

# Data for fading background objects
var background_objects: Array[MeshInstance3D] = []
var background_tweens: Array[Tween] = []          # all tweens (fade‑in & fade‑out)
var fade_out_tweens: Array[Tween] = []            # only fade‑out tweens (to wait for)
var original_overrides: Dictionary                # MeshInstance3D -> original material_override
var dark_materials: Dictionary                    # MeshInstance3D -> duplicated dark material

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
# Background darkening with fade in/out
# ------------------------------------------------------------------
func _darken_layer1_objects_fade_in() -> void:
	# Kill any existing background tweens
	_cleanup_background_darkening()
	
	var root = get_tree().root
	_traverse_and_darken_fade(root)

func _traverse_and_darken_fade(node: Node) -> void:
	if node is MeshInstance3D and (node.layers & 1):
		# Get the effective material we should base our dark material on
		var source_mat: Material = node.material_override
		if not source_mat and node.mesh and node.mesh.get_surface_count() > 0:
			source_mat = node.mesh.surface_get_material(0)
		
		# If the source is not StandardMaterial3D, skip darkening for this object.
		if source_mat and not (source_mat is StandardMaterial3D):
			# Could extend support later; for now, leave it untouched.
			pass
		else:
			# Create a duplicate of the source (or a new default material)
			var dark_mat: StandardMaterial3D
			if source_mat is StandardMaterial3D:
				dark_mat = source_mat.duplicate()
			else:
				# No suitable source – create a simple white material
				dark_mat = StandardMaterial3D.new()
				dark_mat.albedo_color = Color.WHITE
				# Try to preserve texture if possible
				if node.mesh and node.mesh.get_surface_count() > 0:
					var surf_mat = node.mesh.surface_get_material(0)
					if surf_mat is StandardMaterial3D:
						dark_mat.albedo_texture = surf_mat.albedo_texture
						dark_mat.albedo_color = surf_mat.albedo_color
			
			# Store original override to restore later
			original_overrides[node] = node.material_override
			
			# Assign our new material as override
			node.material_override = dark_mat
			dark_materials[node] = dark_mat
			
			# Determine start and end colors
			var start_color = dark_mat.albedo_color
			var end_color = start_color * 0.1   # 90% darker
			
			# Create tween
			var tween = create_tween()
			tween.tween_property(dark_mat, "albedo_color", end_color, 1.0) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			background_tweens.append(tween)
			background_objects.append(node)
	
	# Recurse children
	for child in node.get_children():
		_traverse_and_darken_fade(child)

func _restore_layer1_objects_fade_out() -> void:
	# Kill any remaining fade‑in tweens
	for t in background_tweens:
		if t and t.is_running():
			t.kill()
	background_tweens.clear()
	fade_out_tweens.clear()
	
	# Start fade‑out for each background object
	for obj in background_objects:
		if not is_instance_valid(obj):
			continue
		var mat = dark_materials.get(obj) as StandardMaterial3D
		if not mat:
			continue
		
		# Determine the original color we need to fade back to
		var original_override = original_overrides.get(obj)
		var original_color: Color
		if original_override is StandardMaterial3D:
			original_color = original_override.albedo_color
		else:
			# Try to get color from mesh's surface material
			if obj.mesh and obj.mesh.get_surface_count() > 0:
				var surf_mat = obj.mesh.surface_get_material(0)
				if surf_mat is StandardMaterial3D:
					original_color = surf_mat.albedo_color
				else:
					original_color = Color.WHITE
			else:
				original_color = Color.WHITE
		
		# Tween back to original color
		var tween = create_tween()
		tween.tween_property(mat, "albedo_color", original_color, fade_out_duration) \
			.set_ease(Tween.EASE_IN_OUT)
		tween.finished.connect(_on_background_fade_out_complete.bind(obj, mat, original_override, tween), CONNECT_ONE_SHOT)
		background_tweens.append(tween)
		fade_out_tweens.append(tween)

func _on_background_fade_out_complete(obj: MeshInstance3D, mat: Material, original_override: Material, tween: Tween) -> void:
	if is_instance_valid(obj):
		# Restore original material_override (may be null)
		obj.material_override = original_override
	# Remove our references
	background_objects.erase(obj)
	dark_materials.erase(obj)
	original_overrides.erase(obj)
	background_tweens.erase(tween)
	fade_out_tweens.erase(tween)

func _cleanup_background_darkening() -> void:
	# Kill all tweens
	for t in background_tweens:
		if t and t.is_running():
			t.kill()
	background_tweens.clear()
	fade_out_tweens.clear()
	
	# Immediately restore original overrides
	for obj in background_objects:
		if is_instance_valid(obj):
			var orig = original_overrides.get(obj)
			obj.material_override = orig
	
	background_objects.clear()
	dark_materials.clear()
	original_overrides.clear()

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
	
	if _should_store:
		# Storable: debug mesh disappears instantly
		debug_mesh.visible = false
		# Re-enable collision (original object is still hidden, but it's fine)
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
		# Do not hide debug mesh yet; collision remains disabled until return completes
	
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
	
	# Wait for all fade‑out tweens to finish (if any)
	if not fade_out_tweens.is_empty():
		for t in fade_out_tweens:
			if t and t.is_running():
				await t.finished
	
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
