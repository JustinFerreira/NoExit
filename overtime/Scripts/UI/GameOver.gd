## No Exit
## Overtime Studios
## Last updated 1/23/26 by Justin Ferreira
## Game Over Script
## - The game over screen: restart or quit to the main menu.

extends CanvasLayer

## True when this game over ended a rogue run (Restart starts a new run).
var _rogue_over := false

func _ready() -> void:
	if PlayerManager.DevMode:
		$Control/MarginContainer/VBoxContainer/MainMenuBtn.visible = true
	visibility_changed.connect(_on_shown)

## When the screen appears at the end of a rogue run: end the run and show
## how far the player got.
func _on_shown() -> void:
	if not visible or not RogueRun.active:
		return
	_rogue_over = true
	var survived := RogueRun.end_run()
	var box := $Control/MarginContainer/VBoxContainer
	var summary := Label.new()
	summary.text = "Run over - you survived %d round%s (best: %d)" % [survived, "" if survived == 1 else "s", RogueRun.best_rounds]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(summary)
	box.move_child(summary, 1)
	box.get_node("RestartBtn").text = "New Run"
	box.get_node("MainMenuBtn").visible = true


func _on_quit_btn_pressed() -> void:
	AudioManager.KillerShutUp = true
	#Button clikc sound
	AudioManager.play_sound(AudioManager.GetKeyPress())

	get_tree().quit()


func _on_restart_btn_pressed() -> void:
	AudioManager.KillerShutUp = true
	#Button clikc sound
	AudioManager.play_sound(AudioManager.GetKeyPress())

	PlayerManager.dying = false
	PlayerManager.InAnimation = false
	if _rogue_over:
		get_tree().paused = false
		RogueRun.start_run()
		return

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
