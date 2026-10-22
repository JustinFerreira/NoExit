## No Exit
## Overtime Studios
## Last update 2/14/26 by Justin Ferreira
## Pause Menu Script
## - this script give functionality for both pause menus
## allowing player or developer mutiple options for their
## experience

extends Control

# Dark backdrop behind the menu (both pause menus): dims the frozen game,
# darker toward the edges so the menu stands out.
const DIM_SHADER := """
shader_type canvas_item;
uniform float center_alpha = 0.78;
uniform float edge_alpha = 0.93;
void fragment() {
	float d = distance(UV, vec2(0.5)) * 1.41421;
	// * COLOR.a keeps the node's fade (modulate) - without it the fade did nothing.
	COLOR = vec4(0.0, 0.0, 0.0, mix(center_alpha, edge_alpha, smoothstep(0.2, 1.0, d)) * COLOR.a);
}
"""
var _dim: ColorRect
var _dim_tween: Tween

## Eased fade of the dark backdrop (runs while the game is paused).
func _fade_dim(to: float, time: float) -> void:
	if _dim_tween and _dim_tween.is_valid():
		_dim_tween.kill()
	_dim_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_dim_tween.tween_property(_dim, "modulate:a", to, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if to <= 0.0:
		_dim_tween.tween_callback(func(): _dim.visible = false)

func _ready() -> void:
	$AnimationPlayer.play("RESET")
	_dim = ColorRect.new()
	_dim.name = name + "Dim"   # sits beside this menu (one per pause menu)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = DIM_SHADER
	_dim.material = mat
	_dim.modulate.a = 0.0
	_dim.visible = false
	# Next to the menu, not inside it: the menu's Unpause animation hides the
	# whole menu after 0.3s, which used to cut the fade-out off abruptly.
	_attach_dim.call_deferred()

## Puts the backdrop just behind this menu (deferred - the parent is still
## setting up its children during _ready).
func _attach_dim() -> void:
	var parent := get_parent()
	parent.add_child(_dim)
	parent.move_child(_dim, get_index())

## resume
## Closes the pause menu. UiManager puts the game back exactly how it was
## when it paused (mouse, crosshair, dialog, minigame state).
func resume():
	$AnimationPlayer.play("Unpause")
	# A slow, soft fade back to the game.
	_fade_dim(0.0, 0.7)
	$SettingsMenu.visible = false
	UiManager.close_screen("pause")

## Esc closes the menu. (The dev menu does this through its Resume button's
## shortcut; the regular menu has no Resume button.) The settings menu
## handles its own Esc first.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not UiManager.is_open("pause") or has_node("PanelContainer/VBoxContainer/ResumeBtn"):
		return
	if event.is_action_pressed("ui_cancel") and not $SettingsMenu.visible:
		AudioManager.play_sound(AudioManager.GetKeyPress())
		resume()
		get_viewport().set_input_as_handled()

## pause
## Freezes the game and shows this menu (UiManager hides the HUD/dialog).
func pause():
	if UiManager.is_open("pause"):
		return
	#Button clikc sound
	AudioManager.play_sound(AudioManager.GetKeyPress())
	UiManager.open_screen("pause")
	$AnimationPlayer.play("Pause")
	_dim.visible = true
	_fade_dim(1.0, 0.45)

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
		pass
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


func _on_dev_tools_btn_pressed() -> void:
	#Button clikc sound
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	$PanelContainer.visible = false
	$PanelContainer2.visible = true


func _on_backto_screen_1_pressed() -> void:
	#Button clikc sound
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	$PanelContainer.visible = true
	$PanelContainer2.visible = false


func _on_free_roam_btn_toggled(toggled_on: bool) -> void:
	#Button clikc sound
	AudioManager.play_sound(AudioManager.GetKeyPress())
	
	PlayerManager.FreeRoam = toggled_on
	if PlayerManager.FreeRoam:
		PlayerManager.player.enter_free_roam_mode()
	else:
		PlayerManager.player.exit_free_roam_mode()


func _on_player_visible_btn_toggled(toggled_on: bool) -> void:
	PlayerManager.player.visible = toggled_on


func _on_button_pressed() -> void:
	print("YOOOO")


func _on_cursor_visible_toggled(toggled_on: bool) -> void:
	PlayerManager.CursorInvisible = toggled_on
	UiManager.refresh_cursor()
