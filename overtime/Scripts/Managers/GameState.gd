## No Exit
## Overtime Studios
## Last updated 10/18/26 by Justin Ferreira
## Game State Script (autoload)
## - The one place that knows where the player is in the story:
##     * loop      - which loop we're on (opening cutscene, loop 0, loop 1...)
##     * flags     - named milestones ("got_keys", "hotwire_done", ...)
##     * deaths
## - Moves the player between levels with change_level(), carrying their
##   facing, stamina and sprint over and placing them at a spawn marker.
##
## Old variables like PlayerManager.Loop0 / gotKeys still work - they just
## read and write through here now.
##
## ---------------------------------------------------------------------
## Spawn markers
## ---------------------------------------------------------------------
## A spawn marker is any Node3D (usually a Marker3D) in a level, put in
## the "spawn_points" group. Its node name is its id.
##   GameState.change_level("res://Levels/Office.tscn", "ElevatorSpawn")
## puts the player on the marker named ElevatorSpawn in the Office.
## Its -Z (the blue arrow) is the way the player faces - unless
## keep_facing_from is given, see change_level().

extends Node

signal loop_changed(loop: int)
signal flag_changed(flag: String, value: bool)
signal note_found(note: NoteData)
## Emitted by change_level() just before the old level goes away (things
## that hand state to the next level, like the elevator music, listen).
signal leaving_level

## Every NoteData in this folder is a note in the game.
const NOTES_DIR: String = "res://Assets/Notes"

## Not in a run (main menu, dev test levels).
const LOOP_NONE: int = -2
## The opening cutscene, before loop 0.
const LOOP_OPENING: int = -1

const SPAWN_GROUP: String = "spawn_points"

## Milestone flag names. Use these instead of typing strings, so a typo
## is an error instead of a silent bug.
const FLAG_GOT_KEYS := "got_keys"
const FLAG_GOT_BATTERY := "got_battery"
const FLAG_GOT_GAS_CANISTER := "got_gas_canister"
const FLAG_TALK_TO_JANITOR := "talk_to_janitor"
const FLAG_HOTWIRE_DONE := "hotwire_done"
const FLAG_GAS_DONE := "gas_done"
const FLAG_BATTERY_DONE := "battery_done"
const FLAG_LOOP0_STEERING_CLICKED := "loop0_steering_clicked"

var loop: int = LOOP_NONE:
	set(value):
		if value == loop:
			return
		loop = value
		loop_changed.emit(loop)

var deaths: int = 0

## How an item left the world (see mark_collected).
const PICKED_UP := "picked_up"   # put in the inventory
const STORED := "stored"         # packed into the Box on the desk
const OPENED := "opened"         # an AnimatedInteractable left open (fridge door, drawer)
const SEARCHED := "searched"     # a SearchableInteractable already searched

## flag name -> true. Only set flags are stored.
var _flags: Dictionary = {}

## item id -> PICKED_UP / STORED. Items whose id is in here remove
## themselves when their level loads. Ids are strings, never nodes, so
## nothing goes stale when a level is unloaded.
var _collected: Dictionary = {}

## Ids of notes the player has found, in the order they found them. Not
## cleared by deaths/loops (the player remembers what they read) - only by
## forget_notes(), which a new game calls.
var _found_notes: Array[String] = []
## id -> NoteData for every note in NOTES_DIR (loaded on first use).
var _notes: Dictionary = {}

## Filled by change_level(), used once by the next level's Player.
var _pending_spawn: String = ""
var _carry: Dictionary = {}
## Levels loaded ahead by preload_level() (path -> PackedScene, or true while
## its load is still waiting to run).
var _preloading: Dictionary = {}


## ---------------------------------------------------------------------
## Loop
## ---------------------------------------------------------------------

## True if the player is on loop n.
func is_loop(n: int) -> bool:
	return loop == n

## True during the opening cutscene.
func in_opening() -> bool:
	return loop == LOOP_OPENING


## ---------------------------------------------------------------------
## Flags
## ---------------------------------------------------------------------

## True if the milestone flag is set (use the FLAG_ constants).
func has_flag(flag: String) -> bool:
	return _flags.has(flag)

## Sets (or with value = false, clears) a milestone flag.
func set_flag(flag: String, value: bool = true) -> void:
	if has_flag(flag) == value:
		return
	if value:
		_flags[flag] = true
	else:
		_flags.erase(flag)
	flag_changed.emit(flag, value)

## Clears a milestone flag.
func clear_flag(flag: String) -> void:
	set_flag(flag, false)

## All flags currently set, e.g. for a debug overlay or a save file.
func get_flags() -> Array:
	return _flags.keys()

