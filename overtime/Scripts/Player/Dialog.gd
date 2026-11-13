## No Exit
## Overtime Studios
## Last upadated 1/20/26 by Justin Ferreira
## Dialog Script
## - This script contains functions that
## assits in making dialog apear on screen
## and controling the effects of this dialog

extends Control


@onready var timer: Timer = $Timer
@onready var dialog_label: RichTextLabel = $MarginContainer/DialogLabel
@onready var character_panel: Panel = $CharacterPanelMarginContainer/CharacterPanel
@onready var dialog_label_pic: RichTextLabel =$CharacterPanelMarginContainer/CharacterPanel/MarginContainer2/DialogLabel
@onready var animation_player: AnimationPlayer = $DialogAnimationPlayer

# Dialog management variables
var current_dialog_array: Array[String] = []
var current_dialog_index: int = 0

# Typewriter effect variables
var typewriter_duration: float = 2.0
var typewriter_speed: float = 0.05  # Time between characters (in seconds)
var typewriter_timer: Timer
var current_label: RichTextLabel
var is_typing: bool = false

# Add these variables at the top with your other variables
var active_typewriters: Array = []
var typewriter_timers: Dictionary = {}

var activatedMouse: bool = false

# Expanding text box (Settings > Game > Expanding Text Box): when the box
# opens it starts as a sliver in the middle and quickly widens both ways to
# full width (keeping the box's edge margins); the text only starts typing
# once it's fully open. Later lines of the same conversation just type.
var expanding_box: bool = false:
	set(value):
		expanding_box = value
		if not value and is_node_ready():
			_finish_expand()
## Seconds the box takes to open from the middle to full width.
const EXPAND_TIME := 0.12
var _box: MarginContainer
var _box_margin_left := 30
var _box_margin_right := 30
var _wrap_mode := TextServer.AUTOWRAP_WORD_SMART
var _expand_tween: Tween
var _expand_done: Callable        # starts the typing once the box is open
var _box_open := false           # box is up (later lines of the conversation don't re-expand)

# The "click to continue" mouse icon. Other scripts just turn it on; it
# waits here until the text has finished typing, then sits inside the
# box's bottom-right corner (wherever the box currently is).
@onready var _click_icon: Sprite2D = $MouseClicking
var _click_icon_waiting := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_box = $CharacterPanelMarginContainer
	_box_margin_left = _box.get_theme_constant("margin_left")
	_box_margin_right = _box.get_theme_constant("margin_right")
	_wrap_mode = dialog_label_pic.autowrap_mode
	# Nothing inside may poke out of the box while it is still opening.
	character_panel.clip_contents = true
	# connects animation player to animation finished
	animation_player.connect("animation_finished", _on_animation_finished)
	# the box starts closing: the next dialog opens it from the middle again
	animation_player.animation_started.connect(func(anim: StringName) -> void:
		if anim == &"hide":
			_box_open = false)
	
	# Create typewriter timer
	typewriter_timer = Timer.new()
	typewriter_timer.one_shot = true
	add_child(typewriter_timer)
	typewriter_timer.timeout.connect(_on_typewriter_timeout)

## start_typewriter_effect
## makes the typewriter effect start on dialog
func start_typewriter_effect(label: RichTextLabel, text: String, identifier: String = "") -> void:
	if identifier == "":
		identifier = str(label.get_path())
	
	# Stop any existing typewriter for this label
	stop_typewriter_effect(identifier)
	
	label.visible_ratio = 0.0
	label.text = text  # Make sure text is set before starting
	is_typing = true
	
	# Create a new timer for this specific typewriter
	var _timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	
	typewriter_timers[identifier] = {
		"timer": _timer,
		"label": label,
		"text": text,
		"progress": 0.0
	}
	
	active_typewriters.append(identifier)
	_timer.timeout.connect(_on_typewriter_timeout.bind(identifier))
	# A freshly opened box first expands from the middle; typing waits for it.
	if expanding_box and label == dialog_label_pic and not _box_open:
		_expand_box(_timer.start.bind(typewriter_speed))
	else:
		_timer.start(typewriter_speed)
	if label == dialog_label_pic:
		_box_open = true
	
	
