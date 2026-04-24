extends Interactable

var counter = 0

func _ready():
	pass

func _on_interacted(body: Variant) -> void:
	if counter > 0:
		counter -= 1
	else:
		PlayerManager.player.trapped = false
		$"..".visible = false
		$"../Area3D/CollisionShape3D".disabled = true 
		$CollisionShape3D.disabled = true
