extends Interactable


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AnimationManager.GasIntakeFlashAnimationPlayer = $"../../GasIntakeFlashAnimationPlayer"
	AnimationManager.GasIntakeFlash = $CarGasInatakeVisual
	AnimationManager.ActivateGasIntakeFlashAnimationPlayer()
	AnimationManager.GasIntakeFlashAnimationPlayer.play("GasIntakeFlash")
	
	AnimationManager.MouseClickingAnimationPlayer = $"../../GasIntakeCam/GasIntakeGame/MouseClicking/MouseClickingAnimationPlayer"
	AnimationManager.ActivateMouseClickingAnimationPlayer()
	AnimationManager.MouseClickingAnimationPlayer.play("MouseClicking")
	
	is_interactable = false
	prompt_message = ""
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if PlayerManager.gotGas_Canister == true:
		is_interactable = true
		prompt_message = "Fill Gas"


func _on_interacted(body: Variant) -> void:
	$"../../GasIntakeCam/GasIntakeGame/MouseClickingTimer".start()
	AnimationManager.GasIntakeFlash.visible = false
	AnimationManager.DoorFlash.visible = false
	AnimationManager.HoodFlash.visible = false
	PlayerManager.minigameTwo = true
	PlayerManager.MiniGameModeOn()
	AudioManager.stop_loop("step")
	$"../../GasIntakeCanister".visible = true
	$"../../GasIntakeCam".current = true
	PlayerManager.Gas_Canister = $"../../GasIntakeCanister"
	PlayerManager.gasIntakeUI = $"../../GasIntakeCam/GasIntakeGame"
	PlayerManager.gasIntakeSweetSpot = $"../../GasIntakeSweetSpot"
	$"../../GasIntakeCam/GasIntakeGame".visible = true
	$"../../GasIntakeSweetSpot".visible = true
	


func _on_mouse_clicking_timer_timeout() -> void:
	$"../../GasIntakeCam/GasIntakeGame/MouseClicking".visible = false
