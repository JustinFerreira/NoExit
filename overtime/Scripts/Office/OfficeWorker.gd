## No Exit
## Overtime Studios
## Office Worker
## - One of the rogue office's walking workers (OfficeLife.gd makes them):
##   built from the office NPC's model (NPC.tscn) with walk / stand / sit /
##   type animations from Assets/Characters/Animations, a shirt tint and a
##   size of their own (from the run's staff roster - OfficeQuests.staff).
## - Moves by itself: walk_to(spot) follows a path over the navigation
##   meshes (the office's, the new rooms' - through the door links), then
##   stands, sits or types there. OfficeLife strings these into errands.
## - Can carry a prop in hand (papers, a folder, a mug): hold(kind).
## - Clicked: stops, turns to the player and talks - asks for their lost
##   item (OfficeQuests), takes it if the player has it (coins), or says a
##   line for their job. Shows a "!" over their head while they want
##   something (green once the player is carrying it).
## - The vendor (role "vendor") sits in the break room and sells stamina
##   charges: click once for the offer, again to buy (VENDOR_PRICE coins).
## - No body to bump into: the click box is on the click-only layer.

extends NPC

const OfficeQuests := preload("res://Scripts/Office/OfficeQuests.gd")
const NPC_SCENE := preload("res://Assets/Characters/NPCS/NPC.tscn")
const ANIMS := {
	"walk": "res://Assets/Characters/Animations/Walking.fbx",
	"idle": "res://Assets/Characters/Animations/Old Man Idle.fbx",
	"type": "res://Assets/Characters/Animations/Typing.fbx",
	"sit": "res://Assets/Characters/Animations/Type To Sit.fbx",
}
const CLICK_LAYER := 1 << 6
## Walking speed (level units a second - the level is about 1.8x real size).
const WALK_SPEED := 2.4
## Real metres -> level units (props in hand).
const UNIT := 1.8
## Walking round people (NpcAvoid): a path corner counts as passed this
## close; the last AVOID_FINAL onto their spot is straight (no avoiding);
## STUCK_TIME seconds without getting closer = give that point up.
const AVOID_PASS := 0.9
const AVOID_FINAL := 1.6
const STUCK_TIME := 3.0
const NpcAvoid := preload("res://Scripts/NPCs/NpcAvoid.gd")
const Dance := preload("res://Scripts/NPCs/Dance.gd")
const OfficeJobs := preload("res://Scripts/Office/OfficeJobs.gd")
const TURN_SPEED := 8.0
## Their height, as a share of the player's (times their own roster size).
const HEIGHT_OF_PLAYER := 0.97
## Price of a stamina charge at the vendor.
const VENDOR_PRICE := 5
## Seconds the vendor's offer stays open for the second click.
const OFFER_TIME := 6.0

const LINES := {
	"courier": ["Can't stop, these need signatures.", "Third copy of this memo today.", "If anyone asks, I was never here."],
	"copier": ["The copier jammed again. Of course it did.", "Two hundred copies. Double sided. Collated.", "I know that machine better than my own family."],
	"snacker": ["Someone keeps eating my yogurt.", "Is it break time? It's always break time.", "The coffee here tastes like toner."],
	"social": ["Another meeting about the last meeting.", "Did you hear about the garage? People keep... not coming back.", "Let's circle back on that."],
	"vendor": ["Stamina charges. 5 coins. Best price on this floor.", "Running out of breath down there? I can help."],
}

## Set before adding to the tree (OfficeLife)
var worker_name := "Worker"
var role := "social"
var tint := Color.WHITE
var size_mul := 1.0

## What they're up to (OfficeLife looks at these)
var busy := false              # on an errand
var spot: Dictionary = {}      # the spot they're at / heading for
var home: Dictionary = {}      # where they hang about between errands
var in_room := ""

var _skeleton: Skeleton3D
var _anim: AnimationPlayer
var _held: Node3D
var _marker: Label3D
var _talk_until := 0.0         # stopped to talk to the player until (ms)
var _offer_until := 0.0        # vendor: the offer is open until (ms)
var _sitting := false
var _walk_id := 0              # a newer walk_to cancels an older one
var _dance := {}               # dancing (the fire alarm - Dance.gd)

static var _libs := {}         # anim name -> AnimationLibrary (shared)