## _on_typewriter_timeout
## when timer is finished for type writer effect
## this function is called to reset the effect
func _on_typewriter_timeout(identifier: String) -> void:
	if not typewriter_timers.has(identifier):
		return
	
	var data = typewriter_timers[identifier]
	var label = data["label"]
	
	if label == null:
		stop_typewriter_effect(identifier)
		return
	
	# Increase visible ratio
	data["progress"] += 0.04
	label.visible_ratio = data["progress"]
	AudioManager.play_sound(AudioManager.GetKeyPress(), -20.0, (randi() % 4) + 1)
	
	# Continue if there are more characters to show
	if label.visible_ratio < 1.0:
		var remaining_time = typewriter_duration * (1.0 - label.visible_ratio)
		var characters_remaining = (1.0 - label.visible_ratio) * 100
		var time_per_character = remaining_time / characters_remaining if characters_remaining > 0 else 0.01
		
		data["timer"].start(time_per_character)
	else:
		is_typing = false
		stop_typewriter_effect(identifier)
		
	if PlayerManager.Loop0 and PlayerManager.firstdialog and not activatedMouse:
		PlayerManager.player.DIALOG.get_node("MouseClicking").visible = true
		AnimationManager.MouseClickingAnimationPlayer = PlayerManager.player.DIALOG.get_node("MouseClicking").get_node("MouseClickingAnimationPlayer")
		AnimationManager.ActivateMouseClickingAnimationPlayer()
		AnimationManager.MouseClickingAnimationPlayer.play("MouseClicking")
		activatedMouse = true
		
## skip_typewriter_effect
## stops the type writer effect early
## allowing to see the full dialog immediately
func skip_typewriter_effect() -> void:
	skip_all_typewriter_effects()
		
func stop_typewriter_effect(identifier: String) -> void:
	if typewriter_timers.has(identifier):
		var data = typewriter_timers[identifier]
		if data["timer"] and is_instance_valid(data["timer"]):
			data["timer"].stop()
			data["timer"].queue_free()
		typewriter_timers.erase(identifier)
		active_typewriters.erase(identifier)
	
	if active_typewriters.is_empty():
		is_typing = false
	

func skip_all_typewriter_effects() -> void:
	_finish_expand()   # a click while the box is opening opens it fully at once
	for identifier in active_typewriters.duplicate():
		if typewriter_timers.has(identifier):
			var data = typewriter_timers[identifier]
			if data["label"]:
				data["label"].visible_ratio = 1.0
			stop_typewriter_effect(identifier)
	is_typing = false 

## player_interact_dialog
## This function creates dialog
## which appears at the top of the screen
## and stays until the player clicks the Interact button
func player_interact_dialog(text: String):
	PlayerManager.dialoging = true
	character_panel.visible = false
	dialog_label.visible = true
	animation_player.play("reveal")
	
	var formatted_text = "[color={color}]{text}[/color]".format({
		"color": "white", 
		"text": text
	})
	
	dialog_label.text = formatted_text
	start_typewriter_effect(dialog_label, formatted_text)
	visible = true
	
	
	
	
## show_temporary_dialog
## creates dialog which disapears after duration
## and appears at the top of the screen
## this dialog can also be cleared with interaction
## this dialog can be modified with colors aswell
func show_temporary_dialog(text: String, duration: float = 5.0, color: String = "white"):
	# Enable BBCode and set colored text
	PlayerManager.dialoging = true
	character_panel.visible = false
	dialog_label.visible = true
	animation_player.play("reveal")
	
	# Format text
	var formatted_text: String
	formatted_text = "[center][color={color}]{text}[/color][/center]".format({
		"color": color, 
		"text": text
	})
	
	# Set up text for typewriter effect
	dialog_label.text = formatted_text
	start_typewriter_effect(dialog_label, formatted_text)
	
	visible = true

	# Set timer for automatic hide
	timer.wait_time = duration
	timer.one_shot = true
	timer.start()
	
