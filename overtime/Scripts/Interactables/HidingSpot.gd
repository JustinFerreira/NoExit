## No Exit
## Overtime Studios
## Last updated 11/15/26 by Justin Ferreira
## Hiding Spot
## - Click it and the player ducks into the spot (under a desk, in a
##   locker, behind boxes): the view moves smoothly to hide_point, and the
##   player's collision and enemy kill trigger are switched off - while
##   hidden, the player effectively IS the hiding spot.
## - While hidden the player can look around (within look limits) but not
##   move. Pressing any movement key climbs back out to exactly where they
##   clicked from, with the same smooth move in reverse.
## - Enemies can't see a hidden player (Enemy.can_see_player).
##
## Setup:
##   HidingSpot (StaticBody3D, this script) with a CollisionShape3D over the
##   spot's opening, so clicking the opening hides you.
##     ├ HidePoint (Marker3D)   where the eyes end up; looks along its -Z
##     └ EntryPoint (Marker3D)  optional: the eyes pass through here on the way
##                              in and out (e.g. crouched just in front of the
##                              opening), so the view doesn't clip through
##                              the furniture.
##   For an outline, give it a mesh (e.g. an invisible quad over the opening).

extends Interactable
class_name HidingSpot

## Emitted once the player is fully hidden.
signal player_hidden
## Emitted once the player is fully back out.
signal player_unhidden

@export_group("Points")
## Where the player's eyes go. They look along this node's -Z (blue arrow
## pointing back = facing out of the hiding spot).
@export var hide_point: Node3D
## Optional point the eyes pass through on the way in and out.
@export var entry_point: Node3D

@export_group("Movement")
## Seconds to get into the spot.
@export var enter_time: float = 0.9
## Seconds to get back out.
@export var exit_time: float = 0.8
## How far (degrees) the player can look left/right while hidden.
@export var look_yaw_limit: float = 70.0
## How far (degrees) the player can look up / down while hidden.
@export var look_up_limit: float = 25.0
@export var look_down_limit: float = 40.0

@export_group("Sounds")
## Played when ducking in. Empty = no sound.
@export var hide_sound: AudioStream
## Played when climbing out. Empty = no sound.
@export var unhide_sound: AudioStream

@export_group("Peeking")
## Q / E: stick your head out of the spot and look along the outside to the
## left / right. How far (units) the head comes out towards the opening.
@export var peek_out_distance: float = 0.6
## How far the head also shifts to that side.
@export var peek_side_distance: float = 0.15
## How far the head also rises (e.g. to see past a chair in front of a desk).
@export var peek_up_distance: float = 0.0
## How far (degrees) the view turns to look along the outside. Negative turns
## back toward the middle instead (e.g. under a desk in a cubicle, to look out
## of the cubicle's opening rather than at its side walls).
@export var peek_turn_degrees: float = 60.0
## How quickly the peek eases in and out (higher = snappier).
@export var peek_speed: float = 4.0
## While the head is out, enemies can see the player. One that does gets the
## same catch chance as seeing them hide (Enemy.catch_seen_hiding_chance),
## once per peek.
@export var peeking_exposes: bool = true

@export_group("Getting Caught")
## Seconds an enemy takes to drag the player out of the spot.
@export var drag_out_time: float = 0.75
## How hard the view shakes while being dragged out (degrees).
@export var drag_shake_degrees: float = 7.0
## How far out from the opening (past the EntryPoint) an enemy stands, square
## to the opening, before it reaches in to drag the player out.
@export var grab_distance: float = 0.85

@export_group("Enemies")
## Enemies can't see the player while they're hidden here. An enemy that
## saw them get in may still come for them (Enemy.catch_seen_hiding_chance);
## the others lose track.
@export var hides_from_enemies: bool = true

enum State { IDLE, ENTERING, HIDDEN, EXITING }
var state: State = State.IDLE
## -1 = peeking fully left, 1 = fully right (eased)
var _peek := 0.0
var _hidden_eye := Vector3.ZERO
var _hidden_yaw := 0.0
var _peek_center := 0.0             # where the view is centred (turns with the peek)
var _exposed := false
var _peek_check := 0.0
var _seen_this_peek: Array = []     # enemies that already rolled during this peek
var _shake := 0.0                    # view shake (radians) during the current move

var _player: CharacterBody3D
var _head: Node3D
var _camera: Camera3D
var _saved: Dictionary = {}
var _tween: Tween
## the move currently playing: eyes go a -> b -> c, view yaw/pitch ease from -> to
var _path: Array = []
var _yaw_from := 0.0
var _yaw_to := 0.0
var _pitch_from := 0.0
var _pitch_to := 0.0