## Builds the model around `root_node` (call before adding this to the
## tree): this script goes on its click body, under the root.
static func make(parent: Node, at: Dictionary, info: Dictionary) -> Node:
	var root := Node3D.new()
	root.name = "Worker_%s" % info.name
	root.add_to_group("office_npc")   # (doors open for them - SwingDoor)
	root.add_to_group("npc_body")     # (NPCs walk round each other - NpcAvoid)
	var npc := NPC_SCENE.instantiate()
	var sk := npc.get_node("Skeleton3D") as Skeleton3D
	npc.remove_child(sk)
	npc.free()
	root.add_child(sk)
	sk.owner = null
	var anim := AnimationPlayer.new()
	anim.name = "Anim"
	root.add_child(anim)
	anim.root_node = NodePath("..")
	for k in ANIMS:
		anim.add_animation_library(k, _lib(k))
	var click := StaticBody3D.new()
	click.name = "Click"
	click.collision_layer = CLICK_LAYER
	click.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cs.shape = cap
	click.add_child(cs)
	click.set_script(load("res://Scripts/Office/OfficeWorker.gd"))
	click.add_to_group("office_dancer")   # (the fire alarm party - Dance.gd)
	click.worker_name = info.name
	click.role = info.role
	click.tint = info.get("tint", Color.WHITE)
	click.size_mul = info.get("size", 1.0)
	click.npc_root = root
	click.idle_animation_player = anim
	click.idle_animation = "idle/mixamo_com"
	click.walk_animation_player = anim
	click.walk_animation = "walk/mixamo_com"
	click.home = at
	root.add_child(click)
	parent.add_child(root)
	root.global_position = at.pos
	return click

## One fbx animation as a looping library (made once, shared).
static func _lib(k: String) -> AnimationLibrary:
	if _libs.has(k):
		return _libs[k]
	var sc: Node = load(ANIMS[k]).instantiate()
	var src := sc.get_node("AnimationPlayer") as AnimationPlayer
	var a: Animation = src.get_animation("mixamo_com").duplicate()
	sc.free()
	a.loop_mode = Animation.LOOP_NONE if k == "sit" else Animation.LOOP_LINEAR
	var lib := AnimationLibrary.new()
	lib.add_animation("mixamo_com", a)
	_libs[k] = lib
	return lib

func _npc_ready() -> void:
	_skeleton = root.get_node("Skeleton3D")
	_anim = root.get_node("Anim")
	# their own shirt colour
	for m in _skeleton.get_children():
		if m is MeshInstance3D:
			var mat = m.get_active_material(0)
			if mat is StandardMaterial3D:
				var mine: StandardMaterial3D = mat.duplicate()
				mine.albedo_color = tint
				m.material_override = mine
	# sized against the player
	var player_h := _player_height()
	var standing := _standing_height()
	if player_h > 0.0 and standing > 0.0001:
		root.scale = Vector3.ONE * (player_h * HEIGHT_OF_PLAYER * size_mul / standing)
	var h := player_h * HEIGHT_OF_PLAYER * size_mul if player_h > 0.0 else 1.7
	var cs := get_child(0) as CollisionShape3D
	(cs.shape as CapsuleShape3D).radius = 0.3 / root.scale.x
	(cs.shape as CapsuleShape3D).height = h / root.scale.x
	cs.position = Vector3(0, h * 0.5 / root.scale.x, 0)
	# "!" over the head when they want something
	_marker = Label3D.new()
	_marker.text = "!"
	_marker.font_size = 96
	_marker.pixel_size = 0.006
	_marker.outline_size = 16
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = false
	_marker.position = Vector3(0, (h + 0.35) / root.scale.x, 0)
	_marker.scale = Vector3.ONE / root.scale.x
	root.add_child.call_deferred(_marker)   # (root is still setting up its children)
	_update_marker()
	face_direction(home.get("face", Vector3.FORWARD))
	if home.get("sit", false):
		sit()
	else:
		play_idle()

## The sitting pose is held on its last frame - don't restart it.
func _on_npc_animation_finished(anim_name: StringName) -> void:
	if String(anim_name).begins_with("sit/"):
		return
	super._on_npc_animation_finished(anim_name)

func _player_height() -> float:
	var p = PlayerManager.player
	if not is_instance_valid(p) or not is_instance_valid(p.CAMERA):
		return 0.0
	return (p.CAMERA.global_position.y - p.global_position.y) * 1.08

func _standing_height() -> float:
	var lo := INF
	var hi := -INF
	for i in _skeleton.get_bone_count():
		var y := _skeleton.get_bone_global_rest(i).origin.y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return (hi - lo) * 1.1

