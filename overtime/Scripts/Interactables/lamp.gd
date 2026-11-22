## No Exit
## Overtime Studios
## Last updated 2/14/26 by Andrew Lang
## Lamp
## - The flickering desk lamp on the main menu: every ~0.1 s the bulb picks
##   a new brightness (now and then a deep dip) and the lampshade's glow
##   follows it.

extends Node3D

@onready var lamp_light: SpotLight3D = $LampLight
@onready var m_lamp: MeshInstance3D = $MLamp

func _ready() -> void:
	_flicker()

func _flicker() -> void:
	var material = m_lamp.get_surface_override_material(0)
	while is_inside_tree():
		# glow follows the previous brightness, like the original flicker
		var emission_energy := lamp_light.light_energy * 3
		var low := 0.4 if randf() < 0.9 else 0.1   # 1 in 10: a deep dip
		lamp_light.light_energy = randf_range(low, 0.587)
		if material:
			material.set("emission_energy_multiplier", emission_energy)
		await get_tree().create_timer(randf_range(0.09, 0.1)).timeout