## Clears every milestone flag (a fresh run).
func clear_all_flags() -> void:
	for flag in _flags.keys():
		clear_flag(flag)


## ---------------------------------------------------------------------
## Collected items
## ---------------------------------------------------------------------
## Interactables call these with their get_persist_id(). Remembered until
## forget_collected() - PlayerManager.ResetPlayer() calls that, so a new
## loop / restart brings everything back.

## Remembers that the item with this id left the world (how = PICKED_UP, STORED, OPENED, SEARCHED).
func mark_collected(id: String, how: String = PICKED_UP) -> void:
	_collected[id] = how

## True if the item with this id was taken/used (it should remove itself).
func is_collected(id: String) -> bool:
	return _collected.has(id)

## How an id was marked (PICKED_UP, OPENED, ...), or "" if it wasn't.
func collected_how(id: String) -> String:
	return _collected.get(id, "")

## Forget one id (e.g. a door that was closed again).
func unmark_collected(id: String) -> void:
	_collected.erase(id)

## Ids of collected items, optionally only ones collected a certain way.
func get_collected(how: String = "") -> Array:
	if how == "":
		return _collected.keys()
	return _collected.keys().filter(func(id): return _collected[id] == how)

## Forgets collected items - all of them, or only those with this how.
func forget_collected(how: String = "") -> void:
	if how == "":
		_collected.clear()
		return
	for id in get_collected(how):
		_collected.erase(id)


## ---------------------------------------------------------------------
## Notes
## ---------------------------------------------------------------------

## Has the player found (read) this note? Takes the note's id.
func has_note(id: String) -> bool:
	return _found_notes.has(id)

## Marks a note as found so it shows in the journal. Returns true the
## first time.
func find_note(note: NoteData) -> bool:
	if note == null or note.id == "":
		push_warning("GameState.find_note: note has no id.")
		return false
	_load_notes()
	if not _notes.has(note.id):
		_notes[note.id] = note
	if has_note(note.id):
		return false
	_found_notes.append(note.id)
	note_found.emit(note)
	return true

## Found notes, oldest first.
func get_found_notes() -> Array[NoteData]:
	_load_notes()
	var result: Array[NoteData] = []
	for id in _found_notes:
		if _notes.has(id):
			result.append(_notes[id])
	return result

## Every note in the game, found or not (handy for debugging).
func get_all_notes() -> Array[NoteData]:
	_load_notes()
	var result: Array[NoteData] = []
	result.assign(_notes.values())
	return result

## The NoteData with this id, or null.
func get_note(id: String) -> NoteData:
	_load_notes()
	return _notes.get(id)

## Forgets every found note (a new game).
func forget_notes() -> void:
	_found_notes.clear()

