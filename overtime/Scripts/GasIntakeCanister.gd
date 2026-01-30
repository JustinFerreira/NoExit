## No Exit
## Overtime Studios

extends MeshInstance3D

@onready var GasIntakeSweetSpot = $"../GasIntakeSweetSpot"
@onready var progress_bar = $"../GasIntakeCam/GasIntakeGame/TextureProgressBar"

var progress_bar_value = 0.0

var fall_speed = 30.5
var car_filled = 0.0

var fill_speed = 0.1

var lift_speed = 30

var lowestPointSweetSpot = 10.098 
var lowestPointGasCanister = 1.000

var highestPointGasCanister = 150.9
var highestPointSweetSpot = 100.6

# Add these variables at the top of your script
var sweet_spot_move_speed = 25.5  # Adjust for faster/slower movement
var sweet_spot_direction = 1     # 1 for moving up, -1 for moving down


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	## Make sure Minigame Two is on 
	if PlayerManager.minigameTwo:
		AudioManager.play_sound_loop(AudioManager.Glug, "glug")
		
		_move_sweet_spot(delta)
		
		
		
		## Get the sweet spot node's Y position
		var sweet_spot_y = GasIntakeSweetSpot.global_position.y
		var sweet_spot_tolerance = 0.025  # Adjust this value for how close it needs to be
		
		
		var canister_height = 0.5  # Adjust this value based on your canister size
		var canister_top_y = self.global_position.y 
		var canister_bottom_y = self.global_position.y - (canister_height)
			
			
		# Check if sweet spot is within canister bounds
		if sweet_spot_y >= canister_bottom_y && sweet_spot_y <= canister_top_y:
			car_filled += fill_speed
			progress_bar_value += 0.1
			progress_bar.value = progress_bar_value
			AudioManager.play_sound_loop(AudioManager.Glug, "glug")
			if PlayerManager.minigameTwoPassed:
				AudioManager.stop_loop("glug")
		else:
			AudioManager.stop_loop("glug")
		## Test if Gas Canister should be rising
		## checking if actioning is on
		## checking if it has reached highest point
		if PlayerManager.actioning == true && self.position.y <= highestPointGasCanister:
			PlayerManager.Gas_Canister.position.y += lift_speed * delta
		## Test to see if it should be falling by seeing visibility
		## and checking if it has reached lowest point
		## checking if actioing is off 
		if self.visible == true && self.position.y >= lowestPointGasCanister && PlayerManager.actioning == false:
			self.position.y -= fall_speed * delta
		
		


func _on_progress_bar_value_changed(value: float) -> void:
	if value >= 25:
		if $"../GasIntakeCam/GasIntakeGame/MouseClicking":
			$"../GasIntakeCam/GasIntakeGame/MouseClicking".visible = false
			$"../GasIntakeCam/GasIntakeGame/Label".visible = false
	if value == 100:
		AnimationManager.GasCapAnimationPlayer.play_backwards("GasCap")
		PlayerManager.player.CAMERA.current = true
		PlayerManager.minigameTwo = false
		PlayerManager.MiniGameModeOff()
		PlayerManager.gotGas_Canister = false
		PlayerManager.RemoveItemByName("Gas Canister")
		PlayerManager.minigameTwoPassed = true
		AudioManager.stop_loop("glug")
		$".".visible = false
		$"../GasIntakeCam/GasIntakeGame".visible = false
		$"../GasCap/GasCap"._on_interaction_complete()
		$"../GasIntakeSweetSpot".visible = false
		if not PlayerManager.minigameOnePassed or (PlayerManager.minigameOnePassed and PlayerManager.minigameTwoPassed and PlayerManager.minigameThreePassed):
			AnimationManager.DoorFlash.start_flashing()
		if not PlayerManager.minigameThreePassed and PlayerManager.has_item("Battery"):
			AnimationManager.HoodFlash.start_flashing()
		
func _move_sweet_spot(delta: float) -> void:
	
	# Move the sweet spot
	GasIntakeSweetSpot.position.y += sweet_spot_move_speed * sweet_spot_direction * delta
	
	# Reverse direction when hitting boundaries
	if GasIntakeSweetSpot.position.y >= highestPointSweetSpot:
		GasIntakeSweetSpot.position.y = highestPointSweetSpot
		sweet_spot_direction = -1  # Start moving down
	elif GasIntakeSweetSpot.position.y <= lowestPointSweetSpot:
		GasIntakeSweetSpot.position.y = lowestPointSweetSpot
		sweet_spot_direction = 1   # Start moving up
