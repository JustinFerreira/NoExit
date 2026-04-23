extends Node3D

var activated = false

@export var light_search_height: float = 5.0  # How far above to look
@export var max_search_radius: float = 10.0   # Max horizontal distance to consider

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_area_entered(area: Area3D) -> void:
	if not activated and (area.is_in_group("player") or area.name == "Player"):
		var closest_light = get_closest_light_above()
		if closest_light:
			var omni_light = closest_light.get_node("OmniLight3D")
			if omni_light and omni_light is OmniLight3D:
					omni_light.visible = false
					
			_turn_off_mesh_emission(closest_light)
			AudioManager.play_sound(AudioManager.GetGlassBreak())
	activated = true


func get_closest_light_above() -> Node:
	var all_lights = get_tree().get_nodes_in_group("Lights")
	var valid_lights: Array = []
	var area_center = global_position
	
	# First, filter lights that are above the Area3D
	for light in all_lights:
		if not is_instance_valid(light):
			continue
			
		var light_pos = light.global_position
		
		# Check if light is above the area's top
		if light_pos.y > area_center.y:
			# Check horizontal distance
			var horizontal_dist = Vector2(
				light_pos.x - area_center.x,
				light_pos.z - area_center.z
			).length()
			
			if horizontal_dist <= max_search_radius:
				valid_lights.append({
					"node": light,
					"distance": horizontal_dist
				})
	
	# Sort by distance and return the closest
	if valid_lights.size() > 0:
		valid_lights.sort_custom(func(a, b): return a["distance"] < b["distance"])
		return valid_lights[0]["node"]
	
	return null

func _turn_off_mesh_emission(light_node: Node) -> void:
	# Find the MeshInstance3D child
	var mesh_instance = light_node.find_child("MeshInstance3D", true, false)
	if not mesh_instance:
		# Try to find any MeshInstance3D if not specifically named
		for child in light_node.get_children():
			if child is MeshInstance3D:
				mesh_instance = child
				break
	
	if mesh_instance and mesh_instance.mesh:
		# Check if there's a surface material override
		for i in range(mesh_instance.mesh.get_surface_count()):
			var original_material = mesh_instance.get_surface_override_material(i)
			if not original_material:
				original_material = mesh_instance.mesh.surface_get_material(i)
			
			if original_material and original_material is StandardMaterial3D:
				# Create a unique duplicate of the material
				var new_material = original_material.duplicate()
				
				# Turn off emission on the duplicated material
				new_material.emission_enabled = false
				new_material.emission = Color.BLACK
				
				# Apply the new unique material as an override
				mesh_instance.set_surface_override_material(i, new_material)
				
			elif original_material and original_material is ShaderMaterial:
				# Create a unique duplicate for shader materials
				var new_material = original_material.duplicate()
				
				# Turn off emission parameters
				new_material.set_shader_parameter("emission_enabled", false)
				new_material.set_shader_parameter("emission", Color.BLACK)
				
				# Apply the new unique material as an override
				mesh_instance.set_surface_override_material(i, new_material)
