## No Exit
## Overtime Studios
## Last upadated 1/19/26 by Justin Ferreira
## Battery Script
## - This script is attached to the Battery 
## for the battery minigame this script changes
## saves the battery instance into the playermanager
## so it can be used across other scripts and
## it changes the look of the battery as you progress
## in the minigame

extends MeshInstance3D


# Called when the node enters the scene tree for the first time.
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
	AnimationManager.PositiveBatteryFlashAnimationPlayer = $PositiveBatteryFlashAnimationPlayer
	AnimationManager.NegativeBatteryFlashAnimationPlayer = $NegativeBatteryFlashAnimationPlayer
	AnimationManager.ActivatePositiveBatteryFlashAnimationPlayer()
	AnimationManager.ActivateNegativeBatteryFlashAnimationPlayer()
	AnimationManager.PositiveBatteryFlashAnimationPlayer.play("PositiveBatteryFlash")
	AnimationManager.NegativeBatteryFlashAnimationPlayer.play("NegativeBatteryFlash")
	
	#giving the player battery itself so the player interactions work properly
	PlayerManager.Battery = self


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
