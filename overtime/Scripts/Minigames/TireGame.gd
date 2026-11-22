## No Exit
## Overtime Studios
## Tire Game
## - The spare tire minigame (opened from FlatTire), played on the car itself:
##   the camera moves in on the flat wheel and you
##     1. Jack it up   - click again and again; the car lifts with each pump
##     2. Loosen nuts  - circle the mouse round the wheel anti-clockwise
##                       (follow the arrow); each of the 4 lug nuts (Nut models)
##                       spins out of the hub and drops off
##     3. Pull the flat - click: the flat slides off the car
##     4. Fit the spare - click: the spare slides onto the hub
##     5. Tighten nuts - circle clockwise; the nuts spin back in
##   then the jack lets the car down. Esc stops - and keeps your progress
##   (car still jacked, nuts that are off stay off) for next time.
## - Outlines: the wheel isn't outlined while you work on it; only the lug nut
##   to turn right now is (none while jacking). Opening it, the player says the
##   car needs jacking up - the first pump also clears that line.
## - Gets harder in later rogue rounds: more pumps, more turns per nut.

extends Node

## true = the tire was changed, false = the player gave up / was caught.
signal finished(success: bool)

const NUT_SCENE := preload("res://Assets/Environments/Garage/Nut/Nut.tscn")

## The car (lifted by the jack) and its flat wheel.
var car: Node3D
var wheel: MeshInstance3D
## The wheel's round shape and place (FlatTire squashed it).
var wheel_round_xf: Transform3D
## Progress kept between tries (FlatTire owns it): stopping with Esc saves
## where you got to here - the car stays jacked, nuts that are off stay off -
## and opening the minigame again carries on from there. Empty = fresh start.
var state: Dictionary = {}

## How high the jack lifts the car (garage units).
@export var lift_height := 0.3
## Lug nut ring on the wheel, in the wheel mesh's own units: distance from
## the centre, how far out from the middle of the tire the nuts sit, size.
@export var nut_ring_radius := 8.5
@export var nut_face_offset := 9.0
@export var nut_scale := 1.6
## How far the flat / spare slides out when it comes off (garage units).
@export var pull_distance := 1.1

enum Step { JACK, LOOSEN, PULL_FLAT, FIT_SPARE, TIGHTEN, DONE }
var step: int = Step.JACK

var _pumps := 0
var _pumps_needed := 6
var _turns_needed := 1.5
var _nut := 0
var _nut_turns := 0.0
var _nuts: Array[Node3D] = []
var _nut_home: Array[Transform3D] = []     # seated on the hub, car-local
var _nut_home_flat: Array[Transform3D] = []  # on the flat's (squashed, lower) hub
var _last_angle := 0.0
var _have_angle := false   # _last_angle is set (reset in the dead zone)
## Pixels around the wheel's centre where circling doesn't count.
const TURN_DEAD_ZONE := 30.0
var _car_start_y := 0.0
var _out := Vector3.RIGHT                  # world direction out of the wheel
var _spare: MeshInstance3D
var _busy := false                         # an animation is playing

var _camera: Camera3D
var _ui: CanvasLayer
## The car's other clickable parts (doors, hood...) - their outlines are
## hidden while working on the wheel, and put back after.
var _hushed: Array[Interactable] = []
## Outline helpers on the lug nuts (see _outline_current_nut).
var _nut_outlines: Array[Interactable] = []
## The line said when the minigame opens (cleared by the first pump).
const JACK_LINE := "It's sitting too low - I need to jack the car up first."
var _overlay: Control
var _label: Label

func _ready() -> void:
	var fresh := state.is_empty()
	if fresh:
		var r: int = maxi(RogueRun.round_number, 1)
		_pumps_needed = 6 + r
		_turns_needed = minf(1.0 + 0.15 * (r - 1), 2.0)
		_car_start_y = car.global_position.y
	else:
		_restore()
	var side := wheel_round_xf.origin - car.global_position
	_out = car.global_basis.x.normalized() * signf(car.global_basis.x.dot(side))
	_make_camera()
	if fresh:
		_make_nuts()
	_make_ui()
	PlayerManager.MiniGameModeOn()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_text()
	# nothing else on the car outlined while working on the wheel
	for n in car.find_children("*", "", true, false):
		if n is Interactable and n.has_outline and not n._outline_blocked and not _nut_outlines.has(n):
			n.set_outline_blocked(true)
			_hushed.append(n)
	# what to do first, said out loud (the first pump also clears it)
	if step == Step.JACK and _pumps == 0:
		PlayerManager.CharacterDialog(JACK_LINE)

## ---------------------------------------------------------------------
## Setup
## ---------------------------------------------------------------------

