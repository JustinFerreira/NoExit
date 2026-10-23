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

# flag name -> true. Only set flags are stored.
var _flags: Dictionary = {}

# item id -> PICKED_UP / STORED. Items whose id is in here remove
# themselves when their level loads. Ids are strings, never nodes, so
# nothing goes stale when a level is unloaded.
var _collected: Dictionary = {}

# Ids of notes the player has found, in the order they found them. Not
# cleared by deaths/loops (the player remembers what they read) - only by
# forget_notes(), which a new game calls.
var _found_notes: Array[String] = []
# id -> NoteData for every note in NOTES_DIR (loaded on first use).
var _notes: Dictionary = {}

# Filled by change_level(), used once by the next level's Player.
var _pending_spawn: String = ""
var _carry: Dictionary = {}


## ---------------------------------------------------------------------
## Loop
## ---------------------------------------------------------------------

func is_loop(n: int) -> bool:
	return loop == n

func in_opening() -> bool:
	return loop == LOOP_OPENING


## ---------------------------------------------------------------------
## Flags
## ---------------------------------------------------------------------

func has_flag(flag: String) -> bool:
	return _flags.has(flag)

func set_flag(flag: String, value: bool = true) -> void:
	if has_flag(flag) == value:
		return
	if value:
		_flags[flag] = true
	else:
		_flags.erase(flag)
	flag_changed.emit(flag, value)

func clear_flag(flag: String) -> void:
	set_flag(flag, false)

## All flags currently set, e.g. for a debug overlay or a save file.
func get_flags() -> Array:
	return _flags.keys()

func clear_all_flags() -> void:
	for flag in _flags.keys():
		clear_flag(flag)


## ---------------------------------------------------------------------
## Collected items
## ---------------------------------------------------------------------
## Interactables call these with their get_persist_id(). Remembered until
## forget_collected() - PlayerManager.ResetPlayer() calls that, so a new
## loop / restart brings everything back.

func mark_collected(id: String, how: String = PICKED_UP) -> void:
	_collected[id] = how

func is_collected(id: String) -> bool:
	return _collected.has(id)

## Ids of collected items, optionally only ones collected a certain way.
func get_collected(how: String = "") -> Array:
	if how == "":
		return _collected.keys()
	return _collected.keys().filter(func(id): return _collected[id] == how)

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

func get_note(id: String) -> NoteData:
	_load_notes()
	return _notes.get(id)

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
## player keeps the same facing relative to it - e.g. stepping out of an
## elevator facing the same way relative to the elevator as they went in.
## Without it the player faces the way the spawn marker faces.
func change_level(path: String, spawn: String = "", keep_facing_from: Node3D = null) -> void:
	_pending_spawn = spawn
	_carry = {}
	var player = PlayerManager.player
	if is_instance_valid(player):
		_carry = player.get_carry_state()
		if keep_facing_from:
			_carry.relative_yaw = player.get_look_yaw() - _yaw_of(keep_facing_from)
	get_tree().change_scene_to_file(path)

## Called by the Player when it's ready in a new level. Places it and
## restores what change_level() carried over. Does nothing if the level
## was loaded some other way.
func place_player(player) -> void:
	if not _carry.is_empty():
		player.apply_carry_state(_carry)

	if _pending_spawn != "":
		var marker := _find_spawn(player, _pending_spawn)
		if marker:
			player.global_position = marker.global_position
			var yaw := _yaw_of(marker)
			if _carry.has("relative_yaw"):
				yaw += _carry.relative_yaw
			player.set_look_yaw(yaw)
		else:
			push_warning("GameState: no spawn marker named '%s' (group '%s') in this level." % [_pending_spawn, SPAWN_GROUP])

	_pending_spawn = ""
	_carry = {}

func _find_spawn(player: Node, id: String) -> Node3D:
	for node in player.get_tree().get_nodes_in_group(SPAWN_GROUP):
		if node is Node3D and node.name == id and node.is_inside_tree():
			return node
	return null

func _yaw_of(node: Node3D) -> float:
	return node.global_basis.orthonormalized().get_euler().y
