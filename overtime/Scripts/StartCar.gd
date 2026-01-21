extends Interactable

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	UiManager.HotWireUI = $"../../Head/Car_Cam/Minigame"
	AnimationManager.SteeringWheelFlash = $CarSteeringWheelVisual
	AnimationManager.SteeringWheelFlashAnimationPlayer = $"../../SteeringWheelFlashAnimationPlayer"
	
	AnimationManager.ActivateSteeringWheelFlashAnimationPlayer()
	AnimationManager.SteeringWheelFlashAnimationPlayer.play("SteeringWheelFlash")
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#Event Manager fix when finished minigame one it does this, unsure if the is_interactable even applies here.
	if PlayerManager.minigameOnePassed:
		is_interactable = true
		prompt_message = "Start Car"


func _on_interacted(body: Variant) -> void:
	AnimationManager.SteeringWheelFlash.visible = false
	if PlayerManager.minigameOnePassed && PlayerManager.minigameTwoPassed && PlayerManager.minigameThreePassed:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
	elif PlayerManager.minigameOnePassed and not PlayerManager.minigameTwoPassed and not PlayerManager.minigameThreePassed:
		PlayerManager.CharacterDialog(EventManager.need_battery_and_gas)
	elif PlayerManager.minigameOnePassed and PlayerManager.minigameTwoPassed and not PlayerManager.minigameThreePassed:
		PlayerManager.CharacterDialog(EventManager.need_battery)
	elif PlayerManager.minigameOnePassed and not PlayerManager.minigameTwoPassed and PlayerManager.minigameThreePassed:
		PlayerManager.CharacterDialog(EventManager.need_gas)
	elif not PlayerManager.Loop0:
		PlayerManager.minigameOne = true
		PlayerManager.MiniGameModeOn()
	else:
		AnimationManager.SteeringWheelFlash.visible = false
		AnimationManager.DoorFlash.visible = true
		PlayerManager.CharacterDialog("Huh the cars not starting I better check my battery")
	