func _load_notes() -> void:
	if not _notes.is_empty():
		return
	var dir := DirAccess.open(NOTES_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		# Exported games rename .tres files to .tres.remap.
		file = file.trim_suffix(".remap")
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var note := load(NOTES_DIR.path_join(file)) as NoteData
		if note == null:
			continue
		if note.id == "":
			push_warning("GameState: note %s has no id." % file)
		elif _notes.has(note.id):
			push_warning("GameState: two notes use the id '%s'." % note.id)
		else:
			_notes[note.id] = note


## ---------------------------------------------------------------------
## Moving between levels
## ---------------------------------------------------------------------

## Loads a level and puts the player at the marker named `spawn` (see the
## top of this file). Stamina, fatigue, sprint and look up/down carry over.
##
## keep_facing_from: a marker in the level being left. If given, the
## player keeps the same facing AND the same spot relative to it - e.g.
## arriving in the other elevator standing where they stood, facing the same
## way (the two markers should sit at the same place in their elevators).
## Without it the player faces the way the spawn marker faces.
func change_level(path: String, spawn: String = "", keep_facing_from: Node3D = null) -> void:
	_pending_spawn = spawn
	_carry = {}
	var player = PlayerManager.player
	if is_instance_valid(player):
		_carry = player.get_carry_state()
		if keep_facing_from:
			_carry.relative_yaw = player.get_look_yaw() - _yaw_of(keep_facing_from)
			# where they stand relative to the marker too (sideways only - the
			# elevator may have moved up or down since)
			var local: Vector3 = keep_facing_from.global_transform.affine_inverse() * player.global_position
			# height too in a cutscene (the player's physics is paused, so nothing
			# would settle them; the two markers sit at the same height in their
			# elevators), otherwise sideways only and physics lands them
			if not PlayerManager.cutscene:
				local.y = 0.0
			_carry.relative_offset = local
			# in a cutscene, the exact height above the elevator floor too (its
			# physics is paused; the two cabins' floors sit a few mm differently
			# from their markers, which physics would correct with a visible bump)
			if PlayerManager.cutscene:
				var top := _cabin_floor_top(player.global_position)
				if not is_nan(top):
					_carry.floor_offset = player.global_position.y - top
	leaving_level.emit()
	var packed = _preloading.get(path)
	_preloading.erase(path)
	if packed is PackedScene:
		get_tree().change_scene_to_packed(packed)
		return
	get_tree().change_scene_to_file(path)

## Loads a level ahead of time so the later change_level() to it is
## near-instant (the elevators call it once their doors have shut, so the
## short pause of loading happens inside the closed elevator during the ride).
## Not a background (threaded) load on purpose: in Godot 4.3 those can
## deadlock at the scene switch and freeze the game for good.
func preload_level(path: String) -> void:
	if path == "" or _preloading.has(path):
		return
	_preloading[path] = load(path) as PackedScene
	# the load paused the game: don't let the mouse moved meanwhile jerk the view
	var p = PlayerManager.player
	if is_instance_valid(p) and "_look_ready_frame" in p:
		p._look_ready_frame = Engine.get_process_frames() + 3

## Rests a character on the floor below it exactly as its own physics would
## (for when its physics is paused): the same move_and_slide step, floor
## snap and all - so nothing shifts when its physics starts again.
func settle_on_floor(body: CharacterBody3D) -> void:
	var vel := body.velocity
	for i in 2:
		body.velocity = Vector3.DOWN * 0.5
		body.move_and_slide()
	body.velocity = vel

## See place_player: waits for the floor collision, then settles the player
## onto it (only a tiny correction - never a fall).
func _settle_when_floor_ready(player: CharacterBody3D) -> void:
	for i in 3:
		await get_tree().physics_frame
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	var before := player.global_position
	settle_on_floor(player)
	if absf(player.global_position.y - before.y) > 0.05:
		player.global_position = before   # still no floor - leave it to physics

## Top of the elevator floor (an "ElevatorCollisions/FloorCollision" box) under
## a point, from its shape - works before its collision exists. NAN if none.
func _cabin_floor_top(pos: Vector3, root: Node = null) -> float:
	if root == null:
		root = get_tree().current_scene
	var best := NAN
	for f in root.find_children("FloorCollision", "", true, false):
		if not (f is VisualInstance3D):
			continue
		var b: AABB = f.global_transform * f.get_aabb()
		if pos.x < b.position.x or pos.x > b.end.x or pos.z < b.position.z or pos.z > b.end.z:
			continue
		if b.end.y > pos.y + 1.0:
			continue   # a floor above
		if is_nan(best) or b.end.y > best:
			best = b.end.y
	return best

## Forget anything loaded ahead (a new run, back to the menu).
func clear_preloads() -> void:
	_preloading.clear()

## Called by the Player when it's ready in a new level. Places it and
## restores what change_level() carried over. Does nothing if the level
## was loaded some other way.
func place_player(player) -> void:
	if not _carry.is_empty():
		player.apply_carry_state(_carry)

	if _pending_spawn != "":
		var marker := _find_spawn(player, _pending_spawn)
		if marker:
			player.global_position = marker.global_transform * _carry.get("relative_offset", Vector3.ZERO)
			if _carry.has("floor_offset"):
				var root: Node = player.owner if player.owner else player.get_parent()
				var top := _cabin_floor_top(player.global_position, root)
				if not is_nan(top):
					player.global_position.y = top + _carry.floor_offset
				# then, as soon as the elevator's floor collision exists (its CSG
				# builds it a frame later), rest them on it exactly as physics will -
				# right at the scene switch, not with a bump when control comes back
				_settle_when_floor_ready(player)
			var yaw := _yaw_of(marker)
			if _carry.has("relative_yaw"):
				yaw += _carry.relative_yaw
			player.set_look_yaw(yaw)
		else:
			push_warning("GameState: no spawn marker named '%s' (group '%s') in this level." % [_pending_spawn, SPAWN_GROUP])

	# Skinned models (the elevator, whose doors animate) only get their pose
	# a frame late, so on the level's first frame they weren't drawn and
	# you saw straight through the elevator walls. Pose them now.
	var level: Node = player.owner if player.owner else player.get_parent()
	for skel in level.find_children("*", "Skeleton3D", true, false):
		skel.force_update_all_bone_transforms()
		skel.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)

	_pending_spawn = ""
	_carry = {}

func _find_spawn(player: Node, id: String) -> Node3D:
	for node in player.get_tree().get_nodes_in_group(SPAWN_GROUP):
		if node is Node3D and node.name == id and node.is_inside_tree():
			return node
	return null

func _yaw_of(node: Node3D) -> float:
	return node.global_basis.orthonormalized().get_euler().y
