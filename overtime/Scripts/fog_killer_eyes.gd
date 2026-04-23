extends Node3D

var activated = false

func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group("player") or area.name == "Player":
		if not activated:
			HelperManager.fade_fog_density(1,1.5)
			await get_tree().create_timer(2).timeout
			HelperManager.killer_eyes.visible = true
			AudioManager.play_sound(AudioManager.HeavyBreath)
			await get_tree().create_timer(3).timeout
			HelperManager.killer_eyes.visible = false
			HelperManager.fade_fog_density(-8,1.5)
			activated = true
	
