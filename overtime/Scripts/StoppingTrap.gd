extends Node3D

var activated = false

func _ready() -> void:
	if PlayerManager.Loop0:
		$".".visible = false

func _on_area_3d_area_entered(area: Area3D) -> void:
	print(activated)
	if PlayerManager.Loop0:
		return
	
	if not activated && (area.is_in_group("player") or area.name == "Player"):
		PlayerManager.player.trapped = true
		activated = true
