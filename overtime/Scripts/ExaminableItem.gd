## No Exit
## Overtime Studios
## Last updated 10/18/26 by Justin Ferreira
## Examinable Item Script
## - Generic "click to look at it" item. Brings a copy of the item's mesh in
##   front of the camera, lets the player rotate it, then either puts it back
##   or picks it up.
## - Everything is set up from the Inspector - most items need NO script of
##   their own. See the groups below.
##
## ---------------------------------------------------------------------
## HOW TO MAKE A NEW EXAMINABLE ITEM
## ---------------------------------------------------------------------
## 1. Scene layout (same as every existing item):
##      ItemRoot (Node3D)
##        └ ItemMesh (MeshInstance3D)
##            └ StaticBody3D   <- put ExaminableItem.gd (or a child script) here
##                └ CollisionShape3D
## 2. On the StaticBody3D set:
##      - Interactable > has_outline     = on (the mesh fills in
##        automatically from the parent ItemMesh)
##      - Examine > examine_dialog       = what the player says
## 3. Optional: fill in the Pickup / Flashing / Spawn groups.
## That's it. You do NOT need to:
##      - connect the `interacted` signal (done automatically)
##      - add a var to PlayerManager or set player_manager_reference
##      - add the item to PlayerManager.EndFocus()
##      - make a fade AnimationPlayer
##
## Need custom behaviour? `extends ExaminableItem` and override the hooks at
## the bottom of this file (_can_examine, _on_examine_started, _on_picked_up,
## _should_flash, ...). Don't override _on_interacted / _process unless you
## call super.

extends Interactable
class_name ExaminableItem

## Emitted when the item starts flying to the camera.
signal examine_started
## Emitted once the item is fully back in place (or picked up).
signal examine_ended
## Emitted when the item is put in the inventory / stored in the box.
signal picked_up

## ---------------------------------------------------------------------
## Global toggles - flip these to try things out across every item.
## ---------------------------------------------------------------------

## Spin items once while they fly up to the camera. Every item uses this
## unless its own spin_mode overrides it. Can also be flipped at runtime:
## ExaminableItem.spin_enabled = false
static var spin_enabled: bool = true

enum SpinMode { USE_GLOBAL, ALWAYS, NEVER }
enum SizeMode { FIT_TO_SCREEN, MULTIPLY_ORIGINAL }
enum FlashMode { NEVER, UNTIL_PICKED_UP, WHEN_BOX_EQUIPPED }
enum SpawnCondition { ALWAYS, LOOP_0_ONLY, AFTER_LOOP_0 }

## ---------------------------------------------------------------------
## Examine
## ---------------------------------------------------------------------
@export_group("Examine")
## What the player says when they look at this.
@export_multiline var examine_dialog: String = "I like this item!"
## If set, examine_dialog is read from this EventManager variable instead
## (e.g. "stapler_normal_dialog"). Keeps all dialog in one place.
@export var dialog_from_event_manager: String = ""
## Shown alongside the dialog the very first time the player examines anything.
@export var first_time_hint: String = "Press A, D or the arrow keys to rotate the object, W, S to tilt it"
## Shown when the desk is cleared but the keys are still out.
@export var keys_hint_dialog: String = "I should grab my keys and get out of here"
## Dim the rest of the world while examining.
@export var darken_background: bool = false

