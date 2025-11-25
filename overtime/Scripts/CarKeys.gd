## OverTime Production
## Last upadated 11/24/25 by Justin Ferreira
## CarKeys Script
## - This is the script for the pickup item car keys

extends Interactable

func _ready() -> void:
	AnimationManager.CarKeysFlashAnimationPlayer = $CarKeysFlashAnimationPlayer
	AnimationManager.ActivateCarKeysFlashAnimationPlayer()
	$CarKeysFlashAnimationPlayer.play("CarKeysFlash")

func _process(delta: float) -> void:
	if PlayerManager.DeskItems.size() < 3:
		$CarKeysFlash.visible = false
	elif not PlayerManager.player.interact_ray.get_collider() == self:
		$CarKeysFlash.visible = true
	else:
		$CarKeysFlash.visible = false

func _on_interacted(body: Variant) -> void:
	if PlayerManager.DeskItems.size() >= 3:
		if AnimationManager.ElevatorButtonFlash:
			AnimationManager.ElevatorButtonFlash.visible = true
		PlayerManager.AddToInventory("Car Keys", 0.5, true)
		PlayerManager.gotKeys = true
		AudioManager.play_sound(AudioManager.keys)
		
		if is_inside_tree():
			get_parent().remove_child(self)
			queue_free()
		PlayerManager.CharacterHintDialog("Great now I can head to the elevator and get to my car.","Use the scroll on the mouse to change your equipped item. If the item you pick up is equippable it will automaticly be equipped.")
	else:
		PlayerManager.CharacterDialog("I should pick up all my stuff from my desk.")
