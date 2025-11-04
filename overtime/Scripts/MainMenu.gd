extends CanvasLayer

@onready var animation_player = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerManager.Loop1 = false
	animation_player.connect("animation_finished", _on_animation_finished)
	if PlayerManager.FirstOpen == true:
		animation_player.play("FadeIn")
		PlayerManager.FirstOpen = false
	else:
		$MainMenuFirstScreen/ColorRect.visible = false
		AudioManager.cancel_loop_sfx()
		AudioManager.play_music(AudioManager.MainMenuMusic)
	
	
	
	


func _on_animation_finished(anim_name: String):
	
	if anim_name == "FadeIn":
		animation_player.play("camera_anim")
		

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
	get_tree().change_scene_to_file("res://Scenes/Levels/main.tscn")


func _on_grey_boxing_btn_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Scenes/Levels/GreyBoxLevel.tscn")


func _on_loop_1_btn_pressed() -> void:
	AudioManager.cancel_music()
	AudioManager.play_music(AudioManager.OfficeWhiteNoise)
	AudioManager.OfficeMusicOn = true
	get_tree().change_scene_to_file("res://Scenes/Levels/Loop1.tscn")


func _on_parking_keys_l_1_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Scenes/Levels/ParkingGarageKeysLoop1.tscn")


func _on_parking_l_1_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Scenes/Levels/ParkingGarageLoop1.tscn")


func _on_prev_screen_btn_pressed() -> void:
	$MainMenuFirstScreen2.visible = false
	$MainMenuFirstScreen.visible = true


func _on_alternate_parking_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Scenes/Levels/AlternateParkingGarageL1.tscn")


func _on_alternate_parking_keys_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Scenes/Levels/AlternateParkingGarageKeysL1.tscn")


func _on_textured_parking_garage_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Scenes/Levels/ParkingGarageL1.tscn")
