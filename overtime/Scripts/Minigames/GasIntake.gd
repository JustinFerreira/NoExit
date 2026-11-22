## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Gas Intake Script
## - This script is apart of the car that
## activates the filling gas minigame and turns
## on UI for it

extends Interactable

## Holds state of gas tank for animation
var open: bool = false

func _ready() -> void:
	super._ready()

	# Assignment for use later in other scripts
	AnimationManager.GasIntakeFlash = self

	# Taking animation player for opening and closing animations
	AnimationManager.GasCapAnimationPlayer = $"../../GasCapAnimationPlayer"

	# Mouse clicking aniamtion setting for UI
	AnimationManager.loop_animation($"../../GasIntakeCam/GasIntakeGame/CenterContainer/MouseClicking/MouseClickingAnimationPlayer", "MouseClicking")

	# Turn off interactablity until player has gas canister
	is_interactable = false


func _on_interacted(_body: Variant) -> void:
	#checks if needs to play animation
	if not open:
		AnimationManager.GasCapAnimationPlayer.play("GasCap")
		AudioManager.play_sound(AudioManager.GasCapOpen)
		open = true

	# turning on minigame states
	PlayerManager.minigameTwo = true
	PlayerManager.MiniGameModeOn()

	# Turn off loop sound
	AudioManager.stop_loop("step")

	# Setting up minigame specfics
	$"../../GasIntakeCanister".visible = true
	$"../../GasIntakeCam".current = true
	PlayerManager.Gas_Canister = $"../../GasIntakeCanister"
	UiManager.register_panel("gas_intake", $"../../GasIntakeCam/GasIntakeGame")
	PlayerManager.gasIntakeSweetSpot = $"../../GasIntakeSweetSpot"
	UiManager.show_panel("gas_intake", true)
	$"../../GasIntakeSweetSpot".visible = true

