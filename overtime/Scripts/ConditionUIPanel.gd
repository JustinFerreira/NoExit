## No Exit
## Overtime Studios
## Last updated 8/17/26 by Justin Ferreira
## Condition UI Panel Script
## - Minimal, reusable popup for a "click this button to confirm"
##   interaction - the same shape as the Hot Wire minigame's button, but
##   generic so it isn't tied to that one minigame. Put this script on
##   any Control that has a Button somewhere inside it, assign
##   confirm_button in the Inspector, and call open()/close() from
##   whatever triggers it (see UIConditionItem, which does this for you).
## - Starts hidden and handles the mouse-visible / mouse-captured swap
##   itself, same as HotWireGame already does for the steering wheel.

extends Control
class_name ConditionUIPanel

## The button the player clicks to confirm/complete this UI.
@export var confirm_button: Button

## Emitted the moment confirm_button is pressed (after the panel has
## already closed itself).
signal confirmed


func _ready() -> void:
	visible = false
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	else:
		push_warning("%s: ConditionUIPanel has no confirm_button assigned." % name)


# open
# Shows the panel and frees the mouse so the player can click the
# button. Also disables the player's current interact ray so clicking
# through the UI doesn't also interact with world objects behind it.
func open() -> void:
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if PlayerManager.player and PlayerManager.player.interact_ray:
		PlayerManager.player.interact_ray.enabled = false


# close
# Hides the panel and restores normal mouse/interact-ray behavior.
func close() -> void:
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if PlayerManager.player and PlayerManager.player.interact_ray:
		PlayerManager.player.interact_ray.enabled = true


func _on_confirm_pressed() -> void:
	close()
	confirmed.emit()
