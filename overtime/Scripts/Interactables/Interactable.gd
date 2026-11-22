## No Exit
## Overtime Studios
## Interactable (class_name Interactable)
## - Base class for everything the player can click: the Player's interact
##   ray emits `interacted`, which calls the subclass's _on_interacted().
## - Outlines: with has_outline on, the object gets a red outline while the
##   player is close (fading in/out), flashes while aimed at, and can be told
##   to flash (start_flashing). Drawn as a screen-space effect by
##   OutlineManager - change the colour/width there.
## - mark_success() reports a real success (puzzles listen for it);
##   get_persist_id() is the id GameState remembers it by.

extends CollisionObject3D
class_name Interactable

## This allows for the clicking action the player takes to be sent to a function
## that is set up on the child. This is found on the node and can be accessed in
## the signals tab to easily establish this function.
signal interacted(body)

## A separate signal from `interacted` above. `interacted` just means the
## player clicked this object - it fires no matter what the object's own
## _on_interacted() decides to do with that click. interaction_succeeded
## means this object's interaction actually succeeded (a puzzle piece was
## solved, an item was picked up, etc). Anything that needs to react to a
## real success - like ConditionDoor - should listen for this instead of
## `interacted`. Call mark_success() below to emit it.
signal interaction_succeeded

## turn on and off the objetcs interactivity
## Turning it off also clears the hover outline, so nothing stays outlined
## after it's been used / picked up.
@export var is_interactable: bool = true:
	set(value):
		is_interactable = value
		if not value and _outline_shown:
			hide_outline()
		else:
			_refresh_outline()
## The mesh that need the be outlined
## Optional - leave empty to use this object's parent MeshInstance3D
@export var mesh: MeshInstance3D
@export var mesh_list: Array[MeshInstance3D]
## Tick this to give the object an outline (on hover) and allow flashing.
@export var has_outline: bool
## Id GameState uses to remember this object (e.g. that it was picked up).
## Leave empty to use "<level file>::<path in level>", which is unique as
## long as you don't rename/move the node. Set one by hand if you want it
## to survive renames, or to share one id between several levels.
@export var persist_id: String = ""
## Keep the close-by outline after the player has clicked this.
## Off = once clicked it's only outlined while aimed at (the hover flash).
@export var outline_after_use: bool = false

## true once the player has clicked this (see mark_used)
var was_used: bool = false

## variable to know if object is flashimg or not
var _is_flashing: bool = false
## true while the player is aiming at this object (hover: the outline flashes,
## and it wins over everything else)
var _outline_shown: bool = false
## true while the player is within OutlineManager.NEAR_DISTANCE (steady outline)
var _near: bool = false
## brightness of the "close by" outline, faded in/out by _near_tween
var _near_alpha: float = 0.0
var _near_tween: Tween
## brightness of the hover flash, animated by _hover_tween
var _hover_alpha: float = 1.0
var _hover_tween: Tween
## while true no outline or flash is drawn at all (see set_outline_blocked)
var _outline_blocked: bool = false
## current brightness of the flash, animated 0 -> 1 -> 0 by _flash_tween
var _flash_alpha: float = 0.0
var _flash_tween: Tween
## One mask material per object, shared by its mask meshes. Its "strength"
## is how bright this object's outline is right now.
var _mask_material: ShaderMaterial
## Invisible copies of the outlined meshes that OutlineManager draws from.
var _masks: Array[MeshInstance3D] = []

func _ready():
	# Hook up interacted -> _on_interacted automatically so new objects don't
	# need it wired in the Signals tab. Skipped if it's already connected
	# there, so nothing fires twice.
	if has_method("_on_interacted") and not interacted.is_connected(_on_interacted_callable()):
		interacted.connect(_on_interacted_callable())
	# Fill in outline defaults so new objects only need has_outline ticked.
	if has_outline:
		if not mesh and get_parent() is MeshInstance3D:
			mesh = get_parent()
		if not mesh:
			# or the first mesh under this object (e.g. a key whose mesh is its child)
			for c in find_children("*", "MeshInstance3D", true, false):
				if c.mesh and c.name != "OutlineMask":
					mesh = c
					break
		if not mesh:
			push_warning("%s: has_outline is on but no mesh was set or found on the parent." % name)
			has_outline = false
	if has_outline:
		_setup_outline()

func _on_interacted_callable() -> Callable:
	return Callable(self, "_on_interacted")

## This object's id for GameState (see persist_id above).
func get_persist_id() -> String:
	if persist_id != "":
		return persist_id
	var level := get_tree().current_scene if is_inside_tree() else null
	if level == null:
		return str(get_path())
	return "%s::%s" % [level.scene_file_path, level.get_path_to(self)]

