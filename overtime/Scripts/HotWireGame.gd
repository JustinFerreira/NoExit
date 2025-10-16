extends Control


@onready var item1 = $Item1
@onready var item2 = $Item2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if PlayerManager.minigameOne == true:
		visible = true
		$"../InteractRay".enabled = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		


func _on_button_pressed() -> void:
	visible = false
	PlayerManager.Dialog("Great now I can start my car and get out of here, cause hot wiring tottally does not start the car.")
	$"../InteractRay".enabled = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	PlayerManager.MinigameMode = false
	PlayerManager.minigameOne = false
	PlayerManager.minigameOnePassed = true
	#print("PlayerManger HotWireGame minigameOne:",PlayerManager.minigameOne)
