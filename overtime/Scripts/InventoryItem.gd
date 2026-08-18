## No Exit
## Overtime Studios
## Last updated 8/17/26 by Justin Ferreira
## Inventory Item Script
## - Generic, reusable "pick this up" script for any object that should
##   just be added to the player's inventory when interacted with (a
##   key, a tool, a note, whatever). Give it a name in the Inspector and
##   it's ready - no per-item scripting needed.

extends Interactable
class_name InventoryItem

## ---------------------------------------------------------------------
## Inventory Entry
## ---------------------------------------------------------------------

## Name added to PlayerManager.Inventory. This is also what other
## scripts search for - e.g. Door.key_name checks PlayerManager.has_item()
## against this exact string, so a key's item_name just needs to match
## a door's key_name.
@export var item_name: String = ""

## Passed straight through to PlayerManager.AddToInventory - kept here
## in case weight ever gets used for carry-limits, etc.
@export var item_weight: float = 0.0

## If true, this item becomes the player's equipped item once picked up
## (same flag AddToInventory already supports).
@export var is_equippable: bool = false

## ---------------------------------------------------------------------
## Pickup Feedback (optional)
## ---------------------------------------------------------------------

## Sound played through AudioManager when this item is picked up. Leave
## empty in the Inspector and nothing will play.
@export var pickup_sound: AudioStream

## ---------------------------------------------------------------------
## After Pickup
## ---------------------------------------------------------------------

## If true (default), this object is removed from the scene once it's
## picked up. If false, it's just made non-interactable and left in
## place - useful if something else (a parent node, an animation) needs
## to handle hiding it instead.
@export var remove_on_pickup: bool = true

## Emitted right after this item is added to the inventory. Kept as its
## own signal (in addition to the generic interaction_succeeded on
## Interactable) in case something wants to listen specifically for a
## pickup rather than any generic success.
signal picked_up


# _on_interacted
# Called by Interactable when the player clicks this item (wired up via
# the node's Signals tab in the editor, same as every other Interactable).
func _on_interacted(_body: Variant) -> void:
	if item_name == "":
		push_warning("%s: InventoryItem has no item_name set." % name)
		return

	PlayerManager.AddToInventory(item_name, item_weight, is_equippable)

	# Disable further interaction immediately so this can't be picked up
	# twice, whether or not it's actually removed from the scene below.
	_on_interaction_complete()

	if pickup_sound:
		AudioManager.play_sound(pickup_sound)

	picked_up.emit()
	# Also report the generic success, so this item can be dropped
	# straight into a ConditionDoor's required_conditions with no
	# extra wiring.
	mark_success()

	if remove_on_pickup:
		if is_inside_tree():
			get_parent().remove_child(self)
		queue_free()
