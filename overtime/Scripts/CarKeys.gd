## No Exit
## Overtime Studios
## Last upadated 1/19/26 by Justin Ferreira
## CarKeys Script
## - This is the script for the pickup item car keys

extends Interactable

func _ready() -> void:
	#make it so when it is not Loop 0 keys is invisible
	#maybe make it so it is deleted from scene? save space?
	#put Loops in Event Manager?
	if not PlayerManager.Loop0:
		self.visible = false
		_on_interaction_complete()
		return
	#set up flashing animation
	AnimationManager.CarKeysFlashAnimationPlayer = $CarKeysFlashAnimationPlayer
	#AnimationManager.CarKeysFlash = $CarKeysFlash
	AnimationManager.ActivateCarKeysFlashAnimationPlayer()
	AnimationManager.CarKeysFlashAnimationPlayer.play("CarKeysFlash")

func _process(delta: float) -> void:
	#checks if there is more deskitems than needed so keys will flash
	#should change this so that everytime an item is picked up it checks instead of process
	#also add CarKeyFlash to Animation Manager
	if PlayerManager.DeskItems.size() < 3:
		$CarKeysFlash.visible = false
	elif not PlayerManager.player.interact_ray.get_collider() == self:
		$CarKeysFlash.visible = true
	else:
		$CarKeysFlash.visible = false

func _on_interacted(body: Variant) -> void:
	#checks if there is more deskitems than needed so keys are pickupable
	if PlayerManager.DeskItems.size() >= 3:
		if AnimationManager.ElevatorButtonFlash:
			AnimationManager.ElevatorButtonFlash.visible = true
		PlayerManager.AddToInventory("Car Keys", 0.5, true)
		PlayerManager.gotKeys = true
		AudioManager.play_sound(AudioManager.keys)
		
		#get rid of object in scene 
		if is_inside_tree():
			get_parent().remove_child(self)
			queue_free()
		PlayerManager.CharacterHintDialog(EventManager.keys_pickup,EventManager.keys_pickup_hint)
	else:
		PlayerManager.CharacterDialog(EventManager.keys_pickup_early)
