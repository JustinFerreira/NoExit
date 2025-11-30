extends Interactable


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AnimationManager.HoodFlash = $CarHoodVisual
	AnimationManager.HoodFlashAnimationPlayer = $"../../HoodFlashAnimationPlayer"
	AnimationManager.ActivateHoodFlashAnimationPlayer()
	AnimationManager.HoodFlashAnimationPlayer.play("HoodFlash")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if PlayerManager.Loop0 == true:
		is_interactable = true

func _on_interacted(body: Variant) -> void:
	AnimationManager.HoodFlash.visible = false
	AnimationManager.DoorFlash.visible = false
	PlayerManager.Hood = self
	$"../../HoodCam".current = true
	
	PlayerManager.CharacterDialog("Huh I guess I have no battery")
	
	AudioManager.cancel_loop_sfx()
	
	SettingsManager.KillerDisabled = false
	
	PlayerManager.teleportEnemy = true
