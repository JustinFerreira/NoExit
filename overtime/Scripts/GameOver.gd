extends CanvasLayer


func _on_quit_btn_pressed() -> void:
	get_tree().quit()


func _on_restart_btn_pressed() -> void:
	PlayerManager.ResetPlayer()
	get_tree().paused = false
	var current_scene_path = get_tree().current_scene.scene_file_path
	if PlayerManager.Loop1:
		get_tree().change_scene_to_file("res://Levels/Loop1.tscn")
	else:
		get_tree().change_scene_to_file(current_scene_path)
