## No Exit
## Overtime Studios
## Last updated 8/17/26 by Justin Ferreira
## UI Condition Item Script
## - Interactable that opens a simple confirm-button popup (see
##   ConditionUIPanel) instead of succeeding immediately on click - the
##   same shape as the steering wheel opening the Hot Wire minigame.
##   Success is reported once the player clicks the button in that
##   popup, so this item can be dropped straight into a ConditionDoor's
##   required_conditions like anything else that calls mark_success().
## - Expects its own dedicated ConditionUIPanel (one panel per item is
##   the normal setup - sharing one panel across multiple items isn't
##   supported here, since there'd be no way to tell which item the
##   confirmation was for).

extends Interactable
class_name UIConditionItem

## The popup this item opens on interact. Assign the Control node that
## has ConditionUIPanel on it.
@export var ui_panel: ConditionUIPanel

## If true (default), this item can only succeed once - clicking it
## again after that just re-opens/does nothing new.
@export var one_shot: bool = true


func _ready() -> void:
	super._ready()
	if ui_panel:
		ui_panel.confirmed.connect(_on_ui_confirmed)
	else:
		push_warning("%s: UIConditionItem has no ui_panel assigned." % name)


# _on_interacted
# Called by Interactable when the player clicks this object (wired up
# via the node's Signals tab in the editor, same as every Interactable).
# Note: once one_shot has fired, _on_interaction_complete() sets
# is_interactable to false, so the base Interactable.interact() stops
# calling this at all - no extra guard needed here.
func _on_interacted(_body: Variant) -> void:
	if not ui_panel:
		return
	ui_panel.open()


# _on_ui_confirmed
# Called when the player clicks the button inside ui_panel.
func _on_ui_confirmed() -> void:
	mark_success()
	if one_shot:
		_on_interaction_complete()
