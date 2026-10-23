## No Exit
## Overtime Studios
## Last updated 10/18/26 by Justin Ferreira
## Settings Label Script
## - This script updates the number for sliders in settings menu

extends Label

@export var slider: HSlider
## Shown after the number, e.g. "%" for 75%. Empty for plain numbers.
@export var suffix: String = "%"

func _ready():
	slider.value_changed.connect(update_text)
	update_text(slider.value)

func update_text(value: float):
	var clamped_value := clampf(value, slider.min_value, slider.max_value)
	text = "%d%s" % [int(round(clamped_value)), suffix]
