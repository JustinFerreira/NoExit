## No Exit
## Overtime Studios
## Ghost Car Event (LEGENDARY - once per playthrough, see GarageEvent)
## - Starts invisible; when the director allows it, the car appears, crashes
##   and vanishes ("VanishCar" animation) as the player walks in.

extends "res://Scripts/Events/GarageEvent.gd"

func _init() -> void:
	tier = Tier.LEGENDARY
	kind = "ghost_car"
	min_killer_distance = 30.0

func _ready() -> void:
	$AnimationPlayer.play("INVISIBLE")

func _fire() -> void:
	$AnimationPlayer.play("VanishCar")
