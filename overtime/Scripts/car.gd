extends Interactable

var open = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Mesh.visible = false
	$Car_Collision.visible = true
	$CollisionShape3D.visible = true




func _on_interacted(body: Variant) -> void:
	if open == false:
		$Mesh.visible = true
		$Car_Collision.visible = false
		$CollisionShape3D.visible = false
		$AnimationPlayer.play("NoExitProps")
		prompt_message = "Close Door"
		open = true
	elif open == true:
		$AnimationPlayer.play_backwards("NoExitProps")
		prompt_message = "Open Door"
		open = false;
