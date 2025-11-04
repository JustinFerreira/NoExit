extends Control

## Sound Settings
@onready var master_slider = $ColorRect/TabContainer/VOLUME/SoundSettingsVbox/MasterVbox/MasterSlider
@onready var music_slider = $ColorRect/TabContainer/VOLUME/SoundSettingsVbox/MusicVbox/MusicSlider
@onready var sfx_slider = $ColorRect/TabContainer/VOLUME/SoundSettingsVbox/SFXVbox/SFXSlider
@onready var mute_check = $ColorRect/TabContainer/VOLUME/SoundSettingsVbox/MuteCheckBox

## Visual Settings
@onready var fullscreen_check = $ColorRect/TabContainer/VISUAL/VisualSettingsVbox/FullScreenCheckBox

## Game Settings
@onready var shifthold_check = $ColorRect/TabContainer/GAME/GameSettingsVbox/ShiftHoldRunCheckBox
@onready var sensitivity_slider = $ColorRect/TabContainer/GAME/GameSettingsVbox/SensitivityVbox/SensitivitySlider
@onready var headbob_check = $ColorRect/TabContainer/GAME/GameSettingsVbox/HeadBobCheckBox

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	master_slider.value = SettingsManager.settings.audio.master_volume
	music_slider.value = SettingsManager.settings.audio.music_volume
	sfx_slider.value = SettingsManager.settings.audio.sfx_volume
	mute_check.button_pressed = SettingsManager.settings.audio.muted
	fullscreen_check.button_pressed = SettingsManager.settings.video.fullscreen
	var normalized_value = (SettingsManager.settings.game.sensitivity - SettingsManager.min_sensitivity) / (SettingsManager.max_sensitivity - SettingsManager.min_sensitivity) * 100
	sensitivity_slider.value = normalized_value
	headbob_check.button_pressed = SettingsManager.settings.game.headbob
	shifthold_check.button_pressed = SettingsManager.settings.game.hold_shift
	# Connect signal
	mute_check.toggled.connect(_on_mute_toggled)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_mute_toggled(toggled):
	SettingsManager.settings.audio.muted = toggled
	SettingsManager.apply_settings()
	SettingsManager.save_settings()
	master_slider.editable = not toggled
	music_slider.editable = not toggled
	sfx_slider.editable = not toggled
	if toggled:
		mute_check.add_theme_color_override("font_color", Color.RED)
	else:
		mute_check.remove_theme_color_override("font_color")


func _on_master_slider_value_changed(value: float) -> void:
	SettingsManager.settings.audio.master_volume = value
	SettingsManager.apply_settings()
	SettingsManager.save_settings()

func _on_music_slider_value_changed(value: float) -> void:
	SettingsManager.settings.audio.music_volume = value
	SettingsManager.apply_settings()
	SettingsManager.save_settings()


func _on_sfx_slider_value_changed(value: float) -> void:
	SettingsManager.settings.audio.sfx_volume = value
	SettingsManager.apply_settings()
	SettingsManager.save_settings()


func _on_button_pressed() -> void:
	$".".visible = false
	


func _on_full_screen_check_box_toggled(toggled: bool) -> void:
	SettingsManager.settings.video.fullscreen = toggled
	SettingsManager.apply_settings()
	SettingsManager.save_settings()
		
	


func _on_sensitivity_slider_value_changed(value: float) -> void:
	# Map slider value (0-100) to 0.001 - 0.05
	var sensitivity_value = lerp(0.001, 0.05, value / 100.0)
	SettingsManager.settings.game.sensitivity = sensitivity_value
	SettingsManager.apply_settings()
	SettingsManager.save_settings()


func _on_shift_hold_run_check_box_toggled(toggled: bool) -> void:
	SettingsManager.settings.game.hold_shift = toggled
	SettingsManager.apply_settings()
	SettingsManager.save_settings()


func _on_head_bob_check_box_toggled(toggled: bool) -> void:
	SettingsManager.settings.game.headbob = toggled
	SettingsManager.apply_settings()
	SettingsManager.save_settings()
