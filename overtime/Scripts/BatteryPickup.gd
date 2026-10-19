## No Exit
## Overtime Studios
## Last upadated 10/18/26 by Justin Ferreira
## BatteryPickup Script
## - This is the script for the pickup item battery
## Pickup, flashing, inventory and dialog are set in the Inspector
## (ExaminableItem). This only adds what's special to the battery.

extends ExaminableItem

func _on_picked_up() -> void:
	#changes player state (EventManager?)
	PlayerManager.gotBattery = true
	#turns Hood Flash on (EventManager?)
	AnimationManager.HoodFlash.toggle_interactable(true)
	AnimationManager.HoodFlash.start_flashing()
