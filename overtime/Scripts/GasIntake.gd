## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Gas Intake Script
## - This script is apart of the car that 
## activates the filling gas minigame and turns
## on UI for it

extends Interactable

# Holds state of gas tank for animation
var open = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	
	# Assignment for use later in other scripts
	AnimationManager.GasIntakeFlash = self
	
	# Taking animation player for opening and closing animations
	AnimationManager.GasCapAnimationPlayer = $"../../GasCapAnimationPlayer"
	
	# Mouse clicking aniamtion setting for UI
	AnimationManager.MouseClickingAnimationPlayer = $"../../GasIntakeCam/GasIntakeGame/MouseClicking/MouseClickingAnimationPlayer"
	AnimationManager.ActivateMouseClickingAnimationPlayer()
	AnimationManager.MouseClickingAnimationPlayer.play("MouseClicking")
	
	# Turn off interactablity until player has gas canister
	is_interactable = false
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_interacted(body: Variant) -> void:
	#checks if needs to play animation
	if not open:
		AnimationManager.GasCapAnimationPlayer.play("GasCap")
		open = true
	
	# Turn off flashing for car objects 
	# EventManager?
	AnimationManager.GasIntakeFlash.stop_flashing()
	AnimationManager.DoorFlash.stop_flashing()
	AnimationManager.HoodFlash.stop_flashing()
	
	# turning on minigame states
	PlayerManager.minigameTwo = true
	PlayerManager.MiniGameModeOn()
	
	# Turn off loop sound
	# Event Manager?
	AudioManager.stop_loop("step")
	
	# Setting up minigame specfics
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
