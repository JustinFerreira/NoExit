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
	var emission_energy = lamp_light
	lamp_light.light_energy = randf()
	material.set("emission_energy_multiplier",emission_energy)
	await get_tree().create_timer(randf_range(0.06, 0.1)).timeout
	flash()
