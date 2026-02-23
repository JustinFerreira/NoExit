## No Exit
## Overtime Studios
## Last update 2/14/26 by Justin Ferreira
## Pause Menu Script
## - this script give functionality for both pause menus
## allowing player or developer mutiple options for their
## experience

extends Control

func _ready() -> void:
	$AnimationPlayer.play("RESET")

func resume():
	if PlayerManager.MinigameMode == true && PlayerManager.minigameTwo == false:
		get_tree().paused = false
		$AnimationPlayer.play("Unpause")
		return
	elif PlayerManager.MinigameMode == true && PlayerManager.minigameTwo == true:
		get_tree().paused = false
		$AnimationPlayer.play("Unpause")
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return
	if PlayerManager.multiDialog:
		pass
	else:
		PlayerManager.player.CURSOR.visible = true
	if PlayerManager.dialoging == true: 
		PlayerManager.RevealDialog()
	get_tree().paused = false
	$AnimationPlayer.play("Unpause")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func pause():
	#if PlayerManager.DevMode:
		#$ColorRect.visible = true
	#$SettingsMenu.visible = false
	#Button clikc sound
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	PlayerManager.player.CURSOR.visible = false
	if PlayerManager.player.DIALOG.visible:
		PlayerManager.HideDialog()
	get_tree().paused = true
	$AnimationPlayer.play("Pause")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		

func _on_resume_btn_pressed() -> void:
	#Button clikc sound
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	resume()
	$SettingsMenu.visible = false


func _on_restart_btn_pressed() -> void:
	#Button clikc sound
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	resume()
	PlayerManager.ResetPlayer()
	get_tree().reload_current_scene()


func _on_quit_btn_pressed() -> void:
	get_tree().quit()


func _on_settings_btn_pressed() -> void:
	#Button clikc sound
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	if PlayerManager.DevMode:
		$ColorRect.visible = false
	$SettingsMenu.visible = true


func _on_main_menu_btn_pressed() -> void:
	#Button clikc sound
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")


func _on_disable_killer_btn_toggled(toggled_on: bool) -> void:
	#Button clikc sound
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	SettingsManager.KillerDisabled = toggled_on
