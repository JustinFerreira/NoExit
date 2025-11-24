## OverTime Production
## Last upadated 11/24/25 by Justin Ferreira
## CarKeys Script
## - This is the script for the pickup item car keys

extends Interactable

func _on_interacted(body: Variant) -> void:
	if PlayerManager.DeskItems.size() >= 5:
		if AnimationManager.ElevatorButtonFlash:
			AnimationManager.ElevatorButtonFlash.visible = true
		PlayerManager.AddToInventory("Car Keys", 0.5, true)
		PlayerManager.gotKeys = true
		AudioManager.play_sound(AudioManager.keys)
		
		if is_inside_tree():
			get_parent().remove_child(self)
			queue_free()
	else:
		PlayerManager.CharacterDialog("I should pick up all my stuff from my desk.")
