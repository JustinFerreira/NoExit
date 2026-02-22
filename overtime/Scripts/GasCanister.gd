##No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Gas Canister Script
## - this is the pickup item

extends Interactable

func _ready() -> void:
	super._ready()
	visible = false
	if not PlayerManager.Loop0:
		visible = true
		start_flashing()
	
func _process(delta: float) -> void:
	if not PlayerManager.player.interact_ray.get_collider() == self:
		start_flashing()
	else: 
		stop_flashing()

func _on_interacted(body: Variant) -> void:
	
	AnimationManager.GasIntakeFlash.start_flashing()
	AnimationManager.GasIntakeFlash.toggle_interactable(true)
	
	AudioManager.play_sound(AudioManager.ItemPickup)
	AudioManager.play_sound(AudioManager.ImportantItemStinger)
	PlayerManager.AddToInventory("Gas Canister", 1.5)
	PlayerManager.gotGas_Canister = true
	
	if is_inside_tree():
		get_parent().remove_child(self)
		queue_free()
