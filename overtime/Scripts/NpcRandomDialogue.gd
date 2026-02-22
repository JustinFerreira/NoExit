## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Npc Random Dialogue Script
## - this is for npcs that just sit st their desk 
## so they can spit out random stuff on interaction

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
	var randomDialog = EventManager.random_npc_busy_dialog
	var random_index = randi() % randomDialog.size()
	PlayerManager.CharacterDialog(randomDialog[random_index])
