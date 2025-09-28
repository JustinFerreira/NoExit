extends Interactable


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	is_interactable = false
	prompt_message = ""


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if PlayerManager.minigameOne == true:
		is_interactable = true
		prompt_message = "Start Car"


func _on_interacted(body: Variant) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
	
	
