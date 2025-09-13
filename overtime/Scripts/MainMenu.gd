extends CanvasLayer



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AudioManager.play_music(AudioManager.MainMenuMusic)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_btn_pressed() -> void:
	AudioManager.cancel_music()
	AudioManager.play_music(AudioManager.GamePlayMusic)
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_quit_btn_pressed() -> void:
	get_tree().quit()


func _on_settings_btn_pressed() -> void:
	$SettingsMenu.visible = true
