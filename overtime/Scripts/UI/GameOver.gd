## No Exit
## Overtime Studios
## Last updated 1/23/26 by Justin Ferreira
## Game Over Script
## - The game over screen: restart or quit to the main menu.
## - A red screen (the same red as dying - DamageOverlay.DEAD_RED) with the
##   black "Game Over" and white buttons. Dying, the screen has already gone
##   red (DamageOverlay): it waits for that to finish, the red carries on as
##   its background, then the title and buttons fade in (FADE_IN). No death
##   red coming (some other game over): the red fades in first (RED_IN).

extends CanvasLayer

## True when this game over ended a rogue run (Restart starts a new run).
var _rogue_over := false

## Seconds for the title and buttons to fade in once the screen is red.
const FADE_IN := 0.9
## Seconds for the red to fade in when it wasn't already there from dying.
const RED_IN := 0.6

## 0 = waiting for the red, 1 = fading the title and buttons in, 2 = shown
var _stage := 2
var _bg_alpha := 1.0

func _ready() -> void:
	if PlayerManager.DevMode:
		$Control/MarginContainer/VBoxContainer/MainMenuBtn.visible = true
	visibility_changed.connect(_on_shown)
	visibility_changed.connect(_start_fade)

## Shown: everything starts hidden and comes in (see the top).
func _start_fade() -> void:
	if not visible:
		return
	_stage = 0
	_bg_alpha = 0.0
	_set_bg(0.0)
	$Control.modulate.a = 0.0
	_set_buttons_live(false)

func _process(delta: float) -> void:
	if not visible or _stage == 2:
		return
	if _stage == 0:
		var overlay = UiManager.get_node_or_null("DamageOverlay")
		if is_instance_valid(overlay) and overlay.dying_red():
			# the death red is still coming in under us: wait for all of it,
			# then the background takes over (same colour, no seam)
			if overlay.dead_shown() >= 0.999:
				_bg_alpha = 1.0
		else:
			_bg_alpha = move_toward(_bg_alpha, 1.0, delta / RED_IN)
		_set_bg(_bg_alpha)
		if _bg_alpha >= 1.0:
			_stage = 1
		return
	var a := move_toward($Control.modulate.a, 1.0, delta / FADE_IN)
	$Control.modulate.a = a
	if a >= 1.0:
		_stage = 2
		_set_buttons_live(true)

func _set_bg(alpha: float) -> void:
	var c: Color = _dead_red()
	c.a = alpha
	$ColorRect.color = c

## The death red as the shader draws it (its output skips the colour
## conversion a ColorRect gets, so the plain value would come out darker).
static func _dead_red() -> Color:
	return preload("res://Scripts/UI/DamageOverlay.gd").DEAD_RED.linear_to_srgb()

## The buttons can't be pressed while they're still fading in.
func _set_buttons_live(live: bool) -> void:
	for b in $Control/MarginContainer/VBoxContainer.get_children():
		if b is Button:
			b.mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE

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
