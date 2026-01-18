extends CanvasLayer

@onready var animation_player = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerManager.ResetPlayer()
	PlayerManager.Loop1 = false
	animation_player.connect("animation_finished", _on_animation_finished)
	if PlayerManager.FirstOpen == true:
		animation_player.play("FadeIn")
		PlayerManager.FirstOpen = false
	else:
		$MainMenuFirstScreen/ColorRect.visible = false
		AudioManager.cancel_loop_sfx()
		AudioManager.play_music(AudioManager.MainMenuMusic)
	

func _process(delta: float) -> void:
	if PlayerManager.DevMode:
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/GreyBoxingBtn.visible = true
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/MainBtn.visible = true
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/ParkingKeysL1.visible = true
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/ParkingL1.visible = true
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/AlternateParking.visible = true
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/AlternateParkingKeys.visible = true
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/TexturedParkingGarage.visible = true
		$"MainMenuFirstScreen2/MarginContainer/VBoxContainer/Opening Cutscene".visible = true
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/ParkingGarageL0.visible = true
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/Loop1Btn.visible = true
	elif SettingsManager.Loop0Pass:
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/Loop1Btn.visible = true
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/GreyBoxingBtn.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/MainBtn.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/ParkingKeysL1.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/ParkingL1.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/AlternateParking.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/AlternateParkingKeys.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/TexturedParkingGarage.visible = false
		$"MainMenuFirstScreen2/MarginContainer/VBoxContainer/Opening Cutscene".visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/ParkingGarageL0.visible = false
	else:
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/GreyBoxingBtn.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/MainBtn.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/ParkingKeysL1.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/ParkingL1.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/AlternateParking.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/AlternateParkingKeys.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/TexturedParkingGarage.visible = false
		$"MainMenuFirstScreen2/MarginContainer/VBoxContainer/Opening Cutscene".visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/ParkingGarageL0.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/Loop1Btn.visible = false

func _on_animation_finished(anim_name: String):
	
	if anim_name == "FadeIn":
		pass
		#animation_player.play("camera_anim")
		


func _on_start_btn_pressed() -> void:
	$MainMenuFirstScreen.visible = false
	$MainMenuFirstScreen2.visible = true


func _on_quit_btn_pressed() -> void:
	get_tree().quit()


func _on_settings_btn_pressed() -> void:
	$SettingsMenu.visible = true


func _on_main_btn_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Levels/main.tscn")


func _on_grey_boxing_btn_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Levels/GreyBoxLevel.tscn")


func _on_loop_1_btn_pressed() -> void:
	AudioManager.cancel_music()
	AudioManager.play_music(AudioManager.OfficeWhiteNoise)
	AudioManager.OfficeMusicOn = true
	get_tree().change_scene_to_file("res://Levels/Loop1.tscn")


func _on_parking_keys_l_1_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Levels/ParkingGarageKeysLoop1.tscn")


func _on_parking_l_1_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Levels/ParkingGarageLoop1.tscn")


func _on_prev_screen_btn_pressed() -> void:
	$MainMenuFirstScreen2.visible = false
	$MainMenuFirstScreen.visible = true


func _on_alternate_parking_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Levels/AlternateParkingGarageL1.tscn")


func _on_alternate_parking_keys_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Levels/AlternateParkingGarageKeysL1.tscn")


func _on_textured_parking_garage_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Levels/ParkingGarageL1.tscn")


func _on_loop_0_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Levels/OpeningCutscene.tscn")


func _on_opening_cutscene_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Levels/OpeningCutscene.tscn")


func _on_parking_garage_l_0_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Levels/ParkingGarageL0.tscn")
