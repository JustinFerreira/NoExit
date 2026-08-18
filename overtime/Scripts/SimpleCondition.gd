## No Exit
## Overtime Studios
## Last updated 8/17/26 by Justin Ferreira
## Simple Condition Script
## - Minimal Interactable for puzzle pieces that don't need to be picked
##   up or do anything fancy - a switch, a button, a lever, a plain
##   "click this" object. Clicking it reports a success, which is all a
##   ConditionDoor (or anything else listening for interaction_succeeded)
##   needs to count it as solved.

extends Interactable
class_name SimpleCondition

## If true (default), this can only be triggered once - clicking it
## again afterward does nothing. Turn off if you want a switch the
## player can click more than once (note: a ConditionDoor only ever
## counts the FIRST success from a given condition either way).
@export var one_shot: bool = true

## Optional. Other Interactable-based buttons (SimpleCondition,
## UIConditionItem, etc.) to bring back to their original clickable
## state the moment this one succeeds. Meant for a "relock" switch that
## also resets the buttons a ConditionDoor's required_conditions used
## the first time, so the puzzle can be solved again.
@export var reactivate_targets: Array[Interactable] = []


# _on_interacted
# Called by Interactable when the player clicks this object (wired up
# via the node's Signals tab in the editor, same as every Interactable).
func _on_interacted(_body: Variant) -> void:
	mark_success()
	reactivate_others(reactivate_targets)
	if one_shot:
		_on_interaction_complete()
