## No Exit
## Overtime Studios
## Last upadated 1/19/26 by Justin Ferreira
## Cubicle Script
## This script is for the players cubicle,
## when the player travels far from their cubicle and
## they haven't finished the actions at it the cubicle will
## flash

extends Interactable

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#detect when player is in cubicle range to not flash
func _on_area_3d_area_entered(area: Area3D) -> void:
	stop_flashing()

#detect when player walks away and see whether to flash or not
func _on_area_3d_area_exited(area: Area3D) -> void:
	if not PlayerManager.has_item("Car Keys"):
		start_flashing()
