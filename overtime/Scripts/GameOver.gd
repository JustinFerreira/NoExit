## No Exit
## Overtime Studios
## Last upadated 1/23/26 by Justin Ferreira
## Game Over Script
## - This screen alowys you to exit or restart

extends CanvasLayer

func _ready() -> void:
	if PlayerManager.DevMode:
		$Control/MarginContainer/VBoxContainer/MainMenuBtn.visible = true


func _on_quit_btn_pressed() -> void:
	AudioManager.KillerShutUp = true
	#Button clikc sound
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	get_tree().quit()


func _on_restart_btn_pressed() -> void:
	AudioManager.KillerShutUp = true
	#Button clikc sound
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	PlayerManager.ResetPlayer()
	get_tree().paused = false
	var current_scene_path = get_tree().current_scene.scene_file_path
	if PlayerManager.Loop1:
		get_tree().change_scene_to_file("res://Levels/Office.tscn")
	else:
		get_tree().change_scene_to_file(current_scene_path)
		



func _on_main_menu_btn_pressed() -> void:
	AudioManager.KillerShutUp = true
	#Button clikc sound
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	PlayerManager.ResetPlayer()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
