## OverTime Production
## Last upadated 11/16/25 by Justin Ferreira
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
	AnimationManager.PositiveBatteryFlash = $PositiveBattery/PositiveBatteryFlash
	AnimationManager.NegativeBatteryFlash = $NegativeBattery/NegativeBatteryFlash
	AnimationManager.PositiveBatteryFlashAnimationPlayer = $PositiveBatteryFlashAnimationPlayer
	AnimationManager.NegativeBatteryFlashAnimationPlayer = $NegativeBatteryFlashAnimationPlayer
	AnimationManager.ActivatePositiveBatteryFlashAnimationPlayer()
	AnimationManager.ActivateNegativeBatteryFlashAnimationPlayer()
	AnimationManager.PositiveBatteryFlashAnimationPlayer.play("PositiveBatteryFlash")
	AnimationManager.NegativeBatteryFlashAnimationPlayer.play("NegativeBatteryFlash")
	PlayerManager.Battery = self


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if self.visible:
		if PlayerManager.PositiveConnected:
			$PositiveConnection.visible = true
		if PlayerManager.NegativeConnected:
			$NegativeConnection.visible = true