func _ready() -> void:
	super._ready()
	if hide_point == null:
		hide_point = get_node_or_null("HidePoint")
	if entry_point == null:
		entry_point = get_node_or_null("EntryPoint")
	if hide_point == null:
		push_warning("%s: HidingSpot has no hide_point." % name)


## Where the player stood when they got in (enemies that didn't see them
## search here).
func hidden_from_position() -> Vector3:
	return _saved.get("position", global_position)

## Where an enemy stands to drag the player out (in front of the opening).
func approach_position() -> Vector3:
	var p := entry_point.global_position if entry_point else hide_point.global_position
	var ground: Vector3 = _saved.get("position", p)
	return Vector3(p.x, ground.y, p.z)

## Which way the opening faces (flat, out of the spot).
func out_direction() -> Vector3:
	var out := approach_position() - hide_point.global_position
	out.y = 0.0
	if out.length_squared() < 0.0001:
		out = -hide_point.global_basis.z
		out.y = 0.0
	return out.normalized() if out.length_squared() > 0.0001 else Vector3.FORWARD

## Where an enemy lines up before reaching in to drag the player out:
## grab_distance out from the opening, square to it.
func grab_position() -> Vector3:
	return approach_position() + out_direction() * grab_distance

## An enemy has found the player: they're yanked out of the opening (with a
## shake) and pulled up onto their feet in front of the spot, facing the
## enemy - then the enemy's kill() runs.
func drag_out(enemy: Node3D) -> void:
	if state == State.IDLE or not is_instance_valid(_player):
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	state = State.EXITING
	PlayerManager.InAnimation = true
	PlayerManager.hidden_from_enemies = true
	# end up on your feet just outside the opening, pulled a little towards the
	# enemy (never closer to it than 0.6 m) - Enemy.kill() then steps it to its
	# kill distance
	var stand := approach_position()
	var flat := Vector3(stand.x - enemy.global_position.x, 0.0, stand.z - enemy.global_position.z)
	if flat.length() > 0.05:
		var gap := maxf(flat.length() - 0.15, 0.6)
		stand = Vector3(enemy.global_position.x, stand.y, enemy.global_position.z) + flat.normalized() * gap
	var eye_height: float = _saved.eye.y - _saved.position.y
	var start_eye := _camera.global_position
	var out_eye := entry_point.global_position if entry_point else start_eye.lerp(stand, 0.5)
	_path = [start_eye, out_eye, stand + Vector3.UP * eye_height]
	var to_enemy := enemy.global_position - stand
	_yaw_from = _player.rotation.y + _head.rotation.y
	_yaw_to = atan2(-to_enemy.x, -to_enemy.z)
	_pitch_from = _camera.rotation.x
	_pitch_to = deg_to_rad(5.0)
	_shake = deg_to_rad(drag_shake_degrees)
	if enemy.has_method("play_drag_out"):
		enemy.play_drag_out(drag_out_time)
	_run(drag_out_time, _finish_drag.bind(enemy))


func _finish_drag(enemy: Node3D) -> void:
	_shake = 0.0
	_camera.rotation.z = 0.0
	_player.velocity = Vector3.ZERO
	_peek = 0.0
	_set_player_collision(true)
	set_outline_blocked(false)
	_clear_flags()
	state = State.IDLE
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.has_method("player_unhid"):
			e.player_unhid()
	player_unhidden.emit()
	if is_instance_valid(enemy) and enemy.has_method("kill"):
		enemy.kill()


## Pulls the player straight out (no animation), back where they hid from.
func force_out() -> void:
	if state == State.IDLE:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_finish_exit()


func _on_interacted(_body: Variant) -> void:
	if state != State.IDLE or hide_point == null:
		return
	var player := PlayerManager.player as CharacterBody3D
	if not is_instance_valid(player) or PlayerManager.InAnimation or PlayerManager.hiding:
		return
	_enter(player)


## ---------------------------------------------------------------------
## Going in
## ---------------------------------------------------------------------

