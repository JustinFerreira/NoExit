## No Exit
## Overtime Studios
## Hot Wire Game
## - The hot-wire minigame overlay (opened from the steering wheel). For now
##   it's a single button press once it's open.

extends Control


func _process(_delta: float) -> void:
	if PlayerManager.minigameOne == true:
		visible = true
		AnimationManager.CarInteractRay.enabled = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_button_pressed() -> void:
	if PlayerManager.Enemy:
			PlayerManager.Enemy.exit_stalking_mode()
	PlayerManager.minigameOne = false
	visible = false
	PlayerManager.CharacterDialog(EventManager.hotwire_finished)
	AnimationManager.CarInteractRay.enabled = true


	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	PlayerManager.MiniGameModeOff()
	PlayerManager.minigameOnePassed = true
