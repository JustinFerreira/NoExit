extends Interactable


func _on_interacted(body: Variant) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
