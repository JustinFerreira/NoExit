extends AnimatedSprite2D

@export var slider: HSlider
# Called when the node enters the scene tree for the first time.
func _ready():
	slider.value_changed.connect(update_sprite)
	update_sprite(slider.value)

func update_sprite(value: float):
	var percentage := int(round(value))
	frame = max(0, 20 - (value / 5))
