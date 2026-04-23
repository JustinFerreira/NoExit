extends Node3D

var activated = false

var original_emission_data: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group("player") or area.name == "Player":
		if not activated:
			for light in PlayerManager.ParkingGarageLights:
				# Assuming light_panel_root is the Node3D root
				# Find the OmniLight3D child (any depth)
				var omni_light = light.get_node("OmniLight3D")
				if omni_light and omni_light is OmniLight3D:
					omni_light.visible = false
				_turn_off_mesh_emission(light)
				
			await get_tree().create_timer(2).timeout
			
			for light in PlayerManager.ParkingGarageLights:
				# Assuming light_panel_root is the Node3D root
				# Find the OmniLight3D child (any depth)
				var omni_light = light.get_node("OmniLight3D")
				if omni_light and omni_light is OmniLight3D:
					omni_light.visible = true
				
				_turn_on_mesh_emission(light)
			activated = true

func _turn_off_mesh_emission(light_node: Node) -> void:
	var mesh_instance = light_node.find_child("MeshInstance3D", true, false)
	if not mesh_instance:
		for child in light_node.get_children():
			if child is MeshInstance3D:
				mesh_instance = child
				break
	
	if mesh_instance and mesh_instance.mesh:
		if not original_emission_data.has(light_node):
			original_emission_data[light_node] = []
		
		for i in range(mesh_instance.mesh.get_surface_count()):
			var original_material = mesh_instance.get_surface_override_material(i)
			if not original_material:
				original_material = mesh_instance.mesh.surface_get_material(i)
			
			if original_material and original_material is StandardMaterial3D:
				# Create a duplicate material to avoid modifying the original
				var new_material = original_material.duplicate()
				
				# Store original material reference
				original_emission_data[light_node].append({
					"surface": i,
					"original_material": original_material,
					"is_override": mesh_instance.get_surface_override_material(i) != null
				})
				
				# Turn off emission on the duplicated material
				new_material.emission_enabled = false
				new_material.emission = Color.BLACK
				
				# Apply the duplicated material
				mesh_instance.set_surface_override_material(i, new_material)

func _turn_on_mesh_emission(light_node: Node) -> void:
	if original_emission_data.has(light_node):
		var mesh_instance = light_node.find_child("MeshInstance3D", true, false)
		if not mesh_instance:
			for child in light_node.get_children():
				if child is MeshInstance3D:
					mesh_instance = child
					break
		
		if mesh_instance and mesh_instance.mesh:
			for data in original_emission_data[light_node]:
				if data["is_override"]:
					# Restore the original override material
					mesh_instance.set_surface_override_material(data["surface"], data["original_material"])
				else:
					# Clear the override to use the original mesh material
					mesh_instance.set_surface_override_material(data["surface"], null)
		
		original_emission_data.erase(light_node)
