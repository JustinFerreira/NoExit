## No Exit
## Overtime Studios
## Dead Body
## - A body lying on the garage floor that can be searched (LootContainer,
##   kind "body"). Built from the office NPC's skinned model, posed on the
##   last frame of the Zombie Dying animation (they share the Mixamo rig), and
##   sized to the player. Searching it rolls LootSheet's "body" table.
## - LootSpots.spawn_bodies puts a few of these at random spots every load.
## - No collision you can bump into - just a click box round it (on the
##   click-only layer, like hiding under a car) to search it.

extends Node3D

const NPC_SCENE := preload("res://Assets/Characters/NPCS/NPC.tscn")
const DYING_SCENE := preload("res://Assets/Characters/Animations/Zombie Dying.fbx")
const LOOT_CONTAINER := preload("res://Scripts/Loot/LootContainer.gd")
const LOOT_SHEET := preload("res://Scripts/Loot/LootSheet.gd")
const CLICK_LAYER := 1 << 6
## How tall the body would stand, as a share of the player's height.
const HEIGHT_OF_PLAYER := 0.95
## Click box: this much bigger than the body all round (world units).
const CLICK_PAD := 0.15
## Click box at least this tall, as a share of the player's height.
const CLICK_UP := 0.4

var _skeleton: Skeleton3D
var _mesh: MeshInstance3D

## Builds the body here (call after it's in the tree, so it can measure the
## player). persist_id: a fresh id per body, so a new one isn't "searched".
func build(persist_id: String) -> void:
	var npc := NPC_SCENE.instantiate()
	_skeleton = npc.get_node("Skeleton3D") as Skeleton3D
	npc.remove_child(_skeleton)
	npc.free()
	_skeleton.name = "Skeleton3D"
	add_child(_skeleton)
	for m in _skeleton.get_children():
		if m is MeshInstance3D and m.skin:
			_mesh = m
	var standing := _standing_height()

	# the dying animation, played to its last frame and held there
	var dying := DYING_SCENE.instantiate()
	var src := dying.get_node("AnimationPlayer") as AnimationPlayer
	var lib := src.get_animation_library("")
	dying.free()
	var anim := AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", lib)
	var a := lib.get_animation("mixamo_com")
	a.loop_mode = Animation.LOOP_NONE
	anim.play("mixamo_com")
	anim.seek(a.length, true)
	anim.pause()

	# player-sized
	var player_h := _player_height()
	if standing > 0.001 and player_h > 0.0:
		scale = Vector3.ONE * (player_h * HEIGHT_OF_PLAYER / standing)

	# lying where it was put (the animation can slide the hips off the spot)
	var box := _bones_box()
	var c := box.get_center()
	global_position += Vector3(global_position.x - c.x, global_position.y - box.position.y, global_position.z - c.z)

	_make_click_box(persist_id)

## World box round every bone as posed now.
func _bones_box() -> AABB:
	var box := AABB()
	for i in _skeleton.get_bone_count():
		var p := _skeleton.global_transform * _skeleton.get_bone_global_pose(i).origin
		box = AABB(p, Vector3.ZERO) if i == 0 else box.expand(p)
	return box

## Head-to-toe in the rest pose (model units).
func _standing_height() -> float:
	var lo := INF
	var hi := -INF
	for i in _skeleton.get_bone_count():
		var y := _skeleton.get_bone_global_rest(i).origin.y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return (hi - lo) * 1.1   # (the top of the head is past the last bone)

func _player_height() -> float:
	# (eye height from the feet, plus the top of the head)
	var p = PlayerManager.player
	if not is_instance_valid(p) or not is_instance_valid(p.CAMERA):
		return 0.0
	return (p.CAMERA.global_position.y - p.global_position.y) * 1.08

## The searchable click box round the body, outlined with the body itself.
func _make_click_box(persist_id: String) -> void:
	var box := _bones_box().grow(CLICK_PAD * 0.5)
	# taller than the body (it's flat on the floor): the player's reach is
	# about their own height, so they can search it standing beside it
	var reach_up := _player_height() * CLICK_UP
	if box.size.y < reach_up:
		box.size.y = reach_up
	var click := StaticBody3D.new()
	click.name = "SearchBody"
	click.set_script(LOOT_CONTAINER)
	click.table = "body"
	click.persist_id = persist_id
	click.search_time = LOOT_SHEET.search_time("body")
	click.has_outline = true
	click.mesh = _mesh
	click.collision_layer = CLICK_LAYER
	click.collision_mask = 0
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(maxf(box.size.x, CLICK_PAD), maxf(box.size.y, CLICK_PAD), maxf(box.size.z, CLICK_PAD))
	shape.shape = b
	click.add_child(shape)
	add_child(click)
	click.global_transform = Transform3D(Basis(), box.get_center())
