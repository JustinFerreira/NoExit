## No Exit
## Overtime Studios
## Last updated 10/19/26 by Justin Ferreira
## NPC Script
## - parent class for every NPC (the desk workers, the janitor). To make a
##   new NPC: put this script's child class on the NPC's clickable body
##   (a StaticBody3D, like any Interactable), then fill in the inspector:
##     NPC Root          - the node that moves/turns (empty = the scene root)
##     Idle/Walk Player  - AnimationPlayers to loop (empty = none)
##     Random Lines      - clicked = says one of these (empty = nothing)
##     Ambient Sounds    - sounds played now and then (typing etc.) on
##                         Ambient Player
##   Override the hooks you need:
##     _npc_ready()            - your setup (instead of _ready)
##     _on_interacted(body)    - what happens when clicked
##                               (default: say a random line)
## What you get for free:
##   root                      - the NPC's root node
##   play_idle() / play_walk() - switch animations (stops the other one, so
##                               two players never fight over the skeleton)
##   face_direction(dir) / face_point(pos) - turn (yaw only)
##   say(text) / say_random(lines) / say_sequence(lines) - dialog
##   distance_to_player()

extends Interactable
class_name NPC

@export_group("NPC")
## The node that moves and turns. Empty = this scene's root.
@export var npc_root: Node3D
## Which way the model faces: true = +Z (Mixamo), false = Godot's -Z.
@export var model_faces_plus_z: bool = true

@export_group("Animation")
@export var idle_animation_player: AnimationPlayer
@export var idle_animation: String = "mixamo_com"
@export var walk_animation_player: AnimationPlayer
@export var walk_animation: String = "mixamo_com"
## Start the idle animation automatically.
@export var idle_on_ready: bool = true

@export_group("Talking")
## Clicking the NPC says one of these at random (used by the default
## _on_interacted). Empty = says nothing.
@export var random_lines: Array[String] = []

@export_group("Ambient Sounds")
## Plays one of Ambient Sounds every few seconds (typing, coughing...).
@export var ambient_player: AudioStreamPlayer3D
@export var ambient_sounds: Array[AudioStream] = []
@export var ambient_min_interval: float = 1.0
@export var ambient_max_interval: float = 20.0

var root: Node3D
var _current_anim_player: AnimationPlayer
var _ambient_timer: Timer

func _ready() -> void:
	super._ready()
	root = npc_root if npc_root else _find_root()
	for p in [idle_animation_player, walk_animation_player]:
		if p and not p.animation_finished.is_connected(_on_npc_animation_finished):
			p.animation_finished.connect(_on_npc_animation_finished)
	if idle_on_ready:
		play_idle()
	if ambient_player and not ambient_sounds.is_empty():
		_ambient_timer = Timer.new()
		_ambient_timer.one_shot = true
		_ambient_timer.timeout.connect(_play_ambient)
		add_child(_ambient_timer)
		_schedule_ambient()
	_npc_ready()

## Hook - your setup.
func _npc_ready() -> void:
	pass

## No NPC Root set: the nearest node above this one that holds the
## character's Skeleton3D (works whether the NPC is a placed scene or was
## flattened into a level), else this scene's root.
func _find_root() -> Node3D:
	var n := get_parent()
	while n and n != get_tree().current_scene:
		for c in n.get_children():
			if c is Skeleton3D:
				return n as Node3D
		n = n.get_parent()
	return owner as Node3D if owner is Node3D else get_parent() as Node3D

## Default click: say a random line (if any are set).
func _on_interacted(_body: Variant) -> void:
	if not random_lines.is_empty():
		say_random(random_lines)

## ---------------------------------------------------------------------
## Animation
## ---------------------------------------------------------------------

func play_idle(speed_scale: float = 1.0) -> void:
	_play_on(idle_animation_player, idle_animation, speed_scale)

func play_walk(speed_scale: float = 1.0) -> void:
	_play_on(walk_animation_player, walk_animation, speed_scale)

func _play_on(p: AnimationPlayer, anim: String, speed_scale: float) -> void:
	if p == null:
		return
	if _current_anim_player and _current_anim_player != p and _current_anim_player.is_playing():
		_current_anim_player.stop()
	_current_anim_player = p
	p.speed_scale = speed_scale
	if p.current_animation != anim or not p.is_playing():
		p.play(anim)

## Keeps the current animation looping even if it wasn't imported as a loop.
func _on_npc_animation_finished(_anim_name: StringName) -> void:
	if _current_anim_player and not _current_anim_player.is_playing():
		_current_anim_player.play(_current_anim_player.assigned_animation)

func is_walking() -> bool:
	return _current_anim_player != null and _current_anim_player == walk_animation_player and walk_animation_player != idle_animation_player

## ---------------------------------------------------------------------
## Turning
## ---------------------------------------------------------------------

## Turn the NPC to face a world direction (yaw only - never tilts).
func face_direction(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if root == null or flat.length_squared() < 0.000001:
		return
	flat = flat.normalized()
	root.look_at(root.global_position + (-flat if model_faces_plus_z else flat), Vector3.UP)

func face_point(point: Vector3) -> void:
	if root:
		face_direction(point - root.global_position)

## The yaw (radians) that would make the NPC face a point.
func yaw_towards(point: Vector3) -> float:
	var d := point - root.global_position
	return atan2(d.x, d.z) if model_faces_plus_z else atan2(-d.x, -d.z)

func distance_to_player() -> float:
	if root == null or PlayerManager.player == null:
		return INF
	return root.global_position.distance_to(PlayerManager.player.global_position)

## ---------------------------------------------------------------------
## Talking
## ---------------------------------------------------------------------

## One line of dialog.
func say(text: String) -> void:
	PlayerManager.CharacterDialog(text)

## One random line from a list.
func say_random(lines: Array) -> void:
	if not lines.is_empty():
		say(lines[randi() % lines.size()])

## Several lines in a row (the player clicks through). Await it to wait
## until the player has read them all.
func say_sequence(lines: Array) -> void:
	PlayerManager.MultiDialog(lines)
	while PlayerManager.multiDialog:
		await get_tree().create_timer(0.1).timeout

## ---------------------------------------------------------------------
## Ambient sounds
## ---------------------------------------------------------------------

func _schedule_ambient() -> void:
	_ambient_timer.start(randf_range(ambient_min_interval, ambient_max_interval))

func _play_ambient() -> void:
	if not is_inside_tree() or ambient_sounds.is_empty():
		return
	ambient_player.stream = ambient_sounds[randi() % ambient_sounds.size()]
	ambient_player.play()
	_schedule_ambient()
