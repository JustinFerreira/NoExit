## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Steering Wheel Script
## - starts hot wire minigame, lets player know what theyre missing
## allows player to beat game

extends Interactable

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	AnimationManager.SteeringWheelFlash = self
	UiManager.HotWireUI = $"../../Head/Car_Cam/Minigame"
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#Event Manager fix when finished minigame one it does this, unsure if the is_interactable even applies here.
	if PlayerManager.minigameOnePassed:
		is_interactable = true


func _on_interacted(body: Variant) -> void:
	stop_flashing()
	if PlayerManager.Loop0:
		AnimationManager.HoodFlash.is_interactable = true
		PlayerManager.CharacterDialog(EventManager.loop0_no_battery)
		AudioManager.play_sound(AudioManager.Thud4)
	if PlayerManager.minigameOnePassed && PlayerManager.minigameTwoPassed && PlayerManager.minigameThreePassed:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		AudioManager.play_sound(AudioManager.CarStart)
		get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
	elif PlayerManager.minigameOnePassed and not PlayerManager.minigameTwoPassed and not PlayerManager.minigameThreePassed:
		PlayerManager.CharacterDialog(EventManager.need_battery_and_gas)
		AudioManager.play_sound(AudioManager.Thud4)
		stop_flashing()
	elif PlayerManager.minigameOnePassed and PlayerManager.minigameTwoPassed and not PlayerManager.minigameThreePassed:
		PlayerManager.CharacterDialog(EventManager.need_battery)
		AudioManager.play_sound(AudioManager.Thud4)
		stop_flashing()
	elif PlayerManager.minigameOnePassed and not PlayerManager.minigameTwoPassed and PlayerManager.minigameThreePassed:
		PlayerManager.CharacterDialog(EventManager.need_gas)
		AudioManager.play_sound(AudioManager.CarStartNoGas)
		stop_flashing()
	elif not PlayerManager.Loop0:
		PlayerManager.minigameOne = true
		PlayerManager.MiniGameModeOn()
		
		
	
	
