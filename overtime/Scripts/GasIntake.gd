## No Exit
## Overtime Studios

extends Interactable


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	start_flashing()
	
	AnimationManager.GasIntakeFlash = self
	
	AnimationManager.MouseClickingAnimationPlayer = $"../../GasIntakeCam/GasIntakeGame/MouseClicking/MouseClickingAnimationPlayer"
	AnimationManager.ActivateMouseClickingAnimationPlayer()
	AnimationManager.MouseClickingAnimationPlayer.play("MouseClicking")
	
	is_interactable = false
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if PlayerManager.gotGas_Canister == true:
		is_interactable = true


func _on_interacted(body: Variant) -> void:
	AnimationManager.GasIntakeFlash.stop_flashing()
	AnimationManager.DoorFlash.stop_flashing()
	AnimationManager.HoodFlash.stop_flashing()
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
	$"../../GasIntakeCam/GasIntakeGame/MouseClickingTimer".queue_free()
