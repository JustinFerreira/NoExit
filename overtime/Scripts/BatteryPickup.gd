extends Interactable

func _on_interacted(body: Variant) -> void:
	AudioManager.play_sound(AudioManager.ItemPickup)
	PlayerManager.AddToInventory("Battery", 1.0)
	PlayerManager.gotBattery = true
	
	if is_inside_tree():
		get_parent().remove_child(self)
		queue_free()