func _enter(player: CharacterBody3D) -> void:
	_player = player
	_head = player.get_node("Head")
	_camera = player.CAMERA
	_saved = {
		"position": player.global_position,
		"yaw": player.rotation.y,
		"head_yaw": _head.rotation.y,
		"pitch": _camera.rotation.x,
		"eye": _camera.global_position,
	}
	state = State.ENTERING
	# Which enemies see the player duck in (checked before they're hidden).
	var watchers := {}
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.has_method("player_hid"):
			watchers[e] = e.has_method("can_see_player") and e.can_see_player()
	PlayerManager.InAnimation = true   # no looking/moving during the move
	PlayerManager.hiding = true
	PlayerManager.hidden_from_enemies = hides_from_enemies
	PlayerManager.current_hiding_spot = self
	if hides_from_enemies:
		for e in watchers:
			e.player_hid(self, watchers[e])
	_set_player_collision(false)
	UiManager.set_cursor_hover(false)
	if is_instance_valid(player.last_collider):
		player.last_collider.hide_outline()
	player.last_collider = null
	# no outline on the spot itself while the player is inside it
	set_outline_blocked(true)
	if hide_sound:
		AudioManager.play_sound(hide_sound)

	var start_eye: Vector3 = _saved.eye
	var end_eye := hide_point.global_position
	var mid := entry_point.global_position if entry_point else start_eye.lerp(end_eye, 0.5)
	_path = [start_eye, mid, end_eye]
	_yaw_from = _saved.yaw + _saved.head_yaw
	_yaw_to = _facing_yaw(hide_point)
	_pitch_from = _saved.pitch
	_pitch_to = 0.0
	_run(enter_time, _finish_enter)


func _finish_enter() -> void:
	state = State.HIDDEN
	_peek = 0.0
	_hidden_eye = _camera.global_position
	_hidden_yaw = _view_yaw()   # world yaw looking out of the spot
	_peek_center = _hidden_yaw
	_exposed = false
	_seen_this_peek.clear()
	PlayerManager.InAnimation = false   # looking around is allowed now
	player_hidden.emit()


## ---------------------------------------------------------------------
## While hidden
## ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if state != State.HIDDEN or not is_instance_valid(_player):
		return
	# keep the view inside the look limits (body faces out of the spot)
	# keep the view inside the look limits, around where the spot (or the peek) faces
	var off := wrapf(_view_yaw() - _view_center(), -PI, PI)
	off = clampf(off, -deg_to_rad(look_yaw_limit), deg_to_rad(look_yaw_limit))
	_set_view_yaw(_view_center() + off)
	_camera.rotation.x = clampf(_camera.rotation.x, -deg_to_rad(look_down_limit), deg_to_rad(look_up_limit))
	if UiManager.any_screen_open():
		return
	_update_peek(delta)
	for action in ["forward", "backward", "left", "right"]:
		if Input.is_action_pressed(action):
			unhide()
			return


## Q / E: the head comes out of the spot to the opening and the view turns
## to look along the outside, left or right. Letting go ducks back in.
## While the head is out the player can be seen (peeking_exposes).
func _update_peek(delta: float) -> void:
	var want := Input.get_axis("lean_left", "lean_right")
	_peek = move_toward(_peek, want, delta * peek_speed)
	var eased := signf(_peek) * smoothstep(0.0, 1.0, absf(_peek))
	var amount := absf(eased)
	var out := -hide_point.global_basis.z
	out.y = 0.0
	out = out.normalized()
	var right := hide_point.global_basis.x
	right.y = 0.0
	right = right.normalized()
	# turn with the peek, keeping whatever extra look the mouse added
	var look_off := wrapf(_view_yaw() - _peek_center, -PI, PI)
	_peek_center = _hidden_yaw - deg_to_rad(peek_turn_degrees) * eased
	_set_view_yaw(_peek_center + look_off)
	var eye := _hidden_eye + out * peek_out_distance * amount + right * peek_side_distance * eased + Vector3.UP * peek_up_distance * amount
	_player.global_position += eye - _camera.global_position
	_camera.rotation.z = 0.0
	_update_exposure(delta, amount)


## While the head is out, enemies can see the player; each one that does
## rolls its catch chance once per peek, as if it saw them hide.
func _update_exposure(delta: float, amount: float) -> void:
	var exposed := peeking_exposes and amount > 0.5
	if exposed != _exposed:
		_exposed = exposed
		PlayerManager.hidden_from_enemies = hides_from_enemies and not exposed
	if amount < 0.05:
		_seen_this_peek.clear()
	if not exposed:
		return
	_peek_check -= delta
	if _peek_check > 0.0:
		return
	_peek_check = 0.15
	for e in get_tree().get_nodes_in_group("enemy"):
		if e in _seen_this_peek or not e.has_method("player_hid") or not e.has_method("can_see_player"):
			continue
		if e.can_see_player():
			_seen_this_peek.append(e)
			e.player_hid(self, true)


## ---------------------------------------------------------------------
## Coming out
## ---------------------------------------------------------------------

