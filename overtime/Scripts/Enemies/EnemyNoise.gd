## No Exit
## Overtime Studios
## Enemy Noise
## - Things enemies can hear: EnemyNoise.make(tree, at, loudness) tells every
##   enemy within earshot (enemy.hear(at, by_player)). `loudness` is how far
##   (garage units) it carries with nothing in the way; through floors and
##   walls it's cut down the same way the key fob is (SoundReach) - fully
##   blocked, it isn't heard at all.
## - Made by: the key fob, a car alarm, a light breaking, a pipe falling, the
##   payphone, a bear trap snapping shut, and (rogue mode) the player's own
##   footsteps (RogueRun - louder sprinting, near silent crouched).
## - Static helper, nothing to place.

const SoundReach = preload("res://Scripts/Audio/SoundReach.gd")

## How loud the usual noises are (garage units they carry in the open).
const KEY_FOB := 70.0
const CAR_ALARM := 80.0
const PIPE_FALL := 60.0
const BEAR_TRAP := 50.0
const LIGHT_BREAK := 45.0
const PAYPHONE := 40.0
const STEP_SPRINT := 36.0
const STEP_WALK := 16.0
const STEP_CROUCH := 4.0

static func make(tree: SceneTree, at: Vector3, loudness: float, by_player := false) -> void:
	if tree == null:
		return
	for e in tree.get_nodes_in_group("enemy"):
		if not e.has_method("hear") or not (e is Node3D) or not e.is_inside_tree():
			continue
		var ears: Vector3 = e.global_position + Vector3.UP * 1.6
		var d := at.distance_to(ears)
		if d > loudness:
			continue
		var db := SoundReach.floor_offset_db(e.get_world_3d(), at, ears, [e.get_rid()], e.global_position.y)
		if db <= SoundReach.BLOCKED_DB:
			continue
		# muffled by floors / walls: it carries less far
		if d <= loudness * db_to_linear(db):
			e.hear(at, by_player)
