## No Exit
## Overtime Studios
## Last updated 10/19/26 by Justin Ferreira
## Npc Random Dialogue Script
## - For NPCs that just sit at their desk.
## so they can spit out random stuff on interaction
## - built on NPC (idle animation and typing sounds are set in its inspector)

extends NPC

const Dance := preload("res://Scripts/NPCs/Dance.gd")
## Dancing (the fire alarm - Dance.gd): up out of the chair, this far back
## from the desk (level units), and back down after.
const DANCE_STEP_BACK := 1.0
var _dance := {}
var _dance_from := Vector3.ZERO

func _npc_ready() -> void:
	add_to_group("office_dancer")

## The fire alarm party: gets up and dances for `seconds`.
func dance(seconds: float) -> void:
	if not _dance.is_empty() or root == null:
		return
	var sk := root.get_node_or_null("Skeleton3D") as Skeleton3D
	if sk == null:
		return
	_dance_from = root.global_position
	var fwd := root.global_transform.basis.z if model_faces_plus_z else -root.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() > 0.001:
		root.global_position -= fwd.normalized() * DANCE_STEP_BACK
	# (the desk workers in the levels have no Idle Animation Player set - their
	# typing one sits next to the skeleton)
	var player: AnimationPlayer = idle_animation_player if idle_animation_player else root.get_node_or_null("AnimationPlayer")
	_dance = Dance.start(sk, player)
	await get_tree().create_timer(seconds).timeout
	if not is_inside_tree():
		return
	Dance.stop(_dance)
	_dance = {}
	root.global_position = _dance_from


func _on_interacted(_body: Variant) -> void:
	GetRandomDialog()

## One of this NPC's lines, picked at random.
func GetRandomDialog():
	# Lines set in the inspector win; otherwise the shared "busy" lines.
	say_random(random_lines if not random_lines.is_empty() else EventManager.random_npc_busy_dialog)
