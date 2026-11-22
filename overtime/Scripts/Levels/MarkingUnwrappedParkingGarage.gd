## No Exit
## Overtime Studios
## Parking Garage Lights List
## - Put on the parking garage level: hands every light in the "Lights"
##   group to PlayerManager (ParkingGarageLights) for the blackout events.

extends Node3D

func _ready() -> void:
	PlayerManager.ParkingGarageLights = get_tree().get_nodes_in_group("Lights")
