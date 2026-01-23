## No Exit
## Overtime Studios
## Last upadated 1/19/26 by Justin Ferreira
## BatteryPickup Script
## - This is the script for the pickup item battery

extends Interactable

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#set up flashing animation
	AnimationManager.BatteryFlashAnimationPlayer = $AnimationPlayer
	AnimationManager.ActivateBatteryFlashAnimationPlayer()
	AnimationManager.BatteryFlashAnimationPlayer.play("BatteryFlash")
	
func _process(delta: float) -> void:
	#stop flashing when player is about to interact
	if not PlayerManager.player.interact_ray.get_collider() == self:
		$BatteryFlash.visible = true
	else: 
		$BatteryFlash.visible = false
		

func _on_interacted(body: Variant) -> void:
	#pick up sound
	AudioManager.play_sound(AudioManager.ItemPickup)
	#add to inventory
	PlayerManager.AddToInventory("Battery", 1.0)
	#changes player state (EventManager?)
	PlayerManager.gotBattery = true
	#turns Hood Flash on (EventManager?)
	AnimationManager.HoodFlash.visible = true
	
	#get rid of object in scene 
	if is_inside_tree():
		get_parent().remove_child(self)
		queue_free()
