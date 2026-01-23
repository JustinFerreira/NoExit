## No Exit
## Overtime Studios
## Last upadated 1/23/26 by Justin Ferreira
## Picture Frame 1 Script
## - This is an Examinable Item which appears on the players desk
## it should be gone after first death. Here we also set up the
## dialog for when examining it

extends ExaminableItem


func _ready() -> void:
	#put Loops in Event Manager?
	if not PlayerManager.Loop0:
		PlayerManager.set(player_manager_reference, null)
		get_parent().visible = false
		_on_interaction_complete()
		return
	super._ready()
	first_time_dialog = EventManager.pictureframe1_first_pick_dialog
	normal_dialog = EventManager.pictureframe1_normal_dialog
