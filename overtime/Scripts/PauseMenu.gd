extends Control

func _ready() -> void:
	$AnimationPlayer.play("RESET")

func resume():
	get_tree().paused = false
	$AnimationPlayer.play("Unpause")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func pause():
	get_tree().paused = true
	$AnimationPlayer.play("Pause")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		


func _on_resume_btn_pressed() -> void:
	resume()


func _on_restart_btn_pressed() -> void:
	resume()
	get_tree().reload_current_scene()


func _on_quit_btn_pressed() -> void:
	get_tree().quit()


func _on_settings_btn_pressed() -> void:
	pass # Replace with function body.


func _on_main_menu_btn_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