func _wheel_center() -> Vector3:
	return wheel_round_xf * wheel.get_aabb().get_center()

func _make_camera() -> void:
	_camera = Camera3D.new()
	_camera.near = 0.01
	car.get_parent().add_child(_camera)
	var c := _wheel_center()
	_camera.global_position = c + _out * 1.8 + Vector3.UP * 0.25
	_camera.look_at(c)
	_camera.current = true

## Four lug nuts seated on the hub, children of the car so they lift with it.
func _make_nuts() -> void:
	var local_out := (wheel_round_xf.basis.inverse() * _out).normalized()
	var sign_x := signf(local_out.x) if absf(local_out.x) > 0.01 else 1.0
	var center := wheel.get_aabb().get_center()
	# the nut model's axis is its Y: turn it to point along the wheel's axle
	var nut_basis := Basis(Vector3.BACK, -PI / 2.0 * sign_x).scaled(Vector3.ONE * nut_scale)
	for i in 4:
		var a := deg_to_rad(45.0 + 90.0 * i)
		var local := Transform3D(nut_basis, center + Vector3(nut_face_offset * sign_x, cos(a) * nut_ring_radius, sin(a) * nut_ring_radius))
		var nut: Node3D = NUT_SCENE.instantiate()
		car.add_child(nut)
		nut.global_transform = wheel_round_xf * local
		_nut_home.append(nut.transform)
		# while the flat is on, on its hub - it's squashed and sits lower
		# than the round wheel (same turn and size, just moved)
		nut.global_position = (wheel.global_transform * local).origin
		_nut_home_flat.append(nut.transform)
		_nuts.append(nut)
		# an outline for it - shown only while it's the one to turn (no
		# collision: it's never clicked, just highlighted)
		var ol := StaticBody3D.new()
		ol.name = "NutOutline"
		ol.set_script(load("res://Scripts/Interactables/Interactable.gd"))
		ol.has_outline = true
		ol.mesh = nut.get_node("MeshInstance3D")
		ol.is_interactable = false
		nut.add_child(ol)
		_nut_outlines.append(ol)

func _make_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 45
	add_child(_ui)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.draw.connect(_draw_overlay)
	_overlay.gui_input.connect(_on_gui_input)
	_ui.add_child(_overlay)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_label.offset_top = 24
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", UiManager.ACCENT_TEXT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_label)
	var tip := Label.new()
	tip.text = "Esc - stop"
	tip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tip.offset_top = -40
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 12)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(tip)

## ---------------------------------------------------------------------
## Input
## ---------------------------------------------------------------------

func _process(_delta: float) -> void:
	if PlayerManager.dying:
		_close(false)
		return
	_overlay.queue_redraw()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _busy:
			return   # let the flat / spare finish sliding first
		_close(false)

func _on_gui_input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_click()
		_have_angle = false
	# just circle the mouse round the wheel - no need to hold the button
	elif event is InputEventMouseMotion and (step == Step.LOOSEN or step == Step.TIGHTEN):
		_turn(event.position)

func _click() -> void:
	match step:
		Step.JACK:
			if _pumps == 0:
				PlayerManager.HideDialog()   # the first pump clears the "jack it up" line
			_pumps += 1
			AudioManager.play_sound(AudioManager.GetSocket(), -14)
			car.global_position.y = _car_start_y + lift_height * float(_pumps) / _pumps_needed
			if _pumps >= _pumps_needed:
				step = Step.LOOSEN
		Step.PULL_FLAT:
			_pull_flat()
		Step.FIT_SPARE:
			_fit_spare()
	_update_text()

## Circling the mouse around the wheel turns the current nut: anti-clockwise
## loosens it (it spins out of the hub), clockwise tightens it (spins in).
func _turn(pos: Vector2) -> void:
	# right in the middle the angle swings wildly - ignore it there
	if pos.distance_to(_wheel_screen_center()) < TURN_DEAD_ZONE:
		_have_angle = false
		return
	var a := _angle_at(pos)
	if not _have_angle:
		_last_angle = a
		_have_angle = true
		return
	var d := wrapf(a - _last_angle, -PI, PI)
	_last_angle = a
	# a jump (the mouse flicked across the wheel) isn't a turn
	if absf(d) > PI * 0.5:
		return
	var loosening := step == Step.LOOSEN
	var amount := (-d if loosening else d) / TAU
	if amount <= 0.0:
		return
	_nut_turns += amount
	var nut := _nuts[_nut]
	var t := clampf(_nut_turns / _turns_needed, 0.0, 1.0)
	var home: Transform3D = (_nut_home_flat if loosening else _nut_home)[_nut]
	# spun about the axle, whichever way the nut model ended up turned
	var axle: Vector3 = (home.basis.inverse() * _axle_local()).normalized()
	var spin := Basis(axle, (-1.0 if loosening else 1.0) * _nut_turns * TAU)
	var travel := 1.2 * (t if loosening else 1.0 - t)    # how far out of the hub (nut units)
	nut.transform = Transform3D(home.basis * spin, home.origin + _axle_local() * travel * home.basis.get_scale().y * 2.0)
	if _nut_turns >= _turns_needed:
		_nut_turns = 0.0
		AudioManager.play_sound(AudioManager.GetSocket(), -18)
		if loosening:
			_drop_nut(nut)
		else:
			nut.transform = home
		_nut += 1
		if _nut >= 4:
			_nut = 0
			step = Step.PULL_FLAT if loosening else Step.DONE
			if step == Step.DONE:
				_finish()
	_update_text()