@export_group("Examine View")
## How far in front of the camera the item floats.
@export var focus_distance: float = 0.8
## The item spins around (and is centred on) the middle of its model's
## bounding box. If that looks off (handles, lopsided models), add a
## Marker3D child called "ExamineCenter" and drag it to the spot that should
## sit in the middle of the screen - or nudge it here (in the model's own
## units, added on top of either).
@export var examine_center_offset: Vector3 = Vector3.ZERO
## Nudge on screen, as a fraction of the screen (x: -0.5..0.5 left/right,
## y: -0.5..0.5 down/up). (0, 0) is dead centre.
@export var screen_offset: Vector2 = Vector2.ZERO
## FIT_TO_SCREEN sizes every item the same on screen regardless of the
## model's real size. MULTIPLY_ORIGINAL just scales the original by
## scale_multiplier (old behaviour).
@export var size_mode: SizeMode = SizeMode.FIT_TO_SCREEN
## FIT_TO_SCREEN: how much of the screen height the item takes up (0-1).
@export_range(0.05, 0.95) var screen_fill: float = 0.55
## MULTIPLY_ORIGINAL: scale applied to the item's original size.
@export var scale_multiplier: float = 1.5
## Which way the model's "front" points in its own local space. That side
## is turned to face the camera.
@export var front_axis: Vector3 = Vector3.RIGHT
## Extra rotation (degrees, local) applied after facing the camera, for
## models that need a nudge to look right.
@export var examine_rotation_offset: Vector3 = Vector3.ZERO
## Seconds to fly in / fly back.
@export var transition_time: float = 0.8
## Brightness of a light that only shines on the examined item (from the
## player's direction), so it stays readable in dark rooms. 0 = off.
@export var examine_light_energy: float = 1.0

@export_group("Examine Spin")
## USE_GLOBAL follows ExaminableItem.spin_enabled.
@export var spin_mode: SpinMode = SpinMode.USE_GLOBAL
## How many full turns while flying in.
@export var spin_turns: float = 1.0

@export_group("Examine Controls")
## Degrees per second when the player holds left/right.
@export var rotate_speed_degrees: float = 120.0
## Let the player tilt the item with forward/backward (W/S) too.
@export var allow_tilt: bool = true

## ---------------------------------------------------------------------
## Pickup
## ---------------------------------------------------------------------
@export_group("Pickup")
## Picked up when the player closes the examine view.
@export var pickup_on_close: bool = false
## If the player has the Box equipped when closing, the item is stored on
## the desk (GameState remembers it as STORED) instead of being put back.
@export var store_in_box: bool = false
## Added to PlayerManager.Inventory on pickup. Leave empty to not add
## anything (e.g. desk items stored in the box).
@export var inventory_name: String = ""
@export var inventory_weight: float = 0.5
@export var inventory_equippable: bool = false
## Played on pickup. Empty = AudioManager.ItemPickup.
@export var pickup_sound: AudioStream
## Played when the examine starts (e.g. AudioManager.ImportantItemStinger
## for key items). Empty = nothing.
@export var examine_sound: AudioStream
## Node hidden when picked up. Empty = this body's parent (the item mesh).
@export var hide_on_pickup: Node3D

## ---------------------------------------------------------------------
## Flashing / Spawn
## ---------------------------------------------------------------------
@export_group("Flashing")
## UNTIL_PICKED_UP: flashes whenever it can be clicked.
## WHEN_BOX_EQUIPPED: flashes only while the Box is equipped (desk items).
@export var flash_mode: FlashMode = FlashMode.NEVER

@export_group("Spawn")
## Hide and disable this item depending on the loop.
@export var spawn_condition: SpawnCondition = SpawnCondition.ALWAYS

@export_group("Legacy")
## Optional. Still assigned on PlayerManager for old code that looks items
## up by name - no longer needed for examining to work.
@export var player_manager_reference: String = ""
## Overrides for the examine copy. Leave empty to copy the item's own mesh.
@export var target_mesh: Mesh
@export var target_material: Material
@export_group("")

# Old name kept so existing code (EventManager dialog assignments, etc.) works.
var normal_dialog: String:
	get: return examine_dialog
	set(value): examine_dialog = value

## Layer for the examine copy (kept bright when darkening layer 1).
const EXAM_LAYER: int = 2

enum State { IDLE, FLYING_IN, FOCUSED, RETURNING }
var _state: State = State.IDLE

# Kept for old callers - true while the examine view is open.
var is_in_interaction: bool:
	get: return _state != State.IDLE
