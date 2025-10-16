extends CollisionObject3D
class_name Interactable

signal interacted(body)


@export var prompt_message = "Interact"
@export var is_interactable = true

func interact(body):
	if is_interactable == false:
		prompt_message = ""
	else:
		interacted.emit(body)
		
func _on_interaction_complete() -> void:
	is_interactable = false
	prompt_message = ""
