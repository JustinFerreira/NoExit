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
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/Loop1Btn.visible = true
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/ParkingGarage.visible = true
		$"MainMenuFirstScreen2/MarginContainer/VBoxContainer/Opening Cutscene".visible = true
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/ParkingGarageL0.visible = true
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/New_Office.visible = true
	elif SettingsManager.Loop0Pass:
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/Loop1Btn.visible = true
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/ParkingGarage.visible = false
		$"MainMenuFirstScreen2/MarginContainer/VBoxContainer/Opening Cutscene".visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/ParkingGarageL0.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/New_Office.visible = false
	else:
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/GreyBoxingBtn.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/ParkingGarage.visible = false
		$"MainMenuFirstScreen2/MarginContainer/VBoxContainer/Opening Cutscene".visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/ParkingGarageL0.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/Loop1Btn.visible = false
		$MainMenuFirstScreen2/MarginContainer/VBoxContainer/New_Office.visible = false

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


func _on_loop_1_btn_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Levels/Office.tscn")


func _on_prev_screen_btn_pressed() -> void:
	$MainMenuFirstScreen2.visible = false
	$MainMenuFirstScreen.visible = true


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


func _on_new_office_pressed() -> void:
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Levels/New_Office.tscn")
