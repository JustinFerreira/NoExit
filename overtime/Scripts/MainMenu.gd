extends CanvasLayer



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AudioManager.cancel_loop_sfx()
	AudioManager.play_music(AudioManager.MainMenuMusic)
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_btn_pressed() -> void:
	$MainMenuFirstScreen.visible = false
	$MainMenuFirstScreen2.visible = true


func _on_quit_btn_pressed() -> void:
	get_tree().quit()


func _on_settings_btn_pressed() -> void:
	$SettingsMenu.visible = true


func _on_main_btn_pressed() -> void:
	AudioManager.cancel_music()
	AudioManager.play_music(AudioManager.GamePlayMusic)
	get_tree().change_scene_to_file("res://Scenes/Levels/main.tscn")


func _on_grey_boxing_btn_pressed() -> void:
	AudioManager.cancel_music()
	AudioManager.play_music(AudioManager.GamePlayMusic)
	get_tree().change_scene_to_file("res://Scenes/Levels/GreyBoxLevel.tscn")


func _on_loop_1_btn_pressed() -> void:
	AudioManager.cancel_music()
	AudioManager.play_music(AudioManager.GamePlayMusic)
	get_tree().change_scene_to_file("res://Scenes/Levels/Loop1.tscn")


func _on_parking_keys_l_1_pressed() -> void:
	AudioManager.cancel_music()
	AudioManager.play_music(AudioManager.GamePlayMusic)
	get_tree().change_scene_to_file("res://Scenes/Levels/ParkingGarageKeysLoop1.tscn")


func _on_parking_l_1_pressed() -> void:
	AudioManager.cancel_music()
	AudioManager.play_music(AudioManager.GamePlayMusic)
	get_tree().change_scene_to_file("res://Scenes/Levels/ParkingGarageLoop1.tscn")


func _on_prev_screen_btn_pressed() -> void:
	$MainMenuFirstScreen2.visible = false
	$MainMenuFirstScreen.visible = true
