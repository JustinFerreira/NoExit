##No Exit
## Overtime Studios
## Last updated 10/18/26 by Justin Ferreira
## Gas Canister Script
## - this is the pickup item
## Pickup, flashing, inventory and dialog are set in the Inspector
## (ExaminableItem). This only adds what's special to the gas canister.

extends ExaminableItem

func _on_picked_up() -> void:
	PlayerManager.gotGas_Canister = true
	AnimationManager.GasIntakeFlash.start_flashing()
	AnimationManager.GasIntakeFlash.toggle_interactable(true)
