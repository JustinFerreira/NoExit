#I thought of a feature for a game im not 
#sure how to start implenting and needed help 
#trying to make it work in a game I'm making 
#in Godot. So this is for a horror game id like 
#to make a somewhat transporting mechanic but really 
#what i want to do is make it so that an end to a hallways 
#is black and looks like a deeper hallway but really its kinda 
#just segmenting parts of a bigger build but also it allows for 
#the 

extends Node3D
class_name WallBuddy

@export var destination_wall_buddy: WallBuddy

var _cooldown: bool = false

func _on_area_3d_area_entered(area: Area3D) -> void:
	if _cooldown:
		return
	var player = area.get_parent()
	if not player.is_in_group("player"):
		return
	if destination_wall_buddy == null:
		push_warning("WallBuddy has no destination assigned!")
		return

	var source_mesh = get_node("TeleportMesh")
	var dest_mesh = destination_wall_buddy.get_node("TeleportMesh")
	_apply_teleport(player, source_mesh, dest_mesh)

func _apply_teleport(player: CharacterBody3D, source_mesh: Node3D, dest_mesh: Node3D) -> void:
	var head: Node3D = player.get_node("Head")

	# Reset bob so camera origin is clean before position changes
	player.reset_headbob()

	# --- Position ---
	# Preserve lateral offset AND depth through the wall so the player exits
	# at the correct distance rather than snapping to the wall center plane.
	var to_player = player.global_position - source_mesh.global_position
	var lateral  = source_mesh.global_transform.basis.x.dot(to_player)
	var depth    = source_mesh.global_transform.basis.z.dot(to_player)
	var relative_y = player.global_position.y - source_mesh.global_position.y

	var new_pos = dest_mesh.global_position
	new_pos += dest_mesh.global_transform.basis.x * -lateral  # flip X (left/right mirror)
	new_pos += dest_mesh.global_transform.basis.z * depth     # +depth: preserve entry distance
	new_pos.y = dest_mesh.global_position.y + relative_y
	player.global_position = new_pos

	# --- Velocity ---
	# Flip both X and Z in portal-local space, then transform to dest world space.
	# This correctly carries forward momentum and preserves strafe direction.
	var local_vel = source_mesh.global_transform.basis.inverse() * player.velocity
	local_vel.x = -local_vel.x
	local_vel.z = -local_vel.z
	player.velocity = dest_mesh.global_transform.basis * local_vel

	# --- Rotation ---
	# Flip both X and Z in portal-local space before transforming to dest space.
	# This is the correct mirror transform: forward stays forward, left stays left,
	# right stays right — verified numerically for all angles.
	# (Flip Z only: left/right are mirrored. No flip: player faces back into the wall.)
	var head_forward = -head.global_transform.basis.z
	var local_forward = source_mesh.global_transform.basis.inverse() * head_forward
	local_forward.x = -local_forward.x
	local_forward.z = -local_forward.z
	var new_forward = dest_mesh.global_transform.basis * local_forward
	new_forward.y = 0.0
	new_forward = new_forward.normalized()
	head.rotation.y = atan2(-new_forward.x, -new_forward.z)

	# --- Cooldown ---
	# Prevent the player from immediately re-triggering the destination wall.
	_cooldown = true
	destination_wall_buddy._cooldown = true
	get_tree().create_timer(0.5).timeout.connect(_reset_cooldown)
	get_tree().create_timer(0.5).timeout.connect(destination_wall_buddy._reset_cooldown)

func _reset_cooldown() -> void:
	_cooldown = false