## player_interact_dialog_pic
## This function creates dialog
## which appears at the bottom of the screen
## in a box
## and stays until the player clicks the Interact button
func player_interact_dialog_pic(text: String):
	PlayerManager.dialoging = true
	character_panel.visible = true
	dialog_label.visible = false
	animation_player.play("reveal")
	
	var formatted_text = "[color={color}]{text}[/color]".format({
		"color": "white", 
		"text": text
	})
	
	dialog_label_pic.text = formatted_text
	start_typewriter_effect(dialog_label_pic, formatted_text)
	visible = true
	
	
func player_interact_dialog_pic_and_hint(characterText: String, hintText: String):
	PlayerManager.dialoging = true
	character_panel.visible = true
	dialog_label.visible = true
	animation_player.play("reveal")
	
	# Store the formatted text for both labels
	var formatted_character_text = "[color={color}]{text}[/color]".format({
		"color": "white", 
		"text": characterText
	})
	
	var formatted_hint_text = "[center][color={color}]Hint: {text}[/color][/center]".format({
		"color": "red", 
		"text": hintText
	})
	
	# Set the formatted text to the labels
	dialog_label_pic.text = formatted_character_text
	dialog_label.text = formatted_hint_text
	
	# Start both typewriter effects with the formatted text
	start_typewriter_effect(dialog_label_pic, formatted_character_text, "character")
	start_typewriter_effect(dialog_label, formatted_hint_text, "hint")
	
	visible = true
	
## show_temporary_dialog_pic
## This function creates dialog
## which appears at the bottom of the screen
## in a box
## it will disapear after a duration
func show_temporary_dialog_pic(text: String, duration: float = 5.0):
	# Enable BBCode and set colored text
	PlayerManager.dialoging = true
	character_panel.visible = true
	dialog_label.visible = false
	animation_player.play("reveal")
	
	# Format text
	var formatted_text: String
	if PlayerManager.hint == true:
		formatted_text = "[center]{content}[/center]".format({
		"content": "[color={color}]Hint: {text}[/color]".format({
			"color": "red", 
			"text": text
			})
		})
	else:
		formatted_text = "[color={color}]{text}[/color]".format({
			"color": "white", 
			"text": text
		})
	
	# Set up text for typewriter effect
	dialog_label_pic.text = formatted_text
	start_typewriter_effect(dialog_label_pic, text)
	
	visible = true

	# Set timer for automatic hide
	timer.wait_time = duration
	timer.one_shot = true
	timer.start()

## player_interact_multi_dialog_pic
## Starts a sequence of dialog which
## appears at the bottom of the screen
## in a box 
func player_interact_multi_dialog_pic(text_array: Array[String]):
	UiManager.set_cursor_visible(false)
	PlayerManager.dialoging = true
	PlayerManager.multiDialog = true
	character_panel.visible = true
	dialog_label.visible = false
	
	# Store the dialog array and reset index
	current_dialog_array = text_array
	current_dialog_index = 0
	
	# Show first dialog
	if current_dialog_array.size() > 0:
		visible = true
		var formatted_text = "[color={color}]{text}[/color]".format({
			"color": "white", 
			"text": current_dialog_array[0]
		})
		dialog_label_pic.text = formatted_text
		start_typewriter_effect(dialog_label_pic, formatted_text)
		animation_player.play("reveal")

