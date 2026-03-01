##No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Gas Canister Script
## - this is the pickup item

extends ExaminableItem

func _ready() -> void:
	if PlayerManager.Loop0:
		PlayerManager.set(player_manager_reference, null)
		get_parent().visible = false
		_on_interaction_complete()
		return
	super._ready()
	start_flashing()
	normal_dialog = EventManager.gascanisterpickup_normal_dialog
	
func _process(delta: float) -> void:
	if PlayerManager.ExamingItem == self || PlayerManager.examining == true:
		stop_flashing()
	elif not PlayerManager.player.interact_ray.get_collider() == self:
		start_flashing()
	else:
		stop_flashing()

func _on_interacted(body: Variant) -> void:
	super._on_interacted(body)
	AnimationManager.GasIntakeFlash.start_flashing()
	AnimationManager.GasIntakeFlash.toggle_interactable(true)
	
	AudioManager.play_sound(AudioManager.ImportantItemStinger)
	PlayerManager.AddToInventory("Gas Canister", 1.5)
	PlayerManager.gotGas_Canister = true
	