var should_stay_in_focus: bool:
	get: return _state == State.FLYING_IN or _state == State.FOCUSED

# Examine copy: a pivot at the mesh's visual centre with the mesh under it,
# so moving/rotating/scaling the pivot always happens around the centre.
var _pivot: Node3D
var _exam_mesh: MeshInstance3D
var _exam_light: DirectionalLight3D
var _source_mesh: MeshInstance3D
var _center_local: Vector3 = Vector3.ZERO

var _tween: Tween
var _from: Transform3D           # pivot transform at the start of a tween
var _to_q: Quaternion
var _to_origin: Vector3
var _to_scale: Vector3
var _spin_axis: Vector3 = Vector3.UP
var _spin_angle: float = 0.0
var _anim_q: Quaternion = Quaternion.IDENTITY
var _anim_origin: Vector3
var _anim_scale: Vector3 = Vector3.ONE
var _user_q: Quaternion = Quaternion.IDENTITY   # player's rotation on top

var _home: Transform3D           # pivot transform when sitting in place
var _picking_up: bool = false
var _hidden_meshes: Dictionary = {}   # MeshInstance3D -> [transparency, cast_shadow]

# Background darkening
var _dark_objects: Array[GeometryInstance3D] = []
var _original_overrides: Dictionary = {}
var _dark_tweens: Array[Tween] = []


func _ready() -> void:
	super._ready()
	if not _passes_spawn_condition():
		_remove_from_world()
		return

	if player_manager_reference != "":
		PlayerManager.set(player_manager_reference, self)
	if dialog_from_event_manager != "":
		var text = EventManager.get(dialog_from_event_manager)
		if text is String:
			examine_dialog = text
		else:
			push_warning("%s: EventManager has no String '%s'." % [name, dialog_from_event_manager])

	_source_mesh = _find_source_mesh()
	# The examine copy is built the first time the item is examined, so
	# there's never a stray full-size copy sitting at the world origin.

	# Already picked up / stored earlier (e.g. before an elevator trip)?
	# Deferred so a level that resets GameState in its own _ready() (like
	# the Office starting a new loop) gets to do that first.
	_remove_if_collected.call_deferred()


func _remove_if_collected() -> void:
	if is_inside_tree() and GameState.is_collected(get_persist_id()):
		_remove_from_world()


# _remove_from_world
# Hides the item and makes it dead to clicks - used when it shouldn't be in
# this loop, or was already collected.
func _remove_from_world() -> void:
	if player_manager_reference != "":
		PlayerManager.set(player_manager_reference, null)
	var hide_node := _get_hide_node()
	if hide_node:
		hide_node.visible = false
	_on_interaction_complete()
	set_process(false)


func _process(delta: float) -> void:
	if _should_flash():
		start_flashing()
	else:
		stop_flashing()

	if _state == State.FOCUSED:
		_handle_rotation_input(delta)


func _on_interacted(_body: Variant) -> void:
	if _state != State.IDLE:
		return
	if not _can_examine():
		_on_examine_blocked()
		return
	var camera: Camera3D = PlayerManager.player.CAMERA if PlayerManager.player else null
	if not camera:
		return

	PlayerManager.ExamingItem = self
	PlayerManager.examining = true
	UiManager.set_cursor_visible(false)
	# No outline/flash while the item is off its spot - comes back in
	# _end_examine() once it has settled back down.
	set_outline_blocked(true)
	_picking_up = false
	_user_q = Quaternion.IDENTITY

	# Build the copy BEFORE darkening, so it copies the item's real
	# materials and not the darkened ones.
	if not _pivot:
		_build_exam_copy()
	if darken_background:
		_darken_background()

	# Swap the real mesh for the examine copy at the exact same spot.
	_home = _source_global_pivot()
	_pivot.global_transform = _home
	_hide_source_meshes()
	_exam_mesh.visible = true
	_set_collision_enabled(false)

	_start_fly_in(camera)

	if examine_sound:
		AudioManager.play_sound(examine_sound)
	_show_examine_dialog()
	examine_started.emit()
	_on_examine_started()


