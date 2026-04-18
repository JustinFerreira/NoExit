extends Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_center_sprite()
	# Update center when window size changes
	get_tree().root.connect("size_changed", _center_sprite)

func _center_sprite():
	var viewport_size = get_viewport().get_visible_rect().size
	position = viewport_size / 2
