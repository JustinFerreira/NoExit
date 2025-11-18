extends Interactable

@onready var DoorFlash = $MeshInstance3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if PlayerManager.minigameOnePassed:
		is_interactable = true
		prompt_message = "Start Car"


func _on_interacted(body: Variant) -> void:
	DoorFlash.visible = false
	if PlayerManager.minigameOnePassed && PlayerManager.minigameTwoPassed && PlayerManager.minigameThreePassed:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
	elif PlayerManager.minigameOnePassed:
		PlayerManager.CharacterDialog("Oh no! I don't have a battery or any gas! I better go get the spares that I think are on bottom floor.")
	else:
		PlayerManager.minigameOne = true
		PlayerManager.MiniGameModeOn()
	
