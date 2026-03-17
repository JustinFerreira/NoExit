extends Node3D


@export var stalking_distance: float = 15.0  # Distance killer will maintain
@export var make_killer_invisible: bool = true
@export var make_killer_silent: bool = true

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player") or area.name == "Player":
		print("DID I JUST GET ENTERED????")
		PlayerManager.stalking_mode = true
		PlayerManager.stalking_area = self
		
		# Update killer behavior
		if PlayerManager.Enemy:
			PlayerManager.Enemy.enter_stalking_mode(stalking_distance, make_killer_invisible, make_killer_silent)


func _on_area_3d_area_exited(area: Area3D) -> void:
	if area.is_in_group("player") or area.name == "Player":
		print("Leaving so soon?")
		PlayerManager.stalking_mode = false
		PlayerManager.stalking_area = null
		
		# Update killer behavior
		if PlayerManager.Enemy:
			PlayerManager.Enemy.exit_stalking_mode()
