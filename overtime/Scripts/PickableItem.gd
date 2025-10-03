extends Interactable

func _on_interacted(body: Variant) -> void:
	PlayerManager.AddToInventory("DoorKey", 0.5)
	PlayerManager.gotKeys = true
	
	if is_inside_tree():
		get_parent().remove_child(self)
		queue_free()
