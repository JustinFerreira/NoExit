## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Gas Intake Canister Script
## - This scripts hooks up the gascanister to work
## while the gas canister minigame is on so it rises
## and falls properly. It also moves the sweetspot and
## gives the player score for the game

extends MeshInstance3D

##
@onready var GasIntakeSweetSpot: MeshInstance3D = $"../GasIntakeSweetSpot"
@onready var progress_bar: TextureProgressBar = get_node_or_null("../GasIntakeCam/GasIntakeGame/TextureProgressBar")
var mouse_clicking: Node = null
var hint_label: Node = null

var progress_bar_value: float = 0.0

## Gas Canister movement variables
var fall_speed: float = 30.5

var lift_speed: float = 30

## progress variables
var car_filled: float = 0.0

var fill_speed: float = 0.1


## range of points for gas canister and sweet spot
var lowestPointSweetSpot: float = 10.098
var lowestPointGasCanister: float = 1.000

var highestPointGasCanister: float = 150.9
var highestPointSweetSpot: float = 100.6

## sweet spot movement variables
var sweet_spot_move_speed: float = 25.5  # Adjust for faster/slower movement
var sweet_spot_direction: float = 1     # 1 for moving up, -1 for moving down


func _ready() -> void:
	_make_target()
	mouse_clicking = get_node_or_null("../GasIntakeCam/GasIntakeGame/MouseClicking")
	hint_label = get_node_or_null("../GasIntakeCam/GasIntakeGame/Label")


func _process(delta: float) -> void:
	# Make sure Minigame Two is on
	if PlayerManager.minigameTwo:
		AudioManager.play_sound_loop(AudioManager.Glug, "glug")

		_move_sweet_spot(delta)


		# Get the sweet spot node's Y position
		var sweet_spot_y = GasIntakeSweetSpot.global_position.y

		# correcting canister size
		var canister_height = 0.5  # Adjust this value based on your canister size
		var canister_top_y = self.global_position.y
		var canister_bottom_y = self.global_position.y - (canister_height)


		# Check if sweet spot is within canister bounds
		if sweet_spot_y >= canister_bottom_y && sweet_spot_y <= canister_top_y:
			# Per second, scaled so it fills like it did at 60 FPS on any frame rate.
			car_filled += fill_speed * delta * 60.0
			progress_bar_value += 0.1 * delta * 60.0
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


## this function takes in the parameter value from the progress bar
## this then compares the value to pre determined values to have different effects
func _on_progress_bar_value_changed(value: float) -> void:
	if value >= 25:
		if mouse_clicking:
			mouse_clicking.visible = false
		if hint_label:
			hint_label.visible = false
	if value == 100:
		if PlayerManager.Enemy:
			PlayerManager.Enemy.exit_stalking_mode()
		AnimationManager.GasCapAnimationPlayer.play("GasCapClose")
		AudioManager.play_sound(AudioManager.GasCapClose)
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

## This fucntion move the "sweet spot" up or down
## between its max height and lowest point
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

## The sweet spot to aim the canister at, drawn as a target (red and white
## rings, a red bullseye) instead of a plain red box - twice the old size, so
## it reads clearly. Same node and the same movement (only its height counts
## for the score). Always faces the camera.
func _make_target() -> void:
	var spot := GasIntakeSweetSpot
	if spot == null:
		return
	var rings := Gradient.new()
	rings.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var red := Color(0.8, 0.04, 0.04)
	var white := Color(0.95, 0.93, 0.9)
	rings.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 0.97])
	rings.colors = PackedColorArray([red, white, red, white, red, Color(0, 0, 0, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = rings
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)   # twice the old box: easier to read (only its height counts)
	spot.mesh = quad
	spot.material_override = mat
