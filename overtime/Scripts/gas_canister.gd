extends Interactable

func _on_interacted(body: Variant) -> void:
	PlayerManager.AddToInventory("Gas Canister", 1.5)
	PlayerManager.gotGas_Canister = true
	
	if is_inside_tree():
		get_parent().remove_child(self)
		queue_free()
