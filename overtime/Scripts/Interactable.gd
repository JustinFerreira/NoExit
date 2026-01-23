## No Exit
## Overtime Studios

extends CollisionObject3D
class_name Interactable

signal interacted(body)


@export var prompt_message = "Interact"
@export var is_interactable = true
@export var outline_material: Material
@export var mesh: MeshInstance3D
@export var has_outline: bool

func interact(body):
	if is_interactable == false:
		prompt_message = ""
	else:
		interacted.emit(body)
		
func _on_interaction_complete() -> void:
	is_interactable = false
	prompt_message = ""
	
func show_outline() -> bool:
	if has_outline == true:
		mesh.material_overlay = outline_material
		return true
	return false
	
func hide_outline() -> void: 
	if has_outline == true:
		mesh.material_overlay = null
