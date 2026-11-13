## No Exit
## Overtime Studios
## Last updated 11/10/26 by Justin Ferreira
## Animated Interactable
## - Plays an animation when the player interacts with it: a fridge door
##   swinging open, a drawer sliding out, a cupboard, a car boot...
## - Click again to play it backwards (close it), unless can_close is off.
## - Can hold things shut: anything listed in locked_until_open, or any
##   Interactable placed under the `contents` node, can't be used until
##   the animation has finished opening, and is locked again when it closes.
##   (e.g. items inside the fridge can only be taken once the door is open)
## - Remembers being left open through GameState, like picked-up items.
##
## Setup:
##   1. Animate the moving part with an AnimationPlayer (e.g. rotate a hinge
##      node from closed to open). The animation's last frame is "open".
##   2. Put this script on a StaticBody3D (with a CollisionShape3D) on the
##      moving part, so you click the part itself.
##   3. Set animation_player + animation_name (or leave them empty to use the
##      first AnimationPlayer / animation found nearby).
##   4. Drop any items into `contents` (or list them in locked_until_open).

extends Interactable
class_name AnimatedInteractable

## Emitted when the open animation has finished.
signal opened
## Emitted when the close animation has finished.
signal closed

@export_group("Animation")
## The AnimationPlayer to play. Empty = the first one found on this object,
## its parent, or its parent's children.
@export var animation_player: AnimationPlayer
## Animation to play when opening. Empty = the player's first animation.
@export var animation_name: StringName = &""
## Click again to play the animation backwards (close it).
@export var can_close: bool = true
## Playback speed (2 = twice as fast).
@export var speed: float = 1.0

@export_group("Sounds")
## Played when it starts opening. Empty = no sound.
@export var open_sound: AudioStream
## Played when it starts closing. Empty = no sound.
@export var close_sound: AudioStream

@export_group("Contents")
## Every Interactable under this node is locked until this is open.
## Easiest way to use it: put the fridge's items under this node.
@export var contents: Node
## Extra Interactables (anywhere in the level) locked until this is open.
@export var locked_until_open: Array[Interactable] = []

@export_group("Saving")
## Come back open if the player left it open (GameState, like picked-up items).
@export var remember_open: bool = true

var is_open: bool = false
var _busy: bool = false


func _ready() -> void:
	super._ready()
	if animation_player == null:
		animation_player = _find_animation_player()
	if animation_player and animation_name == &"":
		var list := animation_player.get_animation_list()
		if not list.is_empty():
			animation_name = list[0]
	if animation_player == null or not animation_player.has_animation(animation_name):
		push_warning("%s: AnimatedInteractable has no animation to play." % name)
	# Deferred: the contents run their own _ready() (and may remove
	# themselves if already picked up) before we lock them.
	_restore_state.call_deferred()


func _find_animation_player() -> AnimationPlayer:
	for n: Node in [self, get_parent()]:
		if n == null:
			continue
		if n is AnimationPlayer:
			return n
		var found: Array[Node] = n.find_children("*", "AnimationPlayer", true, false)
		if not found.is_empty():
			return found[0]
	return null


func _restore_state() -> void:
	if remember_open and GameState.collected_how(get_persist_id()) == GameState.OPENED:
		_jump_to_open()
	else:
		_set_contents_locked(true)


## Shows it fully open straight away (no sound, no waiting).
func _jump_to_open() -> void:
	if animation_player and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
		animation_player.seek(animation_player.current_animation_length, true)
		animation_player.pause()
	is_open = true
	_set_contents_locked(false)


func _on_interacted(_body: Variant) -> void:
	if _busy:
		return
	if is_open:
		if can_close:
			close()
	else:
		open()


## Plays the animation forwards. Safe to call from other scripts too.
func open() -> void:
	if _busy or is_open:
		return
	if open_sound:
		AudioManager.play_sound(open_sound)
	await _play(false)
	is_open = true
	_set_contents_locked(false)
	if remember_open:
		GameState.mark_collected(get_persist_id(), GameState.OPENED)
	mark_success()
	opened.emit()


## Plays the animation backwards. Safe to call from other scripts too.
func close() -> void:
	if _busy or not is_open:
		return
	# lock straight away so nothing can be grabbed through a closing door
	_set_contents_locked(true)
	if close_sound:
		AudioManager.play_sound(close_sound)
	await _play(true)
	is_open = false
	if remember_open:
		GameState.unmark_collected(get_persist_id())
	closed.emit()


func _play(backwards: bool) -> void:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return
	_busy = true
	if backwards:
		animation_player.play(animation_name, -1, -speed, true)
	else:
		animation_player.play(animation_name, -1, speed)
	await animation_player.animation_finished
	_busy = false


## Locks / unlocks everything this holds shut.
func _set_contents_locked(locked: bool) -> void:
	for item in _locked_items():
		item.toggle_interactable(not locked)


func _locked_items() -> Array[Interactable]:
	var items: Array[Interactable] = []
	for item in locked_until_open:
		if is_instance_valid(item):
			items.append(item)
	if contents:
		for n in contents.find_children("*", "", true, false):
			if n is Interactable and n != self and not items.has(n):
				items.append(n)
	return items
