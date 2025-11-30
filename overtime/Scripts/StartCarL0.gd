extends Interactable


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AnimationManager.SteeringWheelFlash = $CarSteeringWheelVisual
	AnimationManager.SteeringWheelFlashAnimationPlayer = $"../../SteeringWheelFlashAnimationPlayer"
	
	AnimationManager.ActivateSteeringWheelFlashAnimationPlayer()
	AnimationManager.SteeringWheelFlashAnimationPlayer.play("SteeringWheelFlash")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_interacted(body: Variant) -> void:
	AnimationManager.SteeringWheelFlash.visible = false
	AnimationManager.DoorFlash.visible = true
	PlayerManager.CharacterDialog("Huh the cars not starting I better check my battery")