## Called by PlayerManager.EndFocus() when the player clicks to close.
func end_focus() -> void:
	if not should_stay_in_focus:
		return
	PlayerManager.examining = false
	PlayerManager.closeup = true
	UiManager.set_cursor_visible(true)

	if darken_background:
		_restore_background()

	if store_in_box and PlayerManager.EquippedItem == "Box":
		GameState.mark_collected(get_persist_id(), GameState.STORED)
		_pick_up()
	elif pickup_on_close:
		GameState.mark_collected(get_persist_id(), GameState.PICKED_UP)
		_pick_up()
	else:
		_start_return()


## ---------------------------------------------------------------------
## Overridable hooks
## ---------------------------------------------------------------------

## Return false to refuse examining right now (see CarKeys).
func _can_examine() -> bool:
	return true

## Called instead of examining when _can_examine() is false.
func _on_examine_blocked() -> void:
	pass

## Shows the examine dialog. Override to say something different.
func _show_examine_dialog() -> void:
	if not PlayerManager.examed:
		PlayerManager.CharacterHintDialog(examine_dialog, first_time_hint)
		PlayerManager.examed = true
	elif PlayerManager.DeskItems.size() == 3 and not PlayerManager.has_item("Car Keys"):
		PlayerManager.CharacterHintDialog(examine_dialog, keys_hint_dialog)
	else:
		PlayerManager.CharacterDialog(examine_dialog)

func _on_examine_started() -> void:
	pass

## Called after the item is added to the inventory / stored.
func _on_picked_up() -> void:
	pass

func _on_examine_finished() -> void:
	pass

## Whether the item should flash this frame. Override for custom rules,
## usually as `return super._should_flash() and <your condition>`.
func _should_flash() -> bool:
	if not is_interactable or PlayerManager.examining:
		return false
	var hide_node := _get_hide_node()
	if hide_node and not hide_node.is_visible_in_tree():
		return false
	# The hover outline takes over while the player is aiming at it.
	if PlayerManager.player and PlayerManager.player.interact_ray.get_collider() == self:
		return false
	match flash_mode:
		FlashMode.UNTIL_PICKED_UP:
			return true
		FlashMode.WHEN_BOX_EQUIPPED:
			return store_in_box and PlayerManager.EquippedItem == "Box"
	return false


## ---------------------------------------------------------------------
## Fly in / out
## ---------------------------------------------------------------------

func _start_fly_in(camera: Camera3D) -> void:
	var cam := camera.global_transform.orthonormalized()
	var cam_right := cam.basis.x
	var cam_up := cam.basis.y
	var cam_back := cam.basis.z   # points from the view toward the camera

	# Position: straight ahead of the camera (screen centre) plus offset.
	var half_h := focus_distance * tan(deg_to_rad(camera.fov) * 0.5)
	var half_w := half_h * _viewport_aspect()
	_to_origin = cam.origin - cam_back * focus_distance \
		+ cam_right * (screen_offset.x * 2.0 * half_w) \
		+ cam_up * (screen_offset.y * 2.0 * half_h)

	# Rotation: front_axis faces the camera, local up matches screen up.
	_to_q = _facing_rotation(cam.basis)

	# Size: fit the item's bounding sphere to part of the screen, so it never
	# clips through the camera however it's rotated.
	var start_scale := _home.basis.get_scale()
	if size_mode == SizeMode.FIT_TO_SCREEN:
		var radius := (_radius_vector() * start_scale).length()
		var k := (screen_fill * half_h) / maxf(radius, 0.0001)
		_to_scale = start_scale * k
	else:
		_to_scale = start_scale * scale_multiplier

	_spin_axis = cam_up
	_spin_angle = TAU * spin_turns if _is_spin_on() else 0.0

	# Light shines from just above/left of the player toward the item.
	if _exam_light:
		_exam_light.global_basis = cam.basis \
			* Basis(Vector3.RIGHT, deg_to_rad(-25.0)) \
			* Basis(Vector3.UP, deg_to_rad(-20.0))

	_state = State.FLYING_IN
	_run_tween(_home, func(): _state = State.FOCUSED)


