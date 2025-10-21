extends Interactable


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	is_interactable = false
	prompt_message = ""


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if PlayerManager.minigameOnePassed:
		is_interactable = true
		prompt_message = "Start Car"


func _on_interacted(body: Variant) -> void:
	if PlayerManager.minigameTwoPassed && PlayerManager.minigameThreePassed:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
	else:
		PlayerManager.Dialog("Oh no! I don't have a battery or any gas! I better go get the spares that I think are on first level.")
	
	
