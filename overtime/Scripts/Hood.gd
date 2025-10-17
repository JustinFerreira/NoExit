extends Interactable


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_interacted(body: Variant) -> void:
	$"../../HoodCam".current = true
	PlayerManager.minigameThree = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	PlayerManager.MiniGameModeOn()
	$CollisionShape3D.disabled = true
	_on_interaction_complete()
