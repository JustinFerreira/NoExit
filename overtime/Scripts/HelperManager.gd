extends Node

var fog_remover

var killer_eyes: MeshInstance3D 

func fade_fog_density(target_density: float, duration: float = 1.0) -> void:
	if fog_remover and fog_remover.material:
		var tween = create_tween()
		tween.tween_property(fog_remover.material, "density", target_density, duration)

# Helper function to find the shortest Y rotation path
func find_shortest_y_rotation(current: float, target: float) -> float:
	var difference = fmod(target - current, TAU)
	if difference > PI:
		difference -= TAU
	elif difference < -PI:
		difference += TAU
	return current + difference