## show_next_dialog
## this shows the next line of dialog
## in a sequence of dialog
# show_next_dialog
## this shows the next line of dialog
## in a sequence of dialog
func show_next_dialog() -> bool:
	## Show the next dialog in the sequence. Returns true if there are more dialogs, false if finished.
	if not PlayerManager.multiDialog or current_dialog_array.is_empty():
		return false
	
	current_dialog_index += 1
	
	if current_dialog_index < current_dialog_array.size():
		# Show next dialog
		var formatted_text = "[color={color}]{text}[/color]".format({
			"color": "white", 
			"text": current_dialog_array[current_dialog_index]
		})
		dialog_label_pic.text = formatted_text
		start_typewriter_effect(dialog_label_pic, formatted_text)
		return true
	else:
		# End of dialog sequence
		end_multi_dialog()
		return false

## end_multi_dialog
## this is called when a
## sequence of dialog reaches
## the last part of the sequence
func end_multi_dialog():
	## Clean up and end the multi-dialog sequence.
	UiManager.set_cursor_visible(true)
	current_dialog_array = []
	current_dialog_index = 0
	PlayerManager.multiDialog = false
	PlayerManager.HideDialog()
	PlayerManager.dialoging = false
	PlayerManager.finishedDialogAnimation = false
	PlayerManager.startMultiDialog = true

## _on_timer_timeout
## this is called on the finish of 
## the timer for temporary dialog
func _on_timer_timeout():
	dialog_label.text = ""
	PlayerManager.dialoging = false
	animation_player.play("hide")

## _on_animation_finished
## called when an animation is complete
func _on_animation_finished(anim_name: String):
	if anim_name == "reveal":
		PlayerManager.finishedDialogAnimation = true
	if anim_name == "hide":
		PlayerManager.finishedDialogAnimation = false
		visible = false

## ---------------------------------------------------------------------
## Expanding text box
## ---------------------------------------------------------------------

func _process(_delta: float) -> void:
	_update_click_icon()
	# The box counts as closed once it's hidden, so the next dialog expands again.
	if _box_open and not (visible and character_panel.visible):
		_box_open = false

## Opens the box from a sliver in the middle to full width, then calls `done`
## (which starts the typing).
func _expand_box(done: Callable) -> void:
	_finish_expand()
	_expand_done = done
	_set_box_open(0.0)
	_expand_tween = create_tween()
	_expand_tween.tween_method(_set_box_open, 0.0, 1.0, EXPAND_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_expand_tween.tween_callback(_finish_expand)

## Jumps the box to fully open and starts the typing if it was waiting.
func _finish_expand() -> void:
	if _expand_tween and _expand_tween.is_valid():
		_expand_tween.kill()
	_expand_tween = null
	_set_box_open(1.0)
	if _expand_done.is_valid():
		var done := _expand_done
		_expand_done = Callable()
		done.call()

## 0 = a sliver in the middle, 1 = full width (inside the normal edge
## margins). Shrinks equally from both sides so it stays centred.
func _set_box_open(amount: float) -> void:
	var full := _box.size.x - _box_margin_left - _box_margin_right
	var half_gap := maxf(full * (1.0 - amount), 0.0) * 0.5
	_box.add_theme_constant_override("margin_left", int(_box_margin_left + half_gap))
	_box.add_theme_constant_override("margin_right", int(_box_margin_right + half_gap))
	dialog_label_pic.autowrap_mode = _wrap_mode

## ---------------------------------------------------------------------
## Click-to-continue icon
## ---------------------------------------------------------------------

func _update_click_icon() -> void:
	if _click_icon == null:
		return
	# Something turned it on while the text is still typing: hold it back.
	if _click_icon.visible and is_typing:
		_click_icon.visible = false
		_click_icon_waiting = true
	elif _click_icon_waiting and not is_typing:
		_click_icon_waiting = false
		_click_icon.visible = true
	if not _click_icon.visible:
		return
	# Bottom-right corner, inside the character panel (or the plain caption
	# area when the panel isn't up).
	var box: Rect2 = character_panel.get_global_rect() if character_panel.is_visible_in_tree() else dialog_label.get_global_rect()
	var icon_size := _click_icon.get_rect().size * _click_icon.scale
	_click_icon.global_position = box.end - icon_size * 0.5 - Vector2(10, 8)