func _start_return() -> void:
	_state = State.RETURNING
	# Bake the player's rotation into the start so the return is smooth.
	var from := _pivot.global_transform
	_user_q = Quaternion.IDENTITY
	_to_origin = _home.origin
	_to_q = _home.basis.get_rotation_quaternion()
	_to_scale = _home.basis.get_scale()
	_spin_angle = 0.0
	_run_tween(from, _finish_return)


func _run_tween(from: Transform3D, on_done: Callable) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_from = from
	_tween = create_tween()
	_tween.tween_method(_tween_step, 0.0, 1.0, transition_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(on_done, CONNECT_ONE_SHOT)


func _tween_step(t: float) -> void:
	var from_q := _from.basis.get_rotation_quaternion()
	# slerp always takes the shortest way round - no accidental spins.
	_anim_q = from_q.slerp(_to_q, t)
	if _spin_angle != 0.0:
		# Deliberate spin on top. Ends at a whole number of turns so the
		# final rotation is unchanged.
		_anim_q = Quaternion(_spin_axis, _spin_angle * t) * _anim_q
	_anim_origin = _from.origin.lerp(_to_origin, t)
	_anim_scale = _from.basis.get_scale().lerp(_to_scale, t)
	_apply_pivot()


func _apply_pivot() -> void:
	var q := (_user_q * _anim_q).normalized()
	_pivot.global_transform = Transform3D(Basis(q) * Basis.from_scale(_anim_scale), _anim_origin)


func _finish_return() -> void:
	_exam_mesh.visible = false
	_show_source_meshes()
	_set_collision_enabled(true)
	_end_examine()


func _pick_up() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_picking_up = true
	_exam_mesh.visible = false
	_on_interaction_complete()
	var hide_node := _get_hide_node()
	if hide_node:
		hide_node.visible = false
	_show_source_meshes()   # hidden via hide_node now; keep state tidy

	if inventory_name != "":
		PlayerManager.AddToInventory(inventory_name, inventory_weight, inventory_equippable)
	AudioManager.play_sound(pickup_sound if pickup_sound else AudioManager.ItemPickup)

	picked_up.emit()
	mark_success()
	_on_picked_up()
	_end_examine()


func _end_examine() -> void:
	_state = State.IDLE
	set_outline_blocked(false)
	if PlayerManager.ExamingItem == self:
		PlayerManager.ExamingItem = null
	examine_ended.emit()
	_on_examine_finished()


## ---------------------------------------------------------------------
## Player rotation while focused
## ---------------------------------------------------------------------

func _handle_rotation_input(delta: float) -> void:
	var cam: Camera3D = PlayerManager.player.CAMERA
	var speed := deg_to_rad(rotate_speed_degrees) * delta
	var yaw := Input.get_axis("left", "right") * speed
	var pitch := Input.get_axis("forward", "backward") * speed if allow_tilt else 0.0
	if yaw == 0.0 and pitch == 0.0:
		return
	var basis := cam.global_transform.basis.orthonormalized()
	_user_q = Quaternion(basis.y, yaw) * Quaternion(basis.x, pitch) * _user_q
	_apply_pivot()

# Kept for old callers; rotation is now read from Input every frame.
func rotate_left() -> void:
	pass

func rotate_right() -> void:
	pass


## ---------------------------------------------------------------------
## Helpers
## ---------------------------------------------------------------------

func _is_spin_on() -> bool:
	match spin_mode:
		SpinMode.ALWAYS: return true
		SpinMode.NEVER: return false
	return spin_enabled


func _passes_spawn_condition() -> bool:
	match spawn_condition:
		SpawnCondition.LOOP_0_ONLY: return PlayerManager.Loop0
		SpawnCondition.AFTER_LOOP_0: return not PlayerManager.Loop0
	return true


func _facing_rotation(cam_basis: Basis) -> Quaternion:
	var front := front_axis.normalized() if front_axis != Vector3.ZERO else Vector3.RIGHT
	# Pick a local "up" that isn't parallel to front.
	var up := Vector3.UP if absf(front.dot(Vector3.UP)) < 0.99 else Vector3.BACK
	up = (up - front * up.dot(front)).normalized()
	var local := Basis(up.cross(front), up, front)       # local frame
	var view := Basis(cam_basis.x, cam_basis.y, cam_basis.z)  # front -> camera
	var rot := view * local.transposed()
	rot = rot * Basis.from_euler(examine_rotation_offset * (PI / 180.0))
	return rot.get_rotation_quaternion()


func _viewport_aspect() -> float:
	var size := get_viewport().get_visible_rect().size
	return size.x / maxf(size.y, 1.0)


func _get_hide_node() -> Node3D:
	if hide_on_pickup:
		return hide_on_pickup
	return get_parent() as Node3D


func _find_source_mesh() -> MeshInstance3D:
	if mesh:
		return mesh
	if get_parent() is MeshInstance3D:
		return get_parent()
	for child in find_children("*", "MeshInstance3D", true, false):
		return child
	return null


func _build_exam_copy() -> void:
	_pivot = Node3D.new()
	_pivot.name = "ExaminePivot"
	_pivot.top_level = true   # world-space transform, ignores parent
	add_child(_pivot)

	_exam_mesh = MeshInstance3D.new()
	_exam_mesh.name = "ExamineMesh"
	if target_mesh:
		_exam_mesh.mesh = target_mesh
	elif _source_mesh:
		_exam_mesh.mesh = _source_mesh.mesh
	else:
		_exam_mesh.mesh = BoxMesh.new()

	if target_material:
		_exam_mesh.material_override = target_material
	elif _source_mesh:
		_exam_mesh.material_override = _source_mesh.material_override
		for i in _source_mesh.get_surface_override_material_count():
			_exam_mesh.set_surface_override_material(i, _source_mesh.get_surface_override_material(i))

	_exam_mesh.layers = 1 << EXAM_LAYER
	_exam_mesh.visible = false
	_pivot.add_child(_exam_mesh)

	# Light that only hits the examine copy (its own layer). Child of the
	# copy so it shows/hides with it; top_level so the spin doesn't turn it.
	if examine_light_energy > 0.0:
		_exam_light = DirectionalLight3D.new()
		_exam_light.name = "ExamineLight"
		_exam_light.top_level = true
		_exam_light.light_energy = examine_light_energy
		_exam_light.light_cull_mask = 1 << EXAM_LAYER
		_exam_light.shadow_enabled = false
		_exam_light.light_bake_mode = Light3D.BAKE_DISABLED
		_exam_mesh.add_child(_exam_light)

	# Offset the mesh so the pivot sits at its visual centre: the middle of
	# its bounds, or the ExamineCenter marker if the item has one.
	var aabb := _exam_mesh.mesh.get_aabb() if _exam_mesh.mesh else AABB(Vector3.ZERO, Vector3.ONE)
	_center_local = aabb.get_center()
	var marker := _find_examine_center()
	if marker and _source_mesh:
		_center_local = _source_mesh.global_transform.affine_inverse() * marker.global_position
	_center_local += examine_center_offset
	_exam_mesh.position = -_center_local
	# Park it exactly on top of the real item.
	_pivot.global_transform = _source_global_pivot()


## The optional "ExamineCenter" Marker3D: on the item, its mesh, or the
## mesh's parent (wherever it was dropped in the scene).
func _find_examine_center() -> Node3D:
	for holder in [self, _source_mesh, _source_mesh.get_parent() if _source_mesh else null]:
		if holder:
			var m = holder.get_node_or_null("ExamineCenter")
			if m is Node3D:
				return m
	return null


func _radius_vector() -> Vector3:
	# Half-diagonal of the mesh bounds; scaled per-axis by the caller.
	var aabb := _exam_mesh.mesh.get_aabb() if _exam_mesh.mesh else AABB(Vector3.ZERO, Vector3.ONE)
	return aabb.size * 0.5


# Where the pivot sits when the copy exactly overlaps the real mesh.
func _source_global_pivot() -> Transform3D:
	var src := _source_mesh.global_transform if _source_mesh else global_transform
	return src.translated_local(_center_local)


func _hide_source_meshes() -> void:
	_hidden_meshes.clear()
	var meshes: Array[MeshInstance3D] = []
	if _source_mesh:
		meshes.append(_source_mesh)
	meshes.append_array(mesh_list)
	for m in meshes:
		if m and m.visible and not _hidden_meshes.has(m):
			# Hide by transparency, not visibility - the real mesh is usually
			# this body's parent, and hiding it would hide the copy too.
			_hidden_meshes[m] = [m.transparency, m.cast_shadow]
			m.transparency = 1.0
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _show_source_meshes() -> void:
	for m in _hidden_meshes:
		if is_instance_valid(m):
			m.transparency = _hidden_meshes[m][0]
			m.cast_shadow = _hidden_meshes[m][1]
	_hidden_meshes.clear()


func _set_collision_enabled(enabled: bool) -> void:
	for shape in find_children("*", "CollisionShape3D", false, false):
		shape.set_deferred("disabled", not enabled)


## ---------------------------------------------------------------------
## Background darkening
## ---------------------------------------------------------------------

func _darken_background() -> void:
	_restore_background()
	_collect_dark_targets(get_tree().root)
	for obj in _dark_objects:
		var dark_mat := obj.material_override as StandardMaterial3D
		var t := create_tween()
		t.tween_property(dark_mat, "albedo_color", dark_mat.albedo_color * 0.1, transition_time) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		_dark_tweens.append(t)


func _collect_dark_targets(node: Node) -> void:
	# Never darken this item itself (its real meshes or the examine copy).
	if node == _pivot or node == _source_mesh or (node is MeshInstance3D and mesh_list.has(node)):
		return
	# Meshes, and CSG shapes too (the office light panels and cubicle walls
	# are CSG - they used to stay fully lit). Only the top CSG node of a
	# group draws anything, so that's the one that gets darkened.
	var is_target: bool = node is MeshInstance3D or (node is CSGShape3D and node.is_root_shape())
	if is_target and (node.layers & 1) and node.visible:
		_original_overrides[node] = node.material_override
		node.material_override = _make_dark_material(node)
		_dark_objects.append(node)
	for child in node.get_children():
		_collect_dark_targets(child)


func _make_dark_material(node: GeometryInstance3D) -> StandardMaterial3D:
	var dark_mat := StandardMaterial3D.new()
	dark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var source_mat: Material = node.material_override
	if not source_mat and node is MeshInstance3D and node.mesh and node.mesh.get_surface_count() > 0:
		source_mat = node.mesh.surface_get_material(0)
	if not source_mat and node is CSGShape3D and "material" in node:
		source_mat = node.material
	if source_mat is StandardMaterial3D:
		dark_mat.albedo_color = source_mat.albedo_color
		dark_mat.albedo_texture = source_mat.albedo_texture
	return dark_mat


func _restore_background() -> void:
	for t in _dark_tweens:
		if t and t.is_valid():
			t.kill()
	_dark_tweens.clear()
	for obj in _dark_objects:
		if is_instance_valid(obj):
			obj.material_override = _original_overrides.get(obj)
	_dark_objects.clear()
	_original_overrides.clear()


func _exit_tree() -> void:
	super._exit_tree()
	if _state != State.IDLE:
		_restore_background()
		if PlayerManager.ExamingItem == self:
			PlayerManager.ExamingItem = null
			PlayerManager.examining = false
