## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## - Main Menu Script
## this script makes the main menu work proplery
## giving buttons functionality so they lead to the correct places.

extends CanvasLayer

@onready var animation_player = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerManager.MainMenu = true
	SettingsManager.MainMenuShader = $Shader
	if SettingsManager.settings.video.shader:
		$Shader.visible = true
	else:
		$Shader.visible = false
	PlayerManager.ResetPlayer()
	PlayerManager.Loop1 = false
	AudioManager.play_music(AudioManager.MainMenuMusic)
	if PlayerManager.FirstOpen == true:
		animation_player.play("FadeIn")
		PlayerManager.FirstOpen = false
	else:
		$FadeColorRect.visible = false
		AudioManager.cancel_loop_sfx()
	

func _process(delta: float) -> void:
	if PlayerManager.DevMode:
		$MainMenuSecondScreen/MarginContainer/VBoxContainer/Loop1Btn.visible = true
		$MainMenuSecondScreen/MarginContainer/VBoxContainer/ParkingGarage.visible = true
		$"MainMenuSecondScreen/MarginContainer/VBoxContainer/OpeningCutscene".visible = true
		$MainMenuSecondScreen/MarginContainer/VBoxContainer/New_Office.visible = true
	elif SettingsManager.Loop0Pass:
		$MainMenuSecondScreen/MarginContainer/VBoxContainer/Loop1Btn.visible = true
		$MainMenuSecondScreen/MarginContainer/VBoxContainer/ParkingGarage.visible = false
		$"MainMenuSecondScreen/MarginContainer/VBoxContainer/OpeningCutscene".visible = false
		$MainMenuSecondScreen/MarginContainer/VBoxContainer/New_Office.visible = false
	else:
		$MainMenuSecondScreen/MarginContainer/VBoxContainer/ParkingGarage.visible = false
		$"MainMenuSecondScreen/MarginContainer/VBoxContainer/OpeningCutscene".visible = false
		$MainMenuSecondScreen/MarginContainer/VBoxContainer/Loop1Btn.visible = false
		$MainMenuSecondScreen/MarginContainer/VBoxContainer/New_Office.visible = false
		


func _on_start_btn_pressed() -> void:
	#Button Click Noise
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	$MainMenuFirstScreen.visible = false
	$MainMenuSecondScreen.visible = true


func _on_quit_btn_pressed() -> void:
	#Button Click Noise
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	get_tree().quit()


func _on_settings_btn_pressed() -> void:
	#Button Click Noise
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	$SettingsMenu.visible = true


func _on_loop_1_btn_pressed() -> void:
	#Button Click Noise
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	AudioManager.cancel_music()
	PlayerManager.OpeningCutscene = false
	PlayerManager.Loop0 = false
	PlayerManager.Loop1 = true
	get_tree().change_scene_to_file("res://Levels/Office.tscn")
	PlayerManager.MainMenu = false


func _on_prev_screen_btn_pressed() -> void:
	#Button Click Noise
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	
	$MainMenuSecondScreen.visible = false
	$MainMenuFirstScreen.visible = true


func _on_textured_parking_garage_pressed() -> void:
	#Button Click Noise
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	AudioManager.cancel_music()
	PlayerManager.testing = true
	get_tree().change_scene_to_file("res://Levels/ParkingGarage.tscn")
	PlayerManager.MainMenu = false

func _on_loop_0_pressed() -> void:
	PlayerManager.deaths = 0
	
	#Button Click Noise
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	#deaths 0?
	PlayerManager.OpeningCutscene = true
	PlayerManager.Loop0 = false
	PlayerManager.Loop1 = false
	if PlayerManager.DevMode == true:
		PlayerManager.OpeningCutscene = false
		PlayerManager.Loop0 = true
		PlayerManager.Loop1 = false
		get_tree().change_scene_to_file("res://Levels/Office.tscn")
		PlayerManager.MainMenu = false
		AudioManager.cancel_music()
		return
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Levels/OpeningCutscene.tscn")
	PlayerManager.MainMenu = false

func _on_opening_cutscene_pressed() -> void:
	#Button Click Noise
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	#deaths 0?
	PlayerManager.OpeningCutscene = true
	PlayerManager.Loop0 = false
	PlayerManager.Loop1 = false
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Levels/OpeningCutscene.tscn")



func _on_new_office_pressed() -> void:
	#Button Click Noise
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Levels/Greyboxing/Offices/New_Office.tscn")
	PlayerManager.MainMenu = false


func _on_new_game_btn_pressed() -> void:
	SettingsManager.Loop0Pass = false
	SettingsManager.Loop1Pass = false
	PlayerManager.deaths = 0
	
	#Button Click Noise
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	#deaths 0?
	PlayerManager.OpeningCutscene = true
	PlayerManager.Loop0 = false
	PlayerManager.Loop1 = false
	if PlayerManager.DevMode == true:
		PlayerManager.OpeningCutscene = false
		PlayerManager.Loop0 = true
		PlayerManager.Loop1 = false
		get_tree().change_scene_to_file("res://Levels/Office.tscn")
		PlayerManager.MainMenu = false
		AudioManager.cancel_music()
		return
	AudioManager.cancel_music()
	get_tree().change_scene_to_file("res://Levels/OpeningCutscene.tscn")
	PlayerManager.MainMenu = false