func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 20 == 0:
		_update_marker()

func _update_marker() -> void:
	if _marker == null:
		return
	var q := OfficeQuests.quest_of(worker_name)
	var letter := OfficeJobs.has_letter_for(worker_name)
	_marker.visible = not q.is_empty() or letter
	if _marker.visible:
		if OfficeQuests.can_hand_in(worker_name):
			_marker.modulate = Color(0.35, 1.0, 0.35)
		elif letter:
			_marker.modulate = Color(0.45, 0.75, 1.0)   # their letter
		else:
			_marker.modulate = Color(1.0, 0.85, 0.2)

## ---------------------------------------------------------------------
## Doing things (await these)
## ---------------------------------------------------------------------

func is_talking() -> bool:
	return Time.get_ticks_msec() < _talk_until

func is_dancing() -> bool:
	return not _dance.is_empty()

## The fire alarm party: whatever they're doing stops (walking, waiting -
## carried on after) and they dance for `seconds`.
func dance(seconds: float) -> void:
	if is_dancing() or _skeleton == null:
		return
	_dance = Dance.start(_skeleton, _anim)
	await get_tree().create_timer(seconds).timeout
	if not is_inside_tree():
		return
	Dance.stop(_dance)
	_dance = {}

## Walks to a spot ({pos, face, sit}) over the navigation meshes, then
## stands / sits there facing its way. False if it couldn't get there.
func walk_to(s: Dictionary) -> bool:
	_walk_id += 1
	var me := _walk_id
	var target: Vector3 = s.pos
	_sitting = false
	var map := root.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, root.global_position, target, true)
	if path.is_empty():
		return false
	# the path ends on the mesh near the spot; the spot itself (a chair, a
	# couch) can be just off it - finish with a short step straight there
	# (always for a seat, so nobody sits down in mid-air beside it)
	var gap := Vector2(path[path.size() - 1].x - target.x, path[path.size() - 1].z - target.z).length()
	if gap < 2.6 or (s.get("sit", false) and gap < 5.0):
		path.append(target)
	elif s.get("sit", false):
		s = s.duplicate()
		s.sit = false   # too far off to reach the seat: just stand there
	play_walk()
	for i in path.size():
		var p: Vector3 = path[i]
		var last := i == path.size() - 1
		var goal := Vector3(p.x, target.y if last else p.y, p.z)
		var stuck := 0.0
		var best := INF
		while is_inside_tree():
			if me != _walk_id:
				return false
			while is_talking() or is_dancing():
				if not is_dancing():
					play_idle()
				await get_tree().process_frame
				if not is_inside_tree():
					return false
			play_walk()
			var dt := get_process_delta_time()
			var flat := Vector3(goal.x - root.global_position.x, 0.0, goal.z - root.global_position.z)
			var step := WALK_SPEED * dt
			var dist := flat.length()
			# a corner of the path only needs passing near (someone may be
			# stood on it); the end spot is walked onto exactly
			if dist <= step or (not last and dist < AVOID_PASS):
				if last or dist <= step:
					root.global_position = Vector3(goal.x, _floor_y(goal), goal.z) if dist <= step else root.global_position
				break
			var dir := flat / dist
			# out of everyone's way - except the last step onto their own
			# spot (a seat between two people)
			var final_step := last and dist < AVOID_FINAL
			if not final_step:
				dir = NpcAvoid.steer(root, root.global_position, dir)
			var next := root.global_position + dir * step
			if not final_step:
				next = NpcAvoid.separate(root, next)
			root.global_position = Vector3(next.x, _floor_y(next), next.z)
			_turn_toward(dir, dt)
			# not getting any closer (boxed in): move on after a while
			if dist < best - 0.05:
				best = dist
				stuck = 0.0
			else:
				stuck += dt
				if stuck > STUCK_TIME:
					break
			await get_tree().process_frame
		if not is_inside_tree() or me != _walk_id:
			return false
	if s.has("face"):
		face_direction(s.face)
	if s.get("sit", false):
		sit()
	else:
		play_idle()
	in_room = _wing().room_at(root.global_position) if _wing() else ""
	return true

## Stays put for `seconds` (still stopping to talk), playing an animation.
func wait(seconds: float, anim := "") -> void:
	var t := 0.0
	if anim != "":
		_play(anim)
	while t < seconds and is_inside_tree():
		await get_tree().process_frame
		if not is_talking() and not is_dancing():
			t += get_process_delta_time()

