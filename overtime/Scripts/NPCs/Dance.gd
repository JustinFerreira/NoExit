## No Exit
## Overtime Studios
## Dance
## - The fire alarm easter egg: while the office lights flash red and blue
##   (FireAlarm.gd), every NPC in group "office_dancer" - the desk workers,
##   the walking office workers, Gus, the janitor - gets up and dances.
## - Each of them has a dance(seconds) method; it calls start() here, which
##   plays the walk animation in place (the legs) and puts a DanceModifier
##   on their skeleton (arms, hips, head - a random style each), and stop()
##   puts the animation back.
## - Static helpers only.

const WALK := "res://Assets/Characters/Animations/Walking.fbx"
const MOD := preload("res://Scripts/NPCs/DanceModifier.gd")
## How fast the legs step (walk animation speed).
const STEP_SPEED := 1.6

static var _lib: AnimationLibrary

## Everyone in the office starts dancing for `seconds`.
static func party(tree: SceneTree, seconds: float) -> void:
	tree.call_group("office_dancer", "dance", seconds)

## Starts `skeleton` dancing with `player` (an AnimationPlayer whose root
## sees the skeleton as "Skeleton3D"). Returns what's needed to stop().
static func start(skeleton: Skeleton3D, player: AnimationPlayer) -> Dictionary:
	var state := {
		"player": player,
		"anim": player.current_animation if player else "",
		"pos": player.current_animation_position if player and player.current_animation != "" else 0.0,
		"speed": player.speed_scale if player else 1.0,
		"playing": player.is_playing() if player else false,
	}
	if player:
		if not player.has_animation_library("dance"):
			player.add_animation_library("dance", _walk_lib())
		player.speed_scale = STEP_SPEED * randf_range(0.9, 1.1)
		player.play("dance/mixamo_com")
	var mod := MOD.new()
	mod.name = "Dance"
	mod.style = randi() % 3
	mod.speed = randf_range(0.9, 1.15)
	mod.phase = randf() * TAU
	skeleton.add_child(mod)
	state["mod"] = mod
	return state

## Stops the dance and puts the animation back as it was.
static func stop(state: Dictionary) -> void:
	if state.is_empty():
		return
	var mod = state.get("mod")
	if is_instance_valid(mod):
		mod.queue_free()
	var player: AnimationPlayer = state.get("player")
	if is_instance_valid(player):
		player.speed_scale = state.speed
		if state.anim != "" and player.has_animation(state.anim):
			player.play(state.anim)
			player.seek(state.pos, true)
			if not state.playing:
				player.pause()
		else:
			player.stop()

static func _walk_lib() -> AnimationLibrary:
	if _lib == null:
		var sc: Node = load(WALK).instantiate()
		var a: Animation = (sc.get_node("AnimationPlayer") as AnimationPlayer).get_animation("mixamo_com").duplicate()
		sc.free()
		a.loop_mode = Animation.LOOP_LINEAR
		_lib = AnimationLibrary.new()
		_lib.add_animation("mixamo_com", a)
	return _lib
