## No Exit
## Overtime Studios
## Fog Killer Eyes Event (LEGENDARY - once per playthrough, see GarageEvent)
## - When the director allows it, the fog rolls in, the killer's glowing eyes
##   appear in it with a heavy breath, then vanish and the fog clears.

extends "res://Scripts/Events/GarageEvent.gd"

func _init() -> void:
	tier = Tier.LEGENDARY
	kind = "killer_eyes"
	min_killer_distance = 45.0

func _fire() -> void:
	HelperManager.fade_fog_density(1, 1.5)
	await get_tree().create_timer(2).timeout
	HelperManager.killer_eyes.visible = true
	AudioManager.play_sound(AudioManager.HeavyBreath)
	await get_tree().create_timer(3).timeout
	HelperManager.killer_eyes.visible = false
	HelperManager.fade_fog_density(-8, 1.5)
