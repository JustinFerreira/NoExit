## No Exit
## Overtime Studios
## Car Keys
## - The car keys on the player's desk (an ExaminableItem). Pickup,
##   inventory and sounds are set in the Inspector; this adds the keys'
##   own dialog and records that the player has them.

extends ExaminableItem

func _show_examine_dialog() -> void:
	PlayerManager.CharacterHintDialog(EventManager.keys_pickup, EventManager.keys_pickup_hint)

func _on_examine_started() -> void:
	PlayerManager.firstdialog = false

func _on_picked_up() -> void:
	PlayerManager.gotKeys = true