## Out along the axle (away from the car), in the car's own space - the way a
## nut backs out of the hub.
func _axle_local() -> Vector3:
	return (car.global_basis.inverse() * _out).normalized()

## A loosened nut falls off the hub and is set aside.
func _drop_nut(nut: Node3D) -> void:
	var tw := create_tween()
	tw.tween_property(nut, "global_position", nut.global_position + _out * 0.15 + Vector3.DOWN * 0.25, 0.25)
	tw.tween_callback(nut.hide)

## ---------------------------------------------------------------------
## Swapping the wheel
## ---------------------------------------------------------------------

func _pull_flat() -> void:
	_busy = true
	AudioManager.play_sound(AudioManager.Thud4)
	var tw := create_tween()
	tw.tween_property(wheel, "global_position", wheel.global_position + _out * pull_distance, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(wheel, "global_position", wheel.global_position + _out * pull_distance + Vector3.DOWN * 0.4 - car.global_basis.z.normalized() * 0.8, 0.35)
	tw.tween_callback(wheel.hide)
	await tw.finished
	step = Step.FIT_SPARE
	_busy = false
	_update_text()

func _fit_spare() -> void:
	_busy = true
	_spare = MeshInstance3D.new()
	_spare.mesh = wheel.mesh
	_spare.material_override = wheel.material_override
	car.add_child(_spare)
	var seated := wheel_round_xf
	seated.origin.y += car.global_position.y - _car_start_y   # the car is up on the jack
	_spare.global_transform = seated.translated(_out * pull_distance)
	var tw := create_tween()
	tw.tween_property(_spare, "global_position", seated.origin, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	AudioManager.play_sound(AudioManager.Thud4)
	# nuts back on the hub, sitting loose, ready to be tightened
	for i in 4:
		_nuts[i].transform = Transform3D(_nut_home[i].basis, _nut_home[i].origin + _axle_local() * 1.2 * _nut_home[i].basis.get_scale().y * 2.0)
		_nuts[i].show()
	step = Step.TIGHTEN
	_nut = 0
	_nut_turns = 0.0
	_busy = false
	_update_text()

func _finish() -> void:
	_busy = true
	_update_text()
	var tw := create_tween()
	tw.tween_property(car, "global_position:y", _car_start_y, 0.6)
	await tw.finished
	_close(true)

## Ends the minigame. Stopping early (Esc, or caught) keeps everything as it
## is - car up, nuts off, flat off, spare on - and saves it in `state` to carry
## on next time.
func _close(success: bool) -> void:
	if not is_inside_tree():
		return
	if success:
		for ol in _nut_outlines:
			if is_instance_valid(ol):
				ol.queue_free()
	else:
		_save_progress()
	for n in _hushed:
		if is_instance_valid(n):
			n.set_outline_blocked(false)
	if _pumps == 0:
		PlayerManager.HideDialog()
	if success and is_instance_valid(_spare):
		_spare.queue_free()   # FlatTire puts the real wheel back, round
	if is_instance_valid(_camera):
		_camera.queue_free()
	if is_instance_valid(PlayerManager.player):
		PlayerManager.player.CAMERA.current = true
	PlayerManager.MiniGameModeOff()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	finished.emit(success)
	queue_free()

## Where the tire change got to, kept in `state` (see _close).
func _save_progress() -> void:
	# settle anything mid-animation: nuts already off are gone, the rest stay
	# where they are (a half-turned nut stays half out)
	for i in _nuts.size():
		if (step == Step.LOOSEN and i < _nut) or step == Step.PULL_FLAT or step == Step.FIT_SPARE:
			_nuts[i].hide()
	for ol in _nut_outlines:
		if is_instance_valid(ol):
			ol.is_interactable = false
			ol.set_near(false)
	state.merge({
		"step": step, "pumps": _pumps, "pumps_needed": _pumps_needed,
		"turns_needed": _turns_needed, "nut": _nut, "nut_turns": _nut_turns,
		"nuts": _nuts, "nut_home": _nut_home, "nut_home_flat": _nut_home_flat,
		"nut_outlines": _nut_outlines, "spare": _spare, "car_start_y": _car_start_y,
	}, true)

## Picks up from a saved try (see _save_progress).
func _restore() -> void:
	step = state.step
	_pumps = state.pumps
	_pumps_needed = state.pumps_needed
	_turns_needed = state.turns_needed
	_nut = state.nut
	_nut_turns = state.nut_turns
	_nuts = state.nuts
	_nut_home = state.nut_home
	_nut_home_flat = state.nut_home_flat
	_nut_outlines = state.nut_outlines
	_spare = state.spare
	_car_start_y = state.car_start_y

## ---------------------------------------------------------------------
## On-screen text and the progress ring
## ---------------------------------------------------------------------

func _update_text() -> void:
	_outline_current_nut()
	match step:
		Step.JACK: _label.text = "Pump the jack - click! (%d / %d)" % [_pumps, _pumps_needed]
		Step.LOOSEN: _label.text = "Loosen the lug nuts - circle the mouse anti-clockwise (%d / 4)" % _nut
		Step.PULL_FLAT: _label.text = "Click to pull the flat off"
		Step.FIT_SPARE: _label.text = "Click to fit the spare"
		Step.TIGHTEN: _label.text = "Tighten the lug nuts - circle the mouse clockwise (%d / 4)" % _nut
		Step.DONE: _label.text = "Done - lowering the jack"

## Only the nut to turn right now is outlined (none while jacking, pulling the
## flat or fitting the spare).
func _outline_current_nut() -> void:
	var turning := step == Step.LOOSEN or step == Step.TIGHTEN
	for i in _nut_outlines.size():
		var on := turning and i == _nut and not _busy
		if _nut_outlines[i].is_interactable != on:
			_nut_outlines[i].is_interactable = on
			_nut_outlines[i].set_near(on)

func _wheel_screen_center() -> Vector2:
	return _camera.unproject_position(_wheel_center() + Vector3.UP * (car.global_position.y - _car_start_y))

func _angle_at(pos: Vector2) -> float:
	var v := pos - _wheel_screen_center()
	return atan2(v.y, v.x)

func _draw_overlay() -> void:
	if not is_instance_valid(_camera):
		return
	if step == Step.LOOSEN or step == Step.TIGHTEN:
		var nut := _nuts[_nut]
		var p := _camera.unproject_position(nut.global_position)
		_overlay.draw_arc(p, 18.0, 0, TAU, 32, UiManager.ACCENT, 2.0)
		_overlay.draw_arc(p, 18.0, -PI / 2.0, -PI / 2.0 + TAU * (_nut_turns / _turns_needed), 32, UiManager.ACCENT_TEXT, 4.0)
		_draw_turn_arrow(step == Step.TIGHTEN)
	elif step == Step.JACK:
		var h := 140.0
		var top := Vector2(_overlay.size.x - 60.0, _overlay.size.y / 2.0 - h / 2.0)
		_overlay.draw_rect(Rect2(top, Vector2(20, h)), Color(1, 1, 1, 0.15))
		var fill := h * float(_pumps) / _pumps_needed
		_overlay.draw_rect(Rect2(top + Vector2(0, h - fill), Vector2(20, fill)), UiManager.ACCENT)

## A circular arrow around the wheel showing which way to circle the mouse:
## anti-clockwise to loosen, clockwise to tighten. It creeps round that way.
func _draw_turn_arrow(clockwise: bool) -> void:
	var c := _wheel_screen_center()
	var radius := minf(_overlay.size.y * 0.24, 130.0)
	var dir := 1.0 if clockwise else -1.0   # screen y is down: + angle = clockwise
	var start := dir * Time.get_ticks_msec() / 1000.0 * 0.8
	var sweep := TAU * 0.7
	var col := Color(UiManager.ACCENT_TEXT, 0.85)
	_overlay.draw_arc(c, radius, start, start + dir * sweep, 48, col, 4.0, true)
	# arrowhead at the leading end, pointing along the way to turn
	var e := start + dir * sweep
	var tip_at := c + Vector2(cos(e), sin(e)) * radius
	var along := Vector2(-sin(e), cos(e)) * dir
	var outward := Vector2(cos(e), sin(e))
	_overlay.draw_colored_polygon(PackedVector2Array([
		tip_at + along * 16.0,
		tip_at - along * 6.0 + outward * 11.0,
		tip_at - along * 6.0 - outward * 11.0]), col)
