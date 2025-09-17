extends Interactable


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_interacted(body: Variant) -> void:
	if PlayerManager.RemoveItemByName("DoorKey"):
		if is_inside_tree():
			get_parent().remove_child(self)
			queue_free()
