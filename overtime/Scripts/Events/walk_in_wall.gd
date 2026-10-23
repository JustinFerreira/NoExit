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
## Check this on the DESTINATION wall if it's been rotated/mirrored 180°
## in the editor from the game's normal wall-facing setup (e.g. to fit
## the hallway layout). The portal math below assumes a specific
## relative facing between source and destination walls; flipping the
## destination wall's orientation throws that off and the player comes
## out slightly offset/facing the wrong way. Turning this on undoes that
## extra 180° so the exit lines up again. Only affects the standard
## portal math (exit_only walls don't rotate the player, so this does
## nothing there).
@export var flip_exit: bool = false

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
	#print("Teleport entry position:  ", player.global_position)

	if destination_wall_buddy.exit_only:
		# Exit-only walls are elevator-style: same XZ, different Y.
		# Just displace the player by the offset between the two wall roots —
		# no portal math, no rotation change, player continues in the same direction.
		var displacement = dest_mesh.global_position - source_mesh.global_position
		player.global_position = player.global_position + displacement + destination_wall_buddy.exit_offset
		#print("Teleport exit position:   ", player.global_position)
		_start_cooldown()
		return

	# --- Position (standard 180°-facing portal) ---
	# WalkInWall instances are almost always scaled non-uniformly to fit
	# their opening (see e.g. the Hallway/Hallway2 or Transport walls -
	# their root transforms aren't unit-length on every axis). Projecting
	# onto a basis vector with .dot() like this used to scales the result
	# by that vector's own length, and then re-applying it on the dest
	# wall's (possibly different) basis scales it AGAIN - offsets came out
	# multiplied by the wall's scale twice. Using the full basis inverse/
	# multiply (same technique the velocity/rotation code below already
	# uses) removes and re-applies scale correctly instead of double-
	# counting it.
	var to_player = player.global_position - source_mesh.global_position
	to_player.y = 0.0  # Y is handled separately below via relative_y.
	var local_offset = source_mesh.global_transform.basis.inverse() * to_player
	var relative_y = player.global_position.y - source_mesh.global_position.y

	# Destination wall rotated 180° in the editor? Flip which way we turn
	# the player around instead of always assuming the same convention.
	var flip_sign: float = 1.0 if destination_wall_buddy.flip_exit else -1.0
	local_offset.x *= flip_sign

	var new_pos = dest_mesh.global_position + dest_mesh.global_transform.basis * local_offset
	new_pos.y = dest_mesh.global_position.y + relative_y
	new_pos += destination_wall_buddy.exit_offset
	player.global_position = new_pos
	#print("Teleport exit position:   ", player.global_position)

	# --- Velocity ---
	var local_vel = source_mesh.global_transform.basis.inverse() * player.velocity
	local_vel.x = flip_sign * local_vel.x
	local_vel.z = flip_sign * local_vel.z
	player.velocity = dest_mesh.global_transform.basis * local_vel

	# --- Rotation ---
	var head_forward = -head.global_transform.basis.z
	var local_forward = source_mesh.global_transform.basis.inverse() * head_forward
	local_forward.x = flip_sign * local_forward.x
	local_forward.z = flip_sign * local_forward.z
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
