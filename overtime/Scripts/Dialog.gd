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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.connect("animation_finished", _on_animation_finished)
	
	# Create typewriter timer
	typewriter_timer = Timer.new()
	typewriter_timer.one_shot = true
	add_child(typewriter_timer)
	typewriter_timer.timeout.connect(_on_typewriter_timeout)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


# Typewriter effect functions
func start_typewriter_effect(label: RichTextLabel, text: String) -> void:
	current_label = label
	current_label.visible_ratio = 0.0
	is_typing = true
	
	# Calculate the time per character based on the fixed duration
	var text_length = text.length()
	var time_per_character = typewriter_duration / text_length if text_length > 0 else 0
	
	# Start the typewriter effect
	typewriter_timer.start(typewriter_speed)
	
	

func _on_typewriter_timeout() -> void:
	if current_label == null:
		is_typing = false
		return
	
	# Increase visible ratio
	current_label.visible_ratio += 0.04  # Small increment
	AudioManager.play_sound(AudioManager.GetKeyPress(), -20.0, randi() % 4)
	# Continue if there are more characters to show
	if current_label.visible_ratio < 1.0:
		# Calculate the time for the next character based on remaining time
		var remaining_time = typewriter_duration * (1.0 - current_label.visible_ratio)
		var characters_remaining = (1.0 - current_label.visible_ratio) * 100  # Approximate
		var time_per_character = remaining_time / characters_remaining if characters_remaining > 0 else 0.01
		
		typewriter_timer.start(time_per_character)
	else:
		is_typing = false

func skip_typewriter_effect() -> void:
	if is_typing and current_label != null:
		typewriter_timer.stop()
		current_label.visible_ratio = 1.0
		is_typing = false

func player_interact_dialog(text: String):
	PlayerManager.dialoging = true
	character_panel.visible = false
	dialog_label.visible = true
	animation_player.play("reveal")
	dialog_label.text = "[color={color}]{text}[/color]".format({
		"color": "white", 
		"text": text
	})
	start_typewriter_effect(dialog_label, text)
	visible = true
	
	
	
	

func show_temporary_dialog(text: String, duration: float = 5.0, color: String = "white"):
	# Enable BBCode and set colored text
	PlayerManager.dialoging = true
	character_panel.visible = false
	dialog_label.visible = true
	animation_player.play("reveal")
	
	# Format text
	var formatted_text: String
	if PlayerManager.hint == true:
		formatted_text = "[center][color={color}]Hint: {text}[/color][/center]".format({
			"color": "red", 
			"text": text
		})
	else:
		formatted_text = "[color={color}]{text}[/color]".format({
			"color": color, 
			"text": text
		})
	
	# Set up text for typewriter effect
	dialog_label.text = formatted_text
	start_typewriter_effect(dialog_label, text)
	
	visible = true

	# Set timer for automatic hide
	timer.wait_time = duration
	timer.one_shot = true
	timer.start()
	
	
func player_interact_dialog_pic(text: String):
	PlayerManager.dialoging = true
	character_panel.visible = true
	dialog_label.visible = false
	animation_player.play("reveal")
	dialog_label_pic.text = "[color={color}]{text}[/color]".format({
		"color": "white", 
		"text": text
	})
	
	start_typewriter_effect(dialog_label_pic, text)
	visible = true
	
	
	
	

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
		dialog_label_pic.text = "[color={color}]{text}[/color]".format({
			"color": "white", 
			"text": current_dialog_array[0]
		})
		
	start_typewriter_effect(dialog_label_pic, current_dialog_array[0])
	animation_player.play("reveal")
	
func show_next_dialog() -> bool:
	## Show the next dialog in the sequence. Returns true if there are more dialogs, false if finished.
	if not PlayerManager.multiDialog or current_dialog_array.is_empty():
		return false
	
	current_dialog_index += 1
	
	if current_dialog_index < current_dialog_array.size():
		# Show next dialog
		dialog_label_pic.text = "[color={color}]{text}[/color]".format({
			"color": "white", 
			"text": current_dialog_array[current_dialog_index]
		})
		start_typewriter_effect(dialog_label_pic, current_dialog_array[0])
		return true
	else:
		# End of dialog sequence
		end_multi_dialog()
		return false

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

func _on_timer_timeout():
	dialog_label.text = ""
	PlayerManager.dialoging = false
	animation_player.play("hide")
	visible = false

func _on_animation_finished(anim_name: String):
	if anim_name == "reveal":
		PlayerManager.finishedDialogAnimation = true
	if anim_name == "hide":
		PlayerManager.finishedDialogAnimation = false
		visible = false
