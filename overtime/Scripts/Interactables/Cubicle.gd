## No Exit
## Overtime Studios
## Cubicle
## - The player's cubicle. It flashes while the player is away from it
##   without the car keys (there's still something to do there) and stops
##   when they come back.

extends Interactable

## The desk itself can't be clicked, so it never gets the close-by outline -
## only the "go back to your desk" flash below.
func _ready() -> void:
	super._ready()
	is_interactable = false

## Player is back at the cubicle: stop flashing.
func _on_area_3d_area_entered(_area: Area3D) -> void:
	stop_flashing()

## Player walked away: flash if the keys are still on the desk.
func _on_area_3d_area_exited(_area: Area3D) -> void:
	if not PlayerManager.has_item("Car Keys"):
		start_flashing()
