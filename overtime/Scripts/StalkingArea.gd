## End Shift
## Overtime Studios
## Last updated  3/16/26 by Justin Ferreira 
## Stalking Area Script
## - When player enters this area, killer switches to stalking mode
## When player exits, killer resumes following

extends Area3D


@export var stalking_distance: float = 15.0  # Distance killer will maintain
@export var make_killer_invisible: bool = true
@export var make_killer_silent: bool = true


func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player") or area.name == "Player":
		PlayerManager.stalking_mode = true
		PlayerManager.stalking_area = self
		
		# Update killer behavior
		if PlayerManager.Enemy:
			PlayerManager.Enemy.enter_stalking_mode(stalking_distance, make_killer_invisible, make_killer_silent)

func _on_area_exited(area: Area3D) -> void:
	if area.is_in_group("player") or area.name == "Player":
		PlayerManager.stalking_mode = false
		PlayerManager.stalking_area = null
		
		# Update killer behavior
		if PlayerManager.Enemy:
			PlayerManager.Enemy.exit_stalking_mode()
