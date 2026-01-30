## No Exit
## Overtime Studios

extends Interactable

var open = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	
	AnimationManager.GasIntakeFlash = self
	
	AnimationManager.GasCapAnimationPlayer = $"../../GasCapAnimationPlayer"
	
	AnimationManager.MouseClickingAnimationPlayer = $"../../GasIntakeCam/GasIntakeGame/MouseClicking/MouseClickingAnimationPlayer"
	AnimationManager.ActivateMouseClickingAnimationPlayer()
	AnimationManager.MouseClickingAnimationPlayer.play("MouseClicking")
	
	is_interactable = false
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_interacted(body: Variant) -> void:
	if not open:
		AnimationManager.GasCapAnimationPlayer.play("GasCap")
		open = true
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