## Climbs back out to where the player clicked from. Safe to call from other
## scripts too (e.g. an enemy finding the spot).
func unhide() -> void:
	if state != State.HIDDEN:
		return
	state = State.EXITING
	PlayerManager.InAnimation = true
	if unhide_sound:
		AudioManager.play_sound(unhide_sound)
	var start_eye := _camera.global_position
	var mid := entry_point.global_position if entry_point else start_eye.lerp(_saved.eye, 0.5)
	_path = [start_eye, mid, _saved.eye]
	_yaw_from = _player.rotation.y + _head.rotation.y
	_yaw_to = _saved.yaw + _saved.head_yaw
	_pitch_from = _camera.rotation.x
	_pitch_to = _saved.pitch
	_run(exit_time, _finish_exit)


func _finish_exit() -> void:
	# exactly where they were, facing exactly the same way
	_player.global_position = _saved.position
	_player.rotation.y = _saved.yaw
	_head.rotation.y = _saved.head_yaw
	_camera.rotation.x = _saved.pitch
	_player.velocity = Vector3.ZERO
	_camera.rotation.z = 0.0
	_peek = 0.0
	set_outline_blocked(false)
	_set_player_collision(true)
	_clear_flags()
	state = State.IDLE
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.has_method("player_unhid"):
			e.player_unhid()
	player_unhidden.emit()


## ---------------------------------------------------------------------
## The move itself
## ---------------------------------------------------------------------

func _run(time: float, done: Callable) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_apply(0.0)
	_tween = create_tween()
	_tween.tween_method(_apply, 0.0, 1.0, maxf(time, 0.01))
	_tween.tween_callback(done)


## t = 0..1 along the move: eyes go a -> b, then b -> c; the view turns and
## levels out along the way.
func _apply(t: float) -> void:
	if not is_instance_valid(_player):
		return
	var split := 0.5
	var eye: Vector3
	if t < split:
		eye = _path[0].lerp(_path[1], smoothstep(0.0, 1.0, t / split))
	else:
		eye = _path[1].lerp(_path[2], smoothstep(0.0, 1.0, (t - split) / (1.0 - split)))
	var turn := smoothstep(0.0, 1.0, minf(t / 0.7, 1.0))
	_set_view_yaw(lerp_angle(_yaw_from, _yaw_to, turn))
	_head.rotation.x = 0.0
	_head.rotation.z = 0.0
	_head.position.x = 0.0
	_head.position.z = 0.0
	_camera.rotation.x = lerpf(_pitch_from, _pitch_to, turn)
	# view shake (only while being dragged out), dying down towards the end
	_camera.rotation.z = sin(t * 52.0) * _shake * (1.0 - t)
	_camera.rotation.x += sin(t * 37.0 + 1.3) * _shake * 0.5 * (1.0 - t)
	# move the whole body so the eyes land on `eye`
	_player.global_position += eye - _camera.global_position


## The view's world yaw. Only the head turns (the body keeps the yaw it had
## when the player clicked), like normal mouse look - other systems, such as
## an enemy's kill turn, rely on that.
func _view_yaw() -> float:
	return _player.rotation.y + _head.rotation.y

func _set_view_yaw(yaw: float) -> void:
	_player.rotation.y = _saved.yaw
	_head.rotation.y = wrapf(yaw - _saved.yaw, -PI, PI)

func _view_center() -> float:
	return _peek_center


## The yaw that looks along a node's -Z.
func _facing_yaw(n: Node3D) -> float:
	var f := -n.global_basis.z
	return atan2(-f.x, -f.z)


## While hidden the player has no body: no collision, no enemy kill trigger.
func _set_player_collision(on: bool) -> void:
	if not is_instance_valid(_player):
		return
	var body_shape: CollisionShape3D = _player.COLLISIONSHAPE3D
	if body_shape:
		body_shape.set_deferred("disabled", not on)
	var trigger := _player.get_node_or_null("Player") as Area3D
	if trigger:
		trigger.set_deferred("monitoring", on)
		trigger.set_deferred("monitorable", on)


func _clear_flags() -> void:
	PlayerManager.InAnimation = false
	PlayerManager.hiding = false
	PlayerManager.hidden_from_enemies = false
	if PlayerManager.current_hiding_spot == self:
		PlayerManager.current_hiding_spot = null


func _exit_tree() -> void:
	super._exit_tree()
	# level unloaded mid-hide: don't leave the player stuck without a body
	if state != State.IDLE:
		if _tween and _tween.is_valid():
			_tween.kill()
		_set_player_collision(true)
		_clear_flags()
		state = State.IDLE
		set_outline_blocked(false)
