## No Exit
## Overtime Studios
## Helper Manager (autoload "HelperManager")
## - Small shared helpers used by several scripts: fog fades, the killer's
##   glowing eyes, angle maths, "is this the player?" checks for trigger
##   areas, switching ceiling light panels off and on, and lighting the
##   elevators the same on every floor.

extends Node

## Render layer the elevator cabins are drawn on (see light_elevator_on_its_own).
const ELEVATOR_LAYER: int = 3
const ELEVATOR_BIT: int = 1 << (ELEVATOR_LAYER - 1)

## The fog volume the levels fade in/out (set by the level that owns it).
var fog_remover
## The killer's glowing eyes shown in the fog (set by the level that owns them).
var killer_eyes: MeshInstance3D

## Tweens the fog volume's density to target_density over duration seconds.
func fade_fog_density(target_density: float, duration: float = 1.0) -> void:
	if fog_remover and fog_remover.material:
		var tween = create_tween()
		tween.tween_property(fog_remover.material, "density", target_density, duration)

## Returns target as an angle (radians) that is the shortest turn away from
## current, so tweening current -> result never spins the long way round.
func find_shortest_y_rotation(current: float, target: float) -> float:
	var difference = fmod(target - current, TAU)
	if difference > PI:
		difference -= TAU
	elif difference < -PI:
		difference += TAU
	return current + difference

## True if a trigger Area3D that something walked into belongs to the player
## (the player's "Player" area, or anything in the "player" group).
func is_player_area(area: Node) -> bool:
	return area != null and (area.is_in_group("player") or area.name == "Player")

## Switches a ceiling light panel off or back on: hides/shows its
## "OmniLight3D" child and swaps the glowing mesh's materials for unlit copies
## (the originals are kept on the mesh and put back when it's lit again).
func set_light_panel_lit(panel: Node, lit: bool) -> void:
	if not is_instance_valid(panel):
		return
	var omni := panel.get_node_or_null("OmniLight3D")
	if omni is OmniLight3D:
		omni.visible = lit
	var mesh := _panel_mesh(panel)
	if mesh == null or mesh.mesh == null:
		return
	if lit:
		if not mesh.has_meta("_lit_overrides"):
			return
		var saved: Array = mesh.get_meta("_lit_overrides")
		for i in saved.size():
			mesh.set_surface_override_material(i, saved[i])
		mesh.remove_meta("_lit_overrides")
		return
	if mesh.has_meta("_lit_overrides"):
		return   # already off
	var saved := []
	for i in mesh.mesh.get_surface_count():
		var override := mesh.get_surface_override_material(i)
		saved.append(override)
		var mat := override if override else mesh.mesh.surface_get_material(i)
		if mat is StandardMaterial3D:
			var off: StandardMaterial3D = mat.duplicate()
			off.emission_enabled = false
			off.emission = Color.BLACK
			mesh.set_surface_override_material(i, off)
		elif mat is ShaderMaterial:
			var off_shader: ShaderMaterial = mat.duplicate()
			off_shader.set_shader_parameter("emission_enabled", false)
			off_shader.set_shader_parameter("emission", Color.BLACK)
			mesh.set_surface_override_material(i, off_shader)
	mesh.set_meta("_lit_overrides", saved)

## The panel's glowing mesh: a child named "MeshInstance3D", else the first
## MeshInstance3D found under it.
func _panel_mesh(panel: Node) -> MeshInstance3D:
	var named := panel.find_child("MeshInstance3D", true, false)
	if named is MeshInstance3D:
		return named
	var any := panel.find_children("*", "MeshInstance3D", true, false)
	return any[0] if any.size() > 0 else null

## Lights an elevator so it looks the same on every floor, with no switching
## as the player walks in or out:
## - The level's lights never reach it. They cast no shadows, so they used
##   to shine through the cabin walls and each floor's cabin looked
##   different. Inside, only its own light (and the flashlight) light it.
## - So the outside doesn't go black, a shadow-casting light up near the
##   ceiling out in front (like the level's ceiling lights) lights its front (front_energy matches the floor's lighting). With
##   the doors shut the walls shadow the inside, so every cabin looks the
##   same; with them open the floor's light spills in through the doorway
##   and fades away as they close - no sudden switch.
## Called by each elevator when it's ready.
func light_elevator_on_its_own(cabin: Node3D, own_light: Light3D, front_energy: float) -> void:
	# its models go on their own layer (outline masks and invisible stand-ins
	# are on other layers - left alone)
	for model in cabin.find_children("*", "GeometryInstance3D", true, false):
		if model.layers == 1:
			model.layers = ELEVATOR_BIT
	own_light.add_to_group("elevator_light")
	own_light.light_cull_mask |= ELEVATOR_BIT
	# the level's lights (not the player's flashlight, not other elevators')
	var level: Node = cabin.owner if cabin.owner else cabin.get_tree().current_scene
	var player := level.get_node_or_null("Player")
	for light in level.find_children("*", "Light3D", true, false):
		if light.is_in_group("elevator_light") or cabin.is_ancestor_of(light):
			continue
		if player and player.is_ancestor_of(light):
			continue
		light.light_cull_mask &= ~ELEVATOR_BIT
	# the front light: up near the ceiling, 6 m out from the doors (the
	# door collision moves up and down as they open, so heights come from
	# the floor)
	var door: Node3D = cabin.get_node("ElevatorCollisions/DoorCollision")
	var middle: Node3D = cabin.get_node("ElevatorCollisions/FloorCollision")
	var out := door.global_position - middle.global_position
	out.y = 0.0
	out = out.normalized()
	var aim := Vector3(door.global_position.x, middle.global_position.y + 1.9, door.global_position.z)
	var front := OmniLight3D.new()
	front.name = "FrontLight"
	front.add_to_group("elevator_light")
	front.light_cull_mask = ELEVATOR_BIT
	front.light_energy = front_energy
	front.omni_range = 16.0
	front.shadow_enabled = true    # the walls and doors keep it out of the cabin
	front.transform = cabin.global_transform.affine_inverse() * Transform3D(Basis(), aim + out * 6.0 + Vector3.UP * 2.2)
	# deferred: the office elevator calls this from a child's _ready, while
	# the cabin is still busy adding its children
	cabin.add_child.call_deferred(front)

## Waits until the navigation map has taken in the level that was just
## loaded: it syncs on a physics frame after the regions are added. (A map
## being "ready" isn't enough - on a reload it still holds the last level's
## navigation for a frame or two, and random points / paths come back empty.)
func nav_map_updated(tree: SceneTree, map: RID, max_frames: int = 60) -> void:
	var start := NavigationServer3D.map_get_iteration_id(map)
	for i in max_frames:
		await tree.physics_frame
		if NavigationServer3D.map_get_iteration_id(map) > start:
			return

## The floor right under `at` (within 2 units up / 3 down), or `at` itself if
## there's none - for putting an enemy's feet on the floor (the nav mesh
## floats above it; placed there it drops in).
func floor_at(world: World3D, at: Vector3, exclude: Array[RID] = []) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 3.0, 0xFFFFFFFF, exclude)
	q.collide_with_areas = false
	var hit := world.direct_space_state.intersect_ray(q)
	return hit.position + Vector3.UP * 0.02 if hit else at
