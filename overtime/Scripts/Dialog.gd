## OverTime Production
## Last upadated 11/16/25 by Justin Ferreira
## Dialog Script
## - This script contains functions that
## assits in making dialog apear on screen
## and controling the effects of this dialog

extends Control


@onready var timer = $Timer
@onready var dialog_label = $MarginContainer/DialogLabel
@onready var character_panel = $CharacterPanelMarginContainer/CharacterPanel
@onready var dialog_label_pic =$CharacterPanelMarginContainer/CharacterPanel/MarginContainer2/DialogLabel
@onready var animation_player = $AnimationPlayer

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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# connects animation player to animation finished
	animation_player.connect("animation_finished", _on_animation_finished)
	
	# Create typewriter timer
	typewriter_timer = Timer.new()
	typewriter_timer.one_shot = true
	add_child(typewriter_timer)
	typewriter_timer.timeout.connect(_on_typewriter_timeout)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

## start_typewriter_effect
## makes the typewriter effect start on dialog
func start_typewriter_effect(label: RichTextLabel, text: String, identifier: String = "") -> void:
	if identifier == "":
		identifier = str(label.get_path())
	
	# Stop any existing typewriter for this label
	stop_typewriter_effect(identifier)
	
	label.visible_ratio = 0.0
	label.text = text  # Make sure text is set before starting
	
	# Create a new timer for this specific typewriter
	var timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	
	typewriter_timers[identifier] = {
		"timer": timer,
		"label": label,
		"text": text,
		"progress": 0.0
	}
	
	active_typewriters.append(identifier)
	timer.timeout.connect(_on_typewriter_timeout.bind(identifier))
	timer.start(typewriter_speed)
	
	
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
	AudioManager.play_sound(AudioManager.GetKeyPress(), -20.0, randi() % 4)
	
	# Continue if there are more characters to show
	if label.visible_ratio < 1.0:
		var remaining_time = typewriter_duration * (1.0 - label.visible_ratio)
		var characters_remaining = (1.0 - label.visible_ratio) * 100
		var time_per_character = remaining_time / characters_remaining if characters_remaining > 0 else 0.01
		
		data["timer"].start(time_per_character)
	else:
		stop_typewriter_effect(identifier)

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

func skip_all_typewriter_effects() -> void:
	for identifier in active_typewriters.duplicate():
		if typewriter_timers.has(identifier):
			var data = typewriter_timers[identifier]
			if data["label"]:
				data["label"].visible_ratio = 1.0
			stop_typewriter_effect(identifier)

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
	PlayerManager.player.CURSOR.visible = false
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
	PlayerManager.player.CURSOR.visible = true
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
