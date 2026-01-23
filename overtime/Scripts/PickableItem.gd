## No Exit
## Overtime Studios

extends Interactable

func _on_interacted(body: Variant) -> void:
	PlayerManager.AddToInventory("Object", 0.5)
	PlayerManager.gotKeys = true
	AudioManager.play_sound(AudioManager.keys)
	
	if is_inside_tree():
		get_parent().remove_child(self)
		queue_free()
