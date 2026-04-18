extends Interactable

var counter = 4

func _ready():
	pass

func _on_interacted(body: Variant) -> void:
	if counter > 0:
		counter -= 1
	else:
		PlayerManager.player.trapped = false
		$"..".visible = false
