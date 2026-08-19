## No Exit
## Overtime Studios
## Last updated 8/18/26 by Justin Ferreira
## Color Gate Puzzle Script
## - Three buttons, each opening its own group of color-coded doors.
##   Only max_open_groups colors can be open at once (default 2) -
##   opening one more closes whichever group has been open the LONGEST,
##   no matter what order the buttons get clicked in after that.
## - Doors here are plain Door nodes, not ConditionDoor. This
##   controller calls unlock()/lock() on them directly - ConditionDoor's
##   required_conditions/relock_conditions have no memory of WHEN each
##   button fired relative to the others, so they can't express "close
##   whichever opened first" on their own.
## - Buttons just need SimpleCondition with one_shot = false (or any
##   other Interactable) - this controller listens to the raw
##   `interacted` signal, not interaction_succeeded, so a button can be
##   clicked over and over.

extends Node
class_name ColorGatePuzzle

@export var pink_button: Interactable
@export var pink_doors: Array[Door] = []

@export var yellow_button: Interactable
@export var yellow_doors: Array[Door] = []

@export var blue_button: Interactable
@export var blue_doors: Array[Door] = []

## How many color groups can be open at the same time. Opening one more
## than this closes the group that has been open the longest.
@export var max_open_groups: int = 2

# Doors for each color, keyed by the same color names used in _open_order.
var _group_doors: Dictionary = {}

# Colors currently open, oldest first - index 0 is the next one evicted.
var _open_order: Array[String] = []


func _ready() -> void:
	_group_doors = {
		"pink": pink_doors,
		"yellow": yellow_doors,
		"blue": blue_doors,
	}
	_connect_button(pink_button, "pink")
	_connect_button(yellow_button, "yellow")
	_connect_button(blue_button, "blue")


func _connect_button(button: Interactable, color: String) -> void:
	if button == null:
		push_warning("%s: %s_button not assigned." % [name, color])
		return
	button.interacted.connect(_on_button_interacted.bind(color))


# _on_button_interacted
# A color already open is left alone - clicking its button again does
# nothing. Otherwise it opens, and if that pushes us past
# max_open_groups, the oldest-opened color gets closed to make room.
func _on_button_interacted(_body: Variant, color: String) -> void:
	if color in _open_order:
		return

	_open_order.append(color)
	for door in _group_doors[color]:
		if door:
			door.unlock()

	while _open_order.size() > max_open_groups:
		_close_color(_open_order.pop_front())


func _close_color(color: String) -> void:
	for door in _group_doors[color]:
		if door:
			door.lock()