## Makes the invisible mask copies OutlineManager uses to draw this
## object's outline.
func _setup_outline() -> void:
	OutlineManager.get_instance(get_tree())
	_mask_material = OutlineManager.make_mask_material()
	var targets: Array[MeshInstance3D] = [mesh]
	for m in mesh_list:
		if m and not targets.has(m):
			targets.append(m)
	for m in targets:
		if m.mesh:
			_masks.append(OutlineManager.create_mask(m, _mask_material))
	# lets OutlineManager give this object a steady outline when the player is close
	OutlineManager.register(self)


## Outlines this object using `shape`: an invisible stand-in mesh (e.g. a box
## over a button that's baked into a bigger model). The stand-in is kept
## "visible" so the outline can draw, but on no render layer, so the camera
## never shows it - only the outline appears. Call before super._ready().
## front_toward: a point on the side the player looks from (e.g. inside the
## elevator). If given, only the box's flat face on that side is outlined,
## so the outline is a clean flat shape instead of tracing the box's depth.
func use_outline_stand_in(shape: MeshInstance3D, front_toward: Variant = null) -> void:
	shape.visible = true
	shape.layers = 0
	shape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = shape if front_toward == null else _flat_face_of(shape, front_toward)
	has_outline = true

## An invisible box to outline with (see use_outline_stand_in), placed by `xf`
## in `space`'s coordinates (e.g. where a button sits on an elevator model),
## added under this object.
func make_outline_shape(space: Node3D, xf: Transform3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = "OutlineShape"
	m.mesh = BoxMesh.new()
	add_child(m)
	m.global_transform = space.global_transform * xf
	return m

## A paper-thin copy of `shape` just inside its face toward `toward` (the
## face across the box's thinnest side) - pulled most of the way in toward
## the middle, where the button actually is, so the outline sits on the
## button instead of floating in front of it. Never drawn either.
func _flat_face_of(shape: MeshInstance3D, toward: Vector3) -> MeshInstance3D:
	var box := shape.get_aabb()
	var k := 0
	var thinnest := INF
	for i in 3:
		var width: float = box.size[i] * shape.global_basis[i].length()
		if width < thinnest:
			thinnest = width
			k = i
	var center := box.get_center()
	var face_center := center
	var side := 1.0 if shape.to_local(toward)[k] > center[k] else -1.0
	face_center[k] += side * box.size[k] * 0.5 * 0.2
	var squash := Vector3.ONE
	squash[k] = 0.01
	var face := MeshInstance3D.new()
	face.name = "OutlineFace"
	face.mesh = shape.mesh
	face.layers = 0
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.transform = Transform3D(Basis.from_scale(squash), face_center - squash * center)
	shape.add_child.call_deferred(face)
	return face

## World-space box around the meshes this object outlines (used for the
## "player is close" check).
func get_outline_aabb() -> AABB:
	var box := AABB()
	var first := true
	for m in [mesh] + mesh_list:
		if not is_instance_valid(m) or m.mesh == null or not m.is_inside_tree():
			continue
		var b: AABB = m.global_transform * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first and is_inside_tree():
		box = AABB(global_position, Vector3.ZERO)
	return box


## OutlineManager calls this when the player comes within (or leaves)
## NEAR_DISTANCE of this object. The outline fades in / out
## (OutlineManager.NEAR_FADE_IN_TIME / NEAR_FADE_OUT_TIME).
func set_near(near: bool) -> void:
	if near and _outline_spent():
		near = false
	if near == _near:
		return
	_near = near
	if _near_tween and _near_tween.is_valid():
		_near_tween.kill()
	var target := 1.0 if near else 0.0
	var full_time := OutlineManager.NEAR_FADE_IN_TIME if near else OutlineManager.NEAR_FADE_OUT_TIME
	# only the part still left to fade (turning back halfway is quicker)
	var time := full_time * absf(target - _near_alpha)
	if time <= 0.0 or not is_inside_tree():
		_set_near_alpha(target)
		return
	_near_tween = create_tween()
	_near_tween.tween_method(_set_near_alpha, _near_alpha, target, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_near_alpha(alpha: float) -> void:
	_near_alpha = alpha
	_refresh_outline()

## this function is what is called when clicked by player
## it checks if it is interactable if it is then it goes throught
## with the _on_interacted function for that object
func interact(body):
	if is_interactable == false:
		pass
	else:
		mark_used()
		interacted.emit(body)

## The player has clicked this: unless outline_after_use is on, its close-by
## outline fades away and doesn't come back. Aiming at it still flashes.
## Scripts restoring a saved state (a bin already searched, a door left open)
## call it too.
func mark_used() -> void:
	was_used = true
	if outline_after_use:
		return
	set_near(false)
	_refresh_outline()

func _outline_spent() -> bool:
	return was_used and not outline_after_use

## turns off interactablity for an object
func _on_interaction_complete() -> void:
	is_interactable = false
	stop_flashing()

## Call this from a child script's _on_interacted() once it knows its
## interaction actually succeeded. Emits interaction_succeeded so anything
## listening for a real success (not just a click) can react - see
## ConditionDoor.
func mark_success() -> void:
	interaction_succeeded.emit()

## The player is aiming at this object (hover): the outline starts flashing.
## Returns false if this object has no outline.
func show_outline() -> bool:
	if not has_outline or _outline_blocked:
		return false
	if not _outline_shown:
		_outline_shown = true
		_start_hover_flash()
	_refresh_outline()
	return true

## The player stopped aiming at this object - back to the steady "close by"
## outline, scripted flashing, or nothing.
func hide_outline() -> void:
	if not has_outline:
		return
	_outline_shown = false
	_stop_hover_flash()
	_refresh_outline()

func _start_hover_flash() -> void:
	_stop_hover_flash()
	var half := OutlineManager.HOVER_FLASH_TIME * 0.5
	_hover_tween = create_tween().set_loops()
	_hover_tween.tween_method(_set_hover_alpha, 1.0, OutlineManager.HOVER_FLASH_MIN, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hover_tween.tween_method(_set_hover_alpha, OutlineManager.HOVER_FLASH_MIN, 1.0, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_hover_flash() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_alpha = 1.0

func _set_hover_alpha(alpha: float) -> void:
	_hover_alpha = alpha
	_refresh_outline()

## Starts pulsing the outline on and off
func start_flashing() -> void:
	if not has_outline or _is_flashing:
		return
	_is_flashing = true
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.set_loops()  # Loop indefinitely
	_flash_tween.tween_method(_set_flash_alpha, 0.0, 1.0, 1.0)
	_flash_tween.tween_method(_set_flash_alpha, 1.0, 0.0, 1.0)
	_refresh_outline()

## Stops the pulsing outline
func stop_flashing() -> void:
	if not _is_flashing:
		return
	_is_flashing = false
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_alpha = 0.0
	_refresh_outline()

## Hides this object's outline and flashing completely until unblocked -
## e.g. ExaminableItem blocks it while the item is up at the camera.
## Blocking also forgets the hover outline, so it only comes back once the
## player aims at the object again.
func set_outline_blocked(blocked: bool) -> void:
	_outline_blocked = blocked
	if blocked:
		_outline_shown = false
		_stop_hover_flash()
	_refresh_outline()

## Check if currently flashing
func is_flashing() -> bool:
	return _is_flashing

func _set_flash_alpha(alpha: float) -> void:
	_flash_alpha = alpha
	_refresh_outline()

## Pushes the current outline brightness to the mask and tells
## OutlineManager whether this object needs drawing.
func _refresh_outline() -> void:
	if not _mask_material:
		return
	# hover flash > scripted flashing > steady "close by" outline > nothing
	var strength := 0.0
	if _outline_shown:
		strength = _hover_alpha
	elif _is_flashing:
		strength = _flash_alpha
	elif is_interactable:
		strength = _near_alpha
	_mask_material.set_shader_parameter("strength", strength)
	# Hidden or removed objects (picked up, etc.) never draw an outline.
	var on := strength > 0.001 and not _outline_blocked and is_inside_tree() and is_visible_in_tree()
	_set_masks_on(on)

func _set_masks_on(on: bool) -> void:
	var manager: OutlineManager = OutlineManager._instance
	for mask in _masks:
		if is_instance_valid(mask):
			mask.visible = on
			if is_instance_valid(manager):
				manager.set_mask_active(mask, on)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			_refresh_outline()
		NOTIFICATION_PREDELETE:
			OutlineManager.unregister(self)
			# The masks live on the mesh, not on this node - remove them too.
			for mask in _masks:
				if is_instance_valid(mask):
					mask.queue_free()

## Clean up when node exits
func _exit_tree() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_stop_hover_flash()
	if _near_tween and _near_tween.is_valid():
		_near_tween.kill()
	_near = false
	_near_alpha = 0.0
	_set_masks_on(false)

## takes in a bool parameter and sets
## is_interactable to that
func toggle_interactable(state: bool):
	is_interactable = state

## Shared helper for "button" scripts (SimpleCondition, UIConditionItem)
## that expose their own exported reactivate_targets list and want to
## restore a set of other Interactables to their original clickable state
## when they fire - e.g. a relock trigger putting the buttons a
## ConditionDoor already solved back into play so the puzzle can be
## solved again.
func reactivate_others(targets: Array[Interactable]) -> void:
	for target in targets:
		if target == null:
			continue
		target.toggle_interactable(true)
