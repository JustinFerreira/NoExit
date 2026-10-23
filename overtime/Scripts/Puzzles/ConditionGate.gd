## No Exit
## Overtime Studios
## Last updated 8/18/26 by Justin Ferreira
## Condition Gate Script
## - Waits for a set of Interactable conditions to succeed (same
##   condition objects ConditionDoor uses - SimpleCondition,
##   UIConditionItem, InventoryItem, anything that calls mark_success())
##   and then flips a whole group of Door-family nodes at once - some
##   unlocking, some locking - as a one-time reaction.
## - Built for "appearing platform + disappearing walls" puzzles: give
##   the platform's Door script is_locked = false and hide_on_unlock =
##   true in the Inspector (so it starts invisible/passable), drop it in
##   doors_to_lock here - lock() makes it solid and visible again. Give
##   each invisible wall the normal default (is_locked = true, solid
##   from the start) and drop them in doors_to_unlock - unlock() drops
##   their collision so the player can walk through.
## - Fires once per set of conditions met, same as ConditionDoor. If you
##   also want this reversible, add a second ConditionGate wired to a
##   different trigger with doors_to_lock/doors_to_unlock swapped - the
##   same way ConditionDoor's relock_conditions reverses a door.

extends Node
class_name ConditionGate

## The Interactable-based nodes that must each succeed before this gate
## fires. Same idea as ConditionDoor's required_conditions.
@export var required_conditions: Array[Interactable] = []

## How many of required_conditions must succeed before the gate fires.
## Leave at 0 to require ALL of them.
@export var required_count: int = 0

## Doors that UNLOCK when this gate fires - use for invisible walls that
## should become passable.
@export var doors_to_unlock: Array[Door] = []

## Doors that LOCK when this gate fires - use for platforms (or
## anything else) that should appear/become solid.
@export var doors_to_lock: Array[Door] = []

# Conditions that have already reported success, so a repeat signal from
# the same node doesn't get counted twice.
var _met_conditions: Array[Interactable] = []


func _ready() -> void:
	for condition in required_conditions:
		if condition == null:
			push_warning("%s: required_conditions has an empty slot." % name)
			continue
		condition.interaction_succeeded.connect(_on_condition_succeeded.bind(condition))


# _on_condition_succeeded
# Called whenever one of required_conditions reports success. Once
# enough distinct conditions have fired, flips every door in
# doors_to_unlock/doors_to_lock.
func _on_condition_succeeded(condition: Interactable) -> void:
	if condition in _met_conditions:
		return
	_met_conditions.append(condition)

	var needed: int = required_count if required_count > 0 else required_conditions.size()
	if _met_conditions.size() >= needed:
		_fire()


func _fire() -> void:
	for door in doors_to_unlock:
		if door:
			door.unlock()
	for door in doors_to_lock:
		if door:
			door.lock()


# conditions_met / conditions_total
# Handy if you want to hook up UI feedback, like a "2 / 3" counter.
func conditions_met() -> int:
	return _met_conditions.size()

func conditions_total() -> int:
	return required_count if required_count > 0 else required_conditions.size()
