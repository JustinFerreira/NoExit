extends Interactable

func _on_interacted(body: Variant) -> void:
	AudioManager.play_sound(AudioManager.ItemPickup)
	PlayerManager.AddToInventory("Gas Canister", 1.5)
	PlayerManager.gotGas_Canister = true
	
	if is_inside_tree():
		get_parent().remove_child(self)
		queue_free()
