## No Exit
## Overtime Studios
## Last updated 2/14/26 by Andrew Lang
## Lamp Script
## - this controls flicker of lamp on main menu

extends Node3D
@onready var lamp_light = $LampLight
@onready var m_lamp = $MLamp

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	flash()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
func flash():
	var material = m_lamp.get_surface_override_material(0)
	var emission_energy = lamp_light.light_energy * 3
	var control = randf_range(1,100)
	if control>10:
		lamp_light.light_energy = randf_range(0.4, 0.587)
		material.set("emission_energy_multiplier",emission_energy)
		await get_tree().create_timer(randf_range(0.09, 0.1)).timeout
	else:
		lamp_light.light_energy = randf_range(0.1, 0.587)
		material.set("emission_energy_multiplier",emission_energy)
		await get_tree().create_timer(randf_range(0.09, 0.1)).timeout
	flash()
