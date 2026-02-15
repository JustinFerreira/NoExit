## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Settings Label Script
## - This script updates the number for sliders in settings menu

extends Label

@export var slider: HSlider

func _ready():
	slider.value_changed.connect(update_text)
	update_text(slider.value)

func update_text(value: float):
	var clamped_value := clampf(value, slider.min_value, slider.max_value)
	var percentage := int(round(clamped_value))
	text = "%d%%" % [int(percentage)]
