## OverTime Production
## Last upadated 11/24/25 by Justin Ferreira
## Box Script
## - This is the script for the pickup item box

extends Interactable

func _on_interacted(body: Variant) -> void:
	PlayerManager.AddToInventory("Box", 0.5, true)
	AudioManager.play_sound(AudioManager.ItemPickup)
	
	if is_inside_tree():
		get_parent().remove_child(self)
		queue_free()