## Sits (the end of "Type To Sit", held).
func sit() -> void:
	_sitting = true
	_play("sit")
	var a := _anim.get_animation("sit/mixamo_com")
	_anim.seek(a.length, true)
	_anim.pause()

func type() -> void:
	_sitting = true
	_play("type")

func _play(k: String) -> void:
	if k == "walk":
		play_walk()
	elif k == "idle":
		play_idle()
	else:
		_anim.speed_scale = 1.0
		_anim.play(k + "/mixamo_com")
		_current_anim_player = _anim

func _turn_toward(dir: Vector3, dt: float) -> void:
	var want := atan2(dir.x, dir.z) if model_faces_plus_z else atan2(-dir.x, -dir.z)
	root.rotation.y = lerp_angle(root.rotation.y, want, clampf(TURN_SPEED * dt, 0.0, 1.0))

## The office floor is flat (the navigation mesh floats 0.3 over it).
func _floor_y(_p: Vector3) -> float:
	return 0.02

func _wing() -> Node:
	return get_tree().get_first_node_in_group("office_wing") if is_inside_tree() else null

## ---------------------------------------------------------------------
## Props in hand
## ---------------------------------------------------------------------

## Something in their right hand: "papers", "folder", "mug" - or "" for nothing.
func hold(kind: String) -> void:
	if is_instance_valid(_held):
		_held.queue_free()
	_held = null
	if kind == "":
		return
	var idx := _skeleton.find_bone("mixamorig_RightHand")
	if idx < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_idx = idx
	_skeleton.add_child(att)
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	var bm := BoxMesh.new()
	match kind:
		"papers":
			bm.size = Vector3(0.22, 0.03, 0.3)
			m.albedo_color = Color(0.96, 0.96, 0.94)
		"folder":
			bm.size = Vector3(0.24, 0.04, 0.32)
			m.albedo_color = Color(0.85, 0.65, 0.3)
		"mug":
			bm.size = Vector3(0.09, 0.11, 0.09)
			m.albedo_color = Color(0.9, 0.9, 0.9)
		_:
			bm.size = Vector3(0.15, 0.15, 0.15)
			m.albedo_color = Color(0.6, 0.6, 0.6)
	mi.mesh = bm
	mi.material_override = m
	att.add_child(mi)
	# world-sized, whatever the model's scale
	mi.scale = Vector3.ONE * UNIT / maxf(root.scale.x, 0.0001)
	_held = att

## ---------------------------------------------------------------------
## Talking to the player
## ---------------------------------------------------------------------

func _on_interacted(_body: Variant) -> void:
	_talk_until = Time.get_ticks_msec() + 3500
	if not _sitting:
		play_idle()
		if PlayerManager.player:
			face_point(PlayerManager.player.global_position)
	if role == "vendor":
		_vendor_click()
		return
	var mail := OfficeJobs.deliver_mail(worker_name)
	if mail != "":
		say(mail)
		_update_marker()
		return
	var back := OfficeQuests.hand_in(worker_name)
	if back != "":
		say("%s: %s" % [worker_name, back])
		_update_marker()
		return
	var q := OfficeQuests.quest_of(worker_name)
	if not q.is_empty():
		say("%s: %s (%d coins if you find it)" % [worker_name, OfficeQuests.ask_line(q.item), q.reward])
		return
	say("%s: %s" % [worker_name, LINES.get(role, LINES.social).pick_random()])

func _vendor_click() -> void:
	var now := Time.get_ticks_msec()
	if now < _offer_until:
		_offer_until = 0.0
		if PlayerManager.coins < VENDOR_PRICE:
			say("%s: That's %d coins. You've got %d. Come back when you're richer." % [worker_name, VENDOR_PRICE, PlayerManager.coins])
			return
		PlayerManager.add_coins(-VENDOR_PRICE)
		PlayerManager.add_stamina_charge()
		AudioManager.play_sound(AudioManager.ItemPickup, -6.0)
		say("%s: Pleasure doing business. (-%d coins, +1 Stamina Charge)" % [worker_name, VENDOR_PRICE])
		return
	_offer_until = now + OFFER_TIME * 1000.0
	say("%s: Stamina charge? %d coins. Click me again to buy. (You have %d.)" % [worker_name, VENDOR_PRICE, PlayerManager.coins])
