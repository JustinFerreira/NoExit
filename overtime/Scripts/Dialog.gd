extends Control


@onready var timer = $Timer
@onready var dialog_label = $MarginContainer/DialogLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func show_temporary_dialog(text: String, duration: float = 5.0):
	dialog_label.text = text
	visible = true

	# Set timer for automatic hide
	timer.wait_time = duration
	timer.start()

func _on_timer_timeout():
	visible = false
	dialog_label.text = ""
