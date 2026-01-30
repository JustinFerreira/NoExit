## No Exit
## Overtime Studios

extends Interactable
	
func _process(delta: float) -> void:
	if not PlayerManager.player.interact_ray.get_collider() == self:
		start_flashing()
	else: 
		stop_flashing()

func _on_interacted(body: Variant) -> void:
	
	AnimationManager.GasIntakeFlash.start_flashing()
	AnimationManager.GasIntakeFlash.is_interactable = true
	
	AudioManager.play_sound(AudioManager.ItemPickup)
	PlayerManager.AddToInventory("Gas Canister", 1.5)
	PlayerManager.gotGas_Canister = true
	
	if is_inside_tree():
		get_parent().remove_child(self)
		queue_free()
