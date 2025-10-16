extends Interactable


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	is_interactable = false
	prompt_message = ""


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if PlayerManager.gotGas_Canister == true:
		is_interactable = true
		prompt_message = "Fill Gas"


func _on_interacted(body: Variant) -> void:
	PlayerManager.minigameTwo = true
	PlayerManager.Gas_Canister = $"../../GasIntakeCanister"
	$"../../GasIntakeCanister".visible = true
	$"../../GasIntakeCam".current = true
	
