## No Exit
## Overtime Studios
## Last upadated 1/23/26 by Justin Ferreira
## Mug2A Script
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
	normal_dialog = EventManager.mug2a_normal_dialog
