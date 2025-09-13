extends Control

@onready var master_slider = $ColorRect/MarginContainer/VBoxContainer/SoundSettingsVbox/MasterVbox/MasterSlider
@onready var music_slider = $ColorRect/MarginContainer/VBoxContainer/SoundSettingsVbox/MusicVbox/MusicSlider
@onready var sfx_slider = $ColorRect/MarginContainer/VBoxContainer/SoundSettingsVbox/SFXVbox/SFXSlider
@onready var mute_check = $ColorRect/MarginContainer/VBoxContainer/SoundSettingsVbox/MuteCheckBox

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	master_slider.value = SettingsManager.settings.audio.master_volume
	music_slider.value = SettingsManager.settings.audio.music_volume
	sfx_slider.value = SettingsManager.settings.audio.sfx_volume
	mute_check.button_pressed = SettingsManager.settings.audio.muted
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
