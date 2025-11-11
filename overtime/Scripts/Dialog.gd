extends Control


@onready var timer = $Timer
@onready var dialog_label = $MarginContainer/DialogLabel
@onready var character_panel = $CharacterPanelMarginContainer/CharacterPanel
@onready var dialog_label_pic =$CharacterPanelMarginContainer/CharacterPanel/MarginContainer2/DialogLabel
@onready var animation_player = $AnimationPlayer

# Dialog management variables
var current_dialog_array: Array[String] = []
var current_dialog_index: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.connect("animation_finished", _on_animation_finished)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func player_interact_dialog(text: String):
	PlayerManager.dialoging = true
	character_panel.visible = false
	dialog_label.visible = true
	animation_player.play("reveal")
	dialog_label.text = "[center][color={color}]{text}[/color][/center]".format({
		"color": "white", 
		"text": text
	})
	visible = true
	
	
	
	

func show_temporary_dialog(text: String, duration: float = 5.0, color: String = "white"):
	# Enable BBCode and set colored text
	PlayerManager.dialoging = true
	character_panel.visible = false
	dialog_label.visible = true
	animation_player.play("reveal")
	if PlayerManager.hint == true:
		dialog_label.text = "[center][color={color}]Hint: {text}[/color][/center]".format({
			"color": "red", 
			"text": text
		})
	else:
		dialog_label.text = "[center][color={color}]{text}[/color][/center]".format({
			"color": color, 
			"text": text
		})
	
	visible = true

	# Set timer for automatic hide
	timer.wait_time = duration
	timer.start()
	
	
func player_interact_dialog_pic(text: String):
	PlayerManager.dialoging = true
	character_panel.visible = true
	dialog_label.visible = false
	animation_player.play("reveal")
	dialog_label_pic.text = "[center][color={color}]{text}[/color][/center]".format({
		"color": "white", 
		"text": text
	})
	
	visible = true
	
	
	
	

func show_temporary_dialog_pic(text: String, duration: float = 5.0):
	# Enable BBCode and set colored text
	PlayerManager.dialoging = true
	character_panel.visible = true
	dialog_label.visible = false
	animation_player.play("reveal")
	if PlayerManager.hint == true:
		dialog_label_pic.text = "[center][color={color}]Hint: {text}[/color][/center]".format({
			"color": "red", 
			"text": text
		})
	else:
		dialog_label_pic.text = "[center][color={color}]{text}[/color][/center]".format({
			"color": "white", 
			"text": text
		})
	
	
	visible = true

	# Set timer for automatic hide
	timer.wait_time = duration
	timer.start()

func player_interact_multi_dialog_pic(text_array: Array[String]):
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
		dialog_label_pic.text = "[center][color={color}]{text}[/color][/center]".format({
			"color": "white", 
			"text": current_dialog_array[0]
		})
		
	animation_player.play("reveal")
	
func show_next_dialog() -> bool:
	## Show the next dialog in the sequence. Returns true if there are more dialogs, false if finished.
	if not PlayerManager.multiDialog or current_dialog_array.is_empty():
		return false
	
	current_dialog_index += 1
	
	if current_dialog_index < current_dialog_array.size():
		# Show next dialog
		dialog_label_pic.text = "[center][color={color}]{text}[/color][/center]".format({
			"color": "white", 
			"text": current_dialog_array[current_dialog_index]
		})
		return true
	else:
		# End of dialog sequence
		end_multi_dialog()
		return false

func end_multi_dialog():
	## Clean up and end the multi-dialog sequence.
	current_dialog_array = []
	current_dialog_index = 0
	PlayerManager.multiDialog = false

func _on_timer_timeout():
	visible = false
	dialog_label.text = ""
	PlayerManager.dialoging = false
	animation_player.play("hide")

func _on_animation_finished(anim_name: String):
	if anim_name == "reveal":
		PlayerManager.finishedDialogAnimation = true
	if anim_name == "hide":
		PlayerManager.finishedDialogAnimation = false
