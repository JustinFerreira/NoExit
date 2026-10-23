## No Exit
## Overtime Studios
## Last upadated 10/18/26 by Justin Ferreira
## Box Script
## - This is the script for the pickup item box
## The box is added (and equipped) as soon as it's examined, so when the
## examine closes store_in_box sees the Box equipped and stores the box on
## the desk like the other desk items.

extends ExaminableItem

func _on_examine_started() -> void:
	PlayerManager.AddToInventory("Box", 0.5, true)
