extends MeshInstance3D

var fall_speed = 1.0
var car_filled = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if self.visible == true && self.position.y >= 1.098 && PlayerManager.actioning == false:
		self.position.y -= fall_speed * delta
	if self.position.y <= 1.358 && self.position.y >= 1.308:
		car_filled += .1
		$"../GasIntakeCam/GasIntakeGame/ProgressBar".value += 1
	if PlayerManager.actioning == true:
		PlayerManager.Gas_Canister.position.y += .5 * delta


func _on_progress_bar_value_changed(value: float) -> void:
	if value == 100:
		PlayerManager.player.CAMERA.current = true
		PlayerManager.minigameTwo = false
		PlayerManager.MiniGameModeOff()
		PlayerManager.gotGas_Canister = false
		PlayerManager.RemoveItemByName("Gas Canister")
		PlayerManager.player.visible = true
		PlayerManager.minigameTwoPassed = true
		$".".visible = false
		$"../GasIntakeCam/GasIntakeGame".visible = false
		$"../Mesh/GasIntake"._on_interaction_complete()
		$"../GasIntakeSweetSpot".visible = false
