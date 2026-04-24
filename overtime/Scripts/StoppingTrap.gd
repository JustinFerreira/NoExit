extends Node3D

var activated = false

func _ready() -> void:
	if PlayerManager.Loop0:
		$".".visible = false
		$Area3D/CollisionShape3D.disabled = true
		$StaticBody3D/CollisionShape3D.disabled = true
	$StaticBody3D.is_interactable = false

func _on_area_3d_area_entered(area: Area3D) -> void:
	if PlayerManager.Loop0:
		return
	
	if not activated && (area.is_in_group("player") or area.name == "Player"):
		$StaticBody3D.is_interactable = true
		AudioManager.play_sound(AudioManager.BearTrap)
		AudioManager.play_sound(AudioManager.HeavyDamage)
		PlayerManager.player.trapped = true
		$BearTrapAnimated.visible = false
		$BearTrapAnimated2.visible = true
		activated = true
