## No Exit
## Overtime Studios
## Last updated 8/17/26 by Justin Ferreira
## Door Script
## - Generic, reusable door script meant to be dropped onto ANY door-like
##   object (room doors, cabinets, gates, closets, the car door, etc.).
## - Supports a locked state that plays an exported "locked" sound when
##   the player tries a locked door, an optional key (just a string name
##   the script searches for in PlayerManager's inventory), and an
##   optional AnimationPlayer that plays an unlock animation if one is
##   assigned in the Inspector. Every one of these is optional, so a
##   plain always-unlocked door or a keyless "flip a switch to unlock"
##   door both work with this same script.

extends Interactable
class_name Door

## ---------------------------------------------------------------------
## Locked State
## ---------------------------------------------------------------------

## Whether this door starts locked. Set per-door in the Inspector.
@export var is_locked: bool = true

## Sound played when the player interacts with this door while it is
## still locked. Leave empty in the Inspector and nothing will play.
@export var locked_sound: AudioStream

## ---------------------------------------------------------------------
## Key
## ---------------------------------------------------------------------

## The item name PlayerManager.Inventory must contain to unlock this
## door (see PlayerManager.has_item). Every door can use a different
## key just by changing this string - no extra scripting needed.
## Leave blank if this door has no key and should only be unlocked by
## calling unlock() from somewhere else (a switch, a cutscene, etc.).
@export var key_name: String = ""

## If true, the key is removed from the player's inventory the moment
## this door unlocks (good for single-use keys). If false (default),
## the player keeps the key so it can also open other doors that share
## the same key_name.
@export var consume_key_on_unlock: bool = false

## ---------------------------------------------------------------------
## Unlock Animation (optional)
## ---------------------------------------------------------------------

## Optional. If an AnimationPlayer is assigned here, unlock_animation_name
## is played on it the moment the door unlocks. If left unassigned, no
## animation plays - this lets the same script work on doors that don't
## have one yet.
@export var unlock_animation_player: AnimationPlayer

## Name of the animation to play on unlock_animation_player when unlocked.
@export var unlock_animation_name: String = "Unlock"

## ---------------------------------------------------------------------
## Visibility on Unlock
## ---------------------------------------------------------------------

## If true (default), the door also turns invisible the moment it's
## unlocked - a quick placeholder for "the door is gone" before there's
## a real open animation. Turn this off for doors that should stay
## visible (e.g. ones that rely on unlock_animation_player to swing
## open instead).
@export var hide_on_unlock: bool = true

## ---------------------------------------------------------------------
## Signals
## ---------------------------------------------------------------------

## Emitted the moment this door becomes unlocked.
signal door_unlocked

## Emitted if this door is locked again after being unlocked.
signal door_locked

## Collision layer this door had in the editor, restored if the door is
## ever re-locked with lock().
var _default_collision_layer: int


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	_default_collision_layer = collision_layer
	if not is_locked:
		# Door starts unlocked - match its collision (and visibility) to
		# that state right away. No sound/animation here since nothing
		# actually happened.
		collision_layer = 0
		if hide_on_unlock:
			visible = false


# _on_interacted
# Called by Interactable when the player clicks this door (wired up via
# the node's Signals tab in the editor, same as every other Interactable).
func _on_interacted(_body: Variant) -> void:
	if is_locked:
		_try_unlock_with_key()
	# If the door is already unlocked, interacting with it again does
	# nothing by default. Override this in a subclass (like CarDoor) for
	# doors that need extra behavior - opening/closing animations, etc.


# _try_unlock_with_key
# Checks the player's inventory for key_name. Unlocks the door if it's
# found, otherwise plays the locked sound.
func _try_unlock_with_key() -> void:
	if key_name != "" and PlayerManager.has_item(key_name):
		if consume_key_on_unlock:
			PlayerManager.RemoveItemByName(key_name)
		unlock()
	else:
		_play_locked_sound()


# unlock
# Public so other systems (switches, cutscenes, other puzzles) can
# unlock this door directly without going through the key check.
func unlock() -> void:
	if not is_locked:
		return
	is_locked = false
	# Drop the collision layer so the player can walk straight through.
	collision_layer = 0
	if hide_on_unlock:
		visible = false
	_play_unlock_animation()
	door_unlocked.emit()


# lock
# Re-locks the door and restores its original collision layer so the
# player is blocked by it again.
func lock() -> void:
	if is_locked:
		return
	is_locked = true
	collision_layer = _default_collision_layer
	if hide_on_unlock:
		visible = true
	door_locked.emit()


# _play_locked_sound
# Plays the exported locked_sound through AudioManager - same one-shot
# sfx pattern used elsewhere (see CarDoor's AudioManager.play_sound
# calls). Does nothing if no sound was assigned in the Inspector.
func _play_locked_sound() -> void:
	if locked_sound:
		AudioManager.play_sound(locked_sound)


# _play_unlock_animation
# Plays unlock_animation_name on unlock_animation_player if one was
# assigned in the Inspector. Safe to leave both fields empty - doors
# without an animation just skip this step.
func _play_unlock_animation() -> void:
	if unlock_animation_player and unlock_animation_player.has_animation(unlock_animation_name):
		unlock_animation_player.play(unlock_animation_name)
