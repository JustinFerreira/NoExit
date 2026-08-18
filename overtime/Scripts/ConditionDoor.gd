## No Exit
## Overtime Studios
## Last updated 8/17/26 by Justin Ferreira
## Condition Door Script
## - A Door that stays locked until a set of OTHER Interactables have
##   each reported a successful interaction (see Interactable's
##   interaction_succeeded signal / mark_success()). Drop any number of
##   condition objects into required_conditions in the Inspector - 1, 3,
##   20, however many the puzzle needs - and the door unlocks once
##   enough of them succeed.
## - Any Interactable that calls mark_success() from its own
##   _on_interacted() qualifies as a condition: InventoryItem and
##   SimpleCondition both already do this out of the box, so a basic
##   "3 items, interact with each, door opens" puzzle needs zero extra
##   scripting - just wire the 3 items into required_conditions here.
## - Everything Door already does still works on top of this: a
##   ConditionDoor can also have its own key_name/locked_sound if a
##   puzzle wants both a key AND conditions.

extends Door
class_name ConditionDoor

## The Interactable-based nodes that must each succeed before this door
## unlocks. Drag in any node whose script extends Interactable and calls
## mark_success() when solved. Add/remove entries freely in the
## Inspector - this array is the "editable amount of conditions".
@export var required_conditions: Array[Interactable] = []

## How many of required_conditions must succeed before the door
## unlocks. Leave at 0 to require ALL of them (the common "solve every
## item" case). Set to a smaller number for "any 2 of 3", etc.
@export var required_count: int = 0

# Conditions that have already reported success, so a repeat signal from
# the same node doesn't get counted twice.
var _met_conditions: Array[Interactable] = []


func _ready() -> void:
	super._ready()
	for condition in required_conditions:
		if condition == null:
			push_warning("%s: required_conditions has an empty slot." % name)
			continue
		condition.interaction_succeeded.connect(_on_condition_succeeded.bind(condition))


# _on_condition_succeeded
# Called whenever one of required_conditions reports success. Once
# enough distinct conditions have fired, unlocks the door - reusing all
# of Door's normal unlock behavior (collision, sound, hide_on_unlock,
# animation, etc.) for free.
func _on_condition_succeeded(condition: Interactable) -> void:
	if condition in _met_conditions:
		return
	_met_conditions.append(condition)

	var needed: int = required_count if required_count > 0 else required_conditions.size()
	if _met_conditions.size() >= needed:
		unlock()


# conditions_met / conditions_total
# Handy if you want to hook up UI feedback, like a "2 / 3" counter.
func conditions_met() -> int:
	return _met_conditions.size()

func conditions_total() -> int:
	return required_count if required_count > 0 else required_conditions.size()
