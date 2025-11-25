## OverTime Production
## Last upadated 11/16/25 by Justin Ferreira
## BatteryPickup Script
## - This is the script for the pickup item battery

extends Interactable

func _ready() -> void:
	AnimationManager.BatteryFlashAnimationPlayer = $AnimationPlayer
	AnimationManager.ActivateBatteryFlashAnimationPlayer()
	$AnimationPlayer.play("BatteryFlash")
	
func _process(delta: float) -> void:
	if not PlayerManager.player.interact_ray.get_collider() == self:
		$BatteryFlash.visible = true
	else: 
		$BatteryFlash.visible = false
		

func _on_interacted(body: Variant) -> void:
	AudioManager.play_sound(AudioManager.ItemPickup)
	PlayerManager.AddToInventory("Battery", 1.0)
	PlayerManager.gotBattery = true
	AnimationManager.HoodFlash.visible = true
	
	if is_inside_tree():
		get_parent().remove_child(self)
		queue_free()
