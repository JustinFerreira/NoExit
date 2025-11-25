## OverTime Production
## Last upadated 11/24/25 by Justin Ferreira
## Box Script
## - This is the script for the pickup item box

extends Interactable

func _ready() -> void:
	AnimationManager.BoxFlashAnimationPlayer = $BoxFlashAnimationPlayer
	AnimationManager.BoxFlash = $BoxFlash
	AnimationManager.ActivateBoxFlashAnimationPlayer()
	AnimationManager.BoxFlashAnimationPlayer.play("BoxFlash")

func _process(delta: float) -> void:
	if PlayerManager.player.interact_ray.get_collider() == self:
		$BoxFlash.visible = false
	else:
		$BoxFlash.visible = true

func _on_interacted(body: Variant) -> void:
	
	
	PlayerManager.CharacterHintDialog("I've got to pack up all this stuff!","With your box equipped now you can pick up these items from your desk. hold E to see Inventory, and see your Box is highlighted red as equipped items are highlighted red.")
	PlayerManager.AddToInventory("Box", 0.5, true)
	AudioManager.play_sound(AudioManager.ItemPickup)
	
	if is_inside_tree():
		get_parent().remove_child(self)
		queue_free()
