

extends ExaminableItem



func _ready() -> void:
	super._ready()
	first_time_dialog = EventManager.stapler_first_pick_dialog
	normal_dialog = EventManager.stapler_normal_dialog
