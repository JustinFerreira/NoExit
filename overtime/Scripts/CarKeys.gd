## OverTime Production
## Last upadated 11/16/25 by Justin Ferreira
## CarKeys Script
## - This is the script for the pickup item car keys

extends Interactable

func _on_interacted(body: Variant) -> void:
	if AnimationManager.ElevatorButtonFlash:
		AnimationManager.ElevatorButtonFlash.visible = true
	PlayerManager.AddToInventory("Car Keys", 0.5)
	PlayerManager.gotKeys = true
	AudioManager.play_sound(AudioManager.keys)
	
	if is_inside_tree():
		get_parent().remove_child(self)
		queue_free()
