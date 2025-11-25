extends Interactable

func _ready() -> void:
	AnimationManager.GasCanisterFlashAnimationPlayer = $GasCanisterFlashAnimationPlayer
	AnimationManager.ActivateGasCanisterFlashAnimationPlayer()
	$GasCanisterFlashAnimationPlayer.play("GasCanisterFlash")
	
func _process(delta: float) -> void:
	if not PlayerManager.player.interact_ray.get_collider() == self:
		$GasCanisterFlash.visible = true
	else: 
		$GasCanisterFlash.visible = false

func _on_interacted(body: Variant) -> void:
	AnimationManager.GasIntakeFlash.visible = true
	AudioManager.play_sound(AudioManager.ItemPickup)
	PlayerManager.AddToInventory("Gas Canister", 1.5)
	PlayerManager.gotGas_Canister = true
	
	if is_inside_tree():
		get_parent().remove_child(self)
		queue_free()
