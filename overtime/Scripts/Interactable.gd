## No Exit
## Overtime Studios
## Last updated 10/18/26 by Justin Ferreira
## - Interactable Script
## this is is a parent class for many objects
## having this as a parent allows for objects to have mutiple features
## which are essential for gameplay
## main feature being that the player can click on these objects adn there
## will be some sort of reaction
## there is also the ability to flash the outline of an object
## Outlines are drawn as a screen-space effect by OutlineManager - change
## the colour/width there.

extends CollisionObject3D
class_name Interactable

# This allows for the clicking action the player takes to be sent to a function
# that is set up on the child. This is found on the node and can be accessed in
# the signals tab to easily establish this function.
signal interacted(body)

# interaction_succeeded
# A separate signal from `interacted` above. `interacted` just means the
# player clicked this object - it fires no matter what the object's own
# _on_interacted() decides to do with that click. interaction_succeeded
# means this object's interaction actually succeeded (a puzzle piece was
# solved, an item was picked up, etc). Anything that needs to react to a
# real success - like ConditionDoor - should listen for this instead of
# `interacted`. Call mark_success() below to emit it.
signal interaction_succeeded

# turn on and off the objetcs interactivity
# Turning it off also clears the hover outline, so nothing stays outlined
# after it's been used / picked up.
@export var is_interactable: bool = true:
	set(value):
		is_interactable = value
		if not value and _outline_shown:
			hide_outline()
# Legacy - no longer used. Outline colour/width live in OutlineManager.
@export var outline_material: Material
# The mesh that need the be outlined
# Optional - leave empty to use this object's parent MeshInstance3D
@export var mesh: MeshInstance3D
@export var mesh_list: Array[MeshInstance3D]
# Tick this to give the object an outline (on hover) and allow flashing.
@export var has_outline: bool
# Id GameState uses to remember this object (e.g. that it was picked up).
# Leave empty to use "<level file>::<path in level>", which is unique as
# long as you don't rename/move the node. Set one by hand if you want it
# to survive renames, or to share one id between several levels.
@export var persist_id: String = ""

# variable to know if object is flashimg or not
var _is_flashing: bool = false
# true while the hover outline is showing (it wins over flashing)
var _outline_shown: bool = false
# while true no outline or flash is drawn at all (see set_outline_blocked)
var _outline_blocked: bool = false
# current brightness of the flash, animated 0 -> 1 -> 0 by _flash_tween
var _flash_alpha: float = 0.0
var _flash_tween: Tween
# One mask material per object, shared by its mask meshes. Its "strength"
# is how bright this object's outline is right now.
var _mask_material: ShaderMaterial
# Invisible copies of the outlined meshes that OutlineManager draws from.
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
			push_warning("%s: has_outline is on but no mesh was set or found on the parent." % name)
			has_outline = false
	if has_outline:
		_setup_outline()

func _on_interacted_callable() -> Callable:
	return Callable(self, "_on_interacted")

# get_persist_id
# This object's id for GameState (see persist_id above).
func get_persist_id() -> String:
	if persist_id != "":
		return persist_id
	var level := get_tree().current_scene if is_inside_tree() else null
	if level == null:
		return str(get_path())
	return "%s::%s" % [level.scene_file_path, level.get_path_to(self)]

# _setup_outline
# Makes the invisible mask copies OutlineManager uses to draw this
# object's outline.
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
	stop_flashing()

# mark_success
# Call this from a child script's _on_interacted() once it knows its
# interaction actually succeeded. Emits interaction_succeeded so anything
# listening for a real success (not just a click) can react - see
# ConditionDoor.
func mark_success() -> void:
	interaction_succeeded.emit()

# show_outline
# turns on the outline for an object (hover). Returns false if this object
# has no outline.
func show_outline() -> bool:
	if not has_outline or _outline_blocked:
		return false
	_outline_shown = true
	_refresh_outline()
	return true

# hide_outline
# turns off the hover outline - goes back to flashing if it was flashing
func hide_outline() -> void:
	if not has_outline:
		return
	_outline_shown = false
	_refresh_outline()

# start_flashing
# Starts pulsing the outline on and off
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

# stop_flashing
# Stops the pulsing outline
func stop_flashing() -> void:
	if not _is_flashing:
		return
	_is_flashing = false
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_alpha = 0.0
	_refresh_outline()

# set_outline_blocked
# Hides this object's outline and flashing completely until unblocked -
# e.g. ExaminableItem blocks it while the item is up at the camera.
# Blocking also forgets the hover outline, so it only comes back once the
# player aims at the object again.
func set_outline_blocked(blocked: bool) -> void:
	_outline_blocked = blocked
	if blocked:
		_outline_shown = false
	_refresh_outline()

# is_flashing
# Check if currently flashing
func is_flashing() -> bool:
	return _is_flashing

func _set_flash_alpha(alpha: float) -> void:
	_flash_alpha = alpha
	_refresh_outline()

# _refresh_outline
# Pushes the current outline brightness to the mask and tells
# OutlineManager whether this object needs drawing.
func _refresh_outline() -> void:
	if not _mask_material:
		return
	var strength := 1.0 if _outline_shown else (_flash_alpha if _is_flashing else 0.0)
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
			# The masks live on the mesh, not on this node - remove them too.
			for mask in _masks:
				if is_instance_valid(mask):
					mask.queue_free()

# _exit_tree
# Clean up when node exits
func _exit_tree() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_set_masks_on(false)

# toggle_interactable
# takes in a bool parameter and sets
# is_interactable to that
func toggle_interactable(state: bool):
	is_interactable = state

# reactivate_others
# Shared helper for "button" scripts (SimpleCondition, UIConditionItem)
# that expose their own exported reactivate_targets list and want to
# restore a set of other Interactables to their original clickable state
# when they fire - e.g. a relock trigger putting the buttons a
# ConditionDoor already solved back into play so the puzzle can be
# solved again.
func reactivate_others(targets: Array[Interactable]) -> void:
	for target in targets:
		if target == null:
			continue
		target.toggle_interactable(true)
