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
## When true this wall is exit-only: entering it does nothing, and when used
## as a destination the player is placed relative to the wall itself (not
## TeleportMesh), so no manual offset tuning is needed.
@export var exit_only: bool = false
## Fine-tune the exit position in world space without moving the wall node.
## Tweak X/Y/Z until the transition looks seamless, then leave it.
@export var exit_offset: Vector3 = Vector3.ZERO

var _cooldown: bool = false

func _on_area_3d_area_entered(area: Area3D) -> void:
	if _cooldown:
		return
	if exit_only:
		return  # this wall is an exit only — walking into it doesn't teleport
	var player = area.get_parent()
	if not player.is_in_group("player"):
		return
	if destination_wall_buddy == null:
		push_warning("WallBuddy has no destination assigned!")
		return

	var source_ref: Node3D
	var dest_ref: Node3D
	if destination_wall_buddy.exit_only:
		# Use both wall roots as references so the player lands right at the
		# dest wall surface with the same relative offset they had at the source.
		# No TeleportMesh adjustment required on either wall.
		source_ref = self
		dest_ref = destination_wall_buddy
	else:
		source_ref = get_node("TeleportMesh")
		dest_ref = destination_wall_buddy.get_node("TeleportMesh")

	_apply_teleport(player, source_ref, dest_ref)

func _apply_teleport(player: CharacterBody3D, source_mesh: Node3D, dest_mesh: Node3D) -> void:
	var head: Node3D = player.get_node("Head")

	# Reset bob so camera origin is clean before position changes
	player.reset_headbob()
	print("Teleport entry position:  ", player.global_position)

	if destination_wall_buddy.exit_only:
		# Exit-only walls are elevator-style: same XZ, different Y.
		# Just displace the player by the offset between the two wall roots —
		# no portal math, no rotation change, player continues in the same direction.
		var displacement = dest_mesh.global_position - source_mesh.global_position
		player.global_position = player.global_position + displacement + destination_wall_buddy.exit_offset
		print("Teleport exit position:   ", player.global_position)
		_start_cooldown()
		return

	# --- Position (standard 180°-facing portal) ---
	var to_player = player.global_position - source_mesh.global_position
	var lateral   = source_mesh.global_transform.basis.x.dot(to_player)
	var depth     = source_mesh.global_transform.basis.z.dot(to_player)
	var relative_y = player.global_position.y - source_mesh.global_position.y

	var new_pos = dest_mesh.global_position
	new_pos += dest_mesh.global_transform.basis.x * -lateral
	new_pos += dest_mesh.global_transform.basis.z * depth
	new_pos.y = dest_mesh.global_position.y + relative_y
	new_pos += destination_wall_buddy.exit_offset
	player.global_position = new_pos
	print("Teleport exit position:   ", player.global_position)

	# --- Velocity ---
	var local_vel = source_mesh.global_transform.basis.inverse() * player.velocity
	local_vel.x = -local_vel.x
	local_vel.z = -local_vel.z
	player.velocity = dest_mesh.global_transform.basis * local_vel

	# --- Rotation ---
	var head_forward = -head.global_transform.basis.z
	var local_forward = source_mesh.global_transform.basis.inverse() * head_forward
	local_forward.x = -local_forward.x
	local_forward.z = -local_forward.z
	var new_forward = dest_mesh.global_transform.basis * local_forward
	new_forward.y = 0.0
	new_forward = new_forward.normalized()
	head.rotation.y = atan2(-new_forward.x, -new_forward.z)

	_start_cooldown()

func _start_cooldown() -> void:
	_cooldown = true
	destination_wall_buddy._cooldown = true
	get_tree().create_timer(0.5).timeout.connect(_reset_cooldown)
	get_tree().create_timer(0.5).timeout.connect(destination_wall_buddy._reset_cooldown)

func _reset_cooldown() -> void:
	_cooldown = false
