extends Interactable


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_interacted(body: Variant) -> void:
	GetRandomDialog()
	
func GetRandomDialog():
	var randomDialog = ["I'm busy.","I'm working right now.","Can't you see I'm working.","There's lots to be done.","Paperwork paperwork paperwork","I'm really busy right now."]
	var random_index = randi() % randomDialog.size()
	PlayerManager.CharacterDialog(randomDialog[random_index])
