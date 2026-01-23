## No Exit
## Overtime Studios

extends ExaminableItem



func _ready() -> void:
	#put Loops in Event Manager?
	if not PlayerManager.Loop0:
		get_parent().visible = false
		_on_interaction_complete()
		return
	super._ready()
	first_time_dialog = EventManager.stapler_first_pick_dialog
	normal_dialog = EventManager.stapler_normal_dialog
