## No Exit
## Overtime Studios
## Last updated  5/4/26 by Justin Ferreira
## Battery Script
## - This script is attached to the Battery
## for the battery minigame this script changes
## saves the battery instance into the playermanager
## so it can be used across other scripts and
## it changes the look of the battery as you progress
## in the minigame

extends MeshInstance3D


func _ready() -> void:
	#set up flashing for positive and negative zone of battery
	#also setting up reset zones so visibilty for them can be toggled
	AnimationManager.PositiveBatteryResetZone = $PositiveBattery/MeshInstance3D
	AnimationManager.NegativeBatteryResetZone = $NegativeBattery/MeshInstance3D
	AnimationManager.ResetZones.clear()
	for Resetzone in get_tree().get_nodes_in_group("resetzone"):
		AnimationManager.ResetZones.append(Resetzone)


	AnimationManager.PositiveConnection = $PositiveConnection
	AnimationManager.NegativeConnection = $NegativeConnection
	AnimationManager.PositiveBatteryFlash = $PositiveBattery/PositiveBatteryFlash
	AnimationManager.NegativeBatteryFlash = $NegativeBattery/NegativeBatteryFlash
	AnimationManager.loop_animation($PositiveBatteryFlashAnimationPlayer, "PositiveBatteryFlash")
	AnimationManager.loop_animation($NegativeBatteryFlashAnimationPlayer, "NegativeBatteryFlash")

	#giving the player battery itself so the player interactions work properly
	PlayerManager.Battery = self
