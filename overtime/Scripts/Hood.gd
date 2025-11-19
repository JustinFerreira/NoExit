extends Interactable

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AnimationManager.HoodFlash = $MeshInstance3D
	is_interactable = false
	prompt_message = ""


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if PlayerManager.gotBattery == true:
		is_interactable = true
		prompt_message = "Open Hood"
		if !PlayerManager.minigameThree:
			AnimationManager.HoodFlash.visible = true
			AnimationManager.CarAnimationPlayer.play("HoodFlash")
			


func _on_interacted(body: Variant) -> void:
	PlayerManager.Hood = self
	PlayerManager.RemoveItemByName("Battery")
	PlayerManager.gotBattery = false
	PlayerManager.player.prompt.visible = false
	$"../../HoodCam".current = true
	if !PlayerManager.PositiveConnected:
		PlayerManager.PositiveWire.visible = true
	if !PlayerManager.NegativeConnected:
		PlayerManager.NegativeWire.visible = true
	$"../../HoodCam/HoodGame".visible = true
	PlayerManager.hoodUI = $"../../HoodCam/HoodGame"
	PlayerManager.Battery.visible = true
	PlayerManager.minigameThree = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	PlayerManager.MiniGameModeOn()
	
	
