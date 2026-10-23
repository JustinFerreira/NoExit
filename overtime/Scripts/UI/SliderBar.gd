## No Exit
## Overtime Studios
## Last updated 10/18/26 by Justin Ferreira
## Slider Bar Script
## - This is used to keep the sprite of the sliderbar acurate
## - Works for any slider range (fills by how far along the range it is)

extends AnimatedSprite2D

@export var slider: HSlider
# Called when the node enters the scene tree for the first time.
func _ready():
	slider.value_changed.connect(update_sprite)
	update_sprite(slider.value)

func update_sprite(value: float):
	var ratio := inverse_lerp(slider.min_value, slider.max_value, value) if slider.max_value > slider.min_value else 0.0
	frame = clampi(20 - int(round(ratio * 20.0)), 0, 20)
