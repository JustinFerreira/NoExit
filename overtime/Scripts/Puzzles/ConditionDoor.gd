## No Exit
## Overtime Studios
## Last updated 8/18/26 by Justin Ferreira
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
## - Optionally drop a separate set of condition objects into
##   relock_conditions to re-lock the door once it's already open (a
##   "sabotage" switch, an alarm, etc.) - reuses Door's normal lock().
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

## Optional. Interactable-based nodes that, once enough of them succeed,
## re-lock this door (reusing Door's normal lock() - collision comes
## back, the door reappears, door_locked fires). Leave empty for a door
## that only ever opens. These are separate nodes from required_conditions
## - e.g. a second SimpleCondition used as a "sabotage" switch - not the
## same conditions flipping back.
@export var relock_conditions: Array[Interactable] = []

## How many of relock_conditions must succeed before the door re-locks.
## Leave at 0 to require ALL of them. Set to a smaller number for "any 1
## of 2", etc.
@export var relock_required_count: int = 0

# Conditions that have already reported success, so a repeat signal from
# the same node doesn't get counted twice.
var _met_conditions: Array[Interactable] = []

# Same idea as _met_conditions, but for relock_conditions.
var _relock_met_conditions: Array[Interactable] = []


func _ready() -> void:
	super._ready()
	for condition in required_conditions:
		if condition == null:
			push_warning("%s: required_conditions has an empty slot." % name)
			continue
		condition.interaction_succeeded.connect(_on_condition_succeeded.bind(condition))

	for condition in relock_conditions:
		if condition == null:
			push_warning("%s: relock_conditions has an empty slot." % name)
			continue
		condition.interaction_succeeded.connect(_on_relock_condition_succeeded.bind(condition))

	door_locked.connect(_on_relocked)


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


# _on_relock_condition_succeeded
# Called whenever one of relock_conditions reports success. Once enough
# distinct conditions have fired, re-locks the door - reusing all of
# Door's normal lock() behavior for free.
func _on_relock_condition_succeeded(condition: Interactable) -> void:
	if condition in _relock_met_conditions:
		return
	_relock_met_conditions.append(condition)

	var needed: int = relock_required_count if relock_required_count > 0 else relock_conditions.size()
	if _relock_met_conditions.size() >= needed:
		lock()


# relock_conditions_met / relock_conditions_total
# Same as conditions_met/conditions_total above, but for relock_conditions.
func relock_conditions_met() -> int:
	return _relock_met_conditions.size()

func relock_conditions_total() -> int:
	return relock_required_count if relock_required_count > 0 else relock_conditions.size()


# _on_relocked
# Fires whenever this door re-locks (door_locked, from Door.lock() -
# either via relock_conditions above or a direct lock() call elsewhere).
# Clears _met_conditions so required_conditions can be solved again -
# the buttons themselves need to be put back into play separately, via
# their own reactivate_targets (see SimpleCondition/UIConditionItem).
func _on_relocked() -> void:
	_met_conditions.clear()
