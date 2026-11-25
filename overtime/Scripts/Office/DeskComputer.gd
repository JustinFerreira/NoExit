## No Exit
## Overtime Studios
## Desk Computer
## - The computer on the player's desk (rogue office - OfficeJobs puts this
##   on it). Click it: the view moves in to its screen (a camera of its own,
##   ZOOM_TIME) and the desktop opens - "OVERTIME OS": an Email icon (the
##   inbox: click a message to read it, "< Inbox" to go back, "X" to close
##   the app) and a couple that don't do much. "Log off" (or Esc / right
##   click) and the view comes back.
## - The emails are EMAILS below.
## - Read ones stay read for the run (RogueRun.office_data["read_mail"]).

extends Interactable

## Seconds the view takes to move in / out.
const ZOOM_TIME := 0.7
## How far in front of the screen the view stops (level units), and how
## far up the computer's box the screen's middle is (0-1).
const VIEW_DISTANCE := 1.05
const SCREEN_HEIGHT := 0.62
## Which way the screen faces (world) - towards the player's chair.
const SCREEN_FACING := Vector3(-1, 0, 0)
const FONT := preload("res://Assets/Fonts/Perfect_DOS_VGA_437.ttf")

const EMAILS := [
	{"from": "HR Department", "subject": "Mandatory Overtime", "body": "Team,\n\nAs discussed, everyone will be staying late until the quarter closes. Please do not use the stairwell; it is closed for repairs. The elevator to the parking garage remains in service.\n\nIf you notice a colleague has not returned from the garage, there is no need to report it. HR is aware.\n\nThank you for your continued dedication.\n\n- HR"},
	{"from": "Facilities", "subject": "Garage lighting", "body": "Hi all,\n\nSeveral lights on the lower garage levels are out again. A ticket has been raised.\n\nUntil then, please do not linger down there, and lock your car as soon as you get in.\n\nFacilities"},
	{"from": "Gus (Break Room)", "subject": "STAMINA CHARGES - 5 COINS", "body": "hey\n\nrunning low on breath down in the garage? i got stamina charges. 5 coins each. break room, by the kitchen.\n\nno refunds\n\n- gus"},
	{"from": "IT Support", "subject": "Your password has expired", "body": "Your password expired -3 days ago.\n\nPlease change it at your earliest convenience. Do not reply to this message. Do not turn off your computer. Do not look behind you.\n\nIT Support\n(automated message)"},
	{"from": "Facilities", "subject": "RE: coffee on the floor", "body": "To whoever keeps spilling coffee by the kitchen:\n\nThe janitor has asked me to pass on that he has 'had it'. Please use a lid.\n\nAlso: there is a revolver in the kitchen fridge. Nobody knows whose it is. Please do not touch it.\n\nFacilities"},
	{"from": "(no sender)", "subject": "dont go down there", "body": "it waits by the cars\n\nit is faster than you think\n\nif it grabs you, FIGHT. hit F as hard as you can\n\nthe ones who stood still never came back up"},
]

var _busy := false
var _cam: Camera3D
var _home := Transform3D()
var _ui: CanvasLayer
var _desktop: Control
var _app: Control

## ---------------------------------------------------------------------
## In and out
## ---------------------------------------------------------------------

func _on_interacted(_body: Variant) -> void:
	if _busy or UiManager.any_screen_open() or not is_instance_valid(PlayerManager.player):
		return
	_busy = true
	PlayerManager.InAnimation = true
	set_outline_blocked(true)
	var pcam: Camera3D = PlayerManager.player.CAMERA
	_cam = Camera3D.new()
	_cam.name = "ComputerCam"
	_cam.fov = pcam.fov
	_cam.near = 0.02
	get_tree().current_scene.add_child(_cam)
	_home = pcam.global_transform
	_cam.global_transform = _home
	_cam.current = true
	await _move(_home, _view())
	_open_ui()

func _view() -> Transform3D:
	var m := get_parent() as MeshInstance3D
	var box: AABB = m.global_transform * m.get_aabb() if m else AABB(global_position, Vector3.ONE)
	var screen := Vector3(box.get_center().x, box.position.y + box.size.y * SCREEN_HEIGHT, box.get_center().z)
	var eye := screen + SCREEN_FACING * VIEW_DISTANCE
	return Transform3D(Basis.looking_at(screen - eye, Vector3.UP), eye)

func _move(from: Transform3D, to: Transform3D) -> void:
	var tw := create_tween()
	tw.tween_method(func(k: float): if is_instance_valid(_cam): _cam.global_transform = from.interpolate_with(to, k), 0.0, 1.0, ZOOM_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

func _log_off() -> void:
	if _ui == null:
		return
	_ui.queue_free()
	_ui = null
	UiManager.close_screen("computer")
	await _move(_cam.global_transform, PlayerManager.player.CAMERA.global_transform if is_instance_valid(PlayerManager.player) else _home)
	if is_instance_valid(PlayerManager.player):
		PlayerManager.player.CAMERA.current = true
	_cam.queue_free()
	PlayerManager.InAnimation = false
	set_outline_blocked(false)
	_busy = false

## ---------------------------------------------------------------------
## The screen
## ---------------------------------------------------------------------

func _read() -> Array:
	var d: Dictionary = RogueRun.office_data
	if not d.has("read_mail"):
		d["read_mail"] = []
	return d.read_mail

func _open_ui() -> void:
	UiManager.open_screen("computer", false, true)
	_ui = CanvasLayer.new()
	_ui.layer = 45
	add_child(_ui)
	var keys := _KeyCatcher.new()
	keys.on_exit = _log_off
	_ui.add_child(keys)
	# the monitor's bezel round the screen
	var bezel := ColorRect.new()
	bezel.color = Color(0.08, 0.08, 0.09)
	bezel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(bezel)
	var screen := ColorRect.new()
	screen.color = Color(0.0, 0.38, 0.42)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.offset_left = 60
	screen.offset_top = 40
	screen.offset_right = -60
	screen.offset_bottom = -40
	bezel.add_child(screen)
	_desktop = screen
	# top bar
	var bar := ColorRect.new()
	bar.color = Color(0.75, 0.75, 0.72)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, 34)
	bar.size.y = 34
	screen.add_child(bar)
	var title := _label("OVERTIME OS 3.1   -   Workstation 0451", 18, Color(0.1, 0.1, 0.1))
	title.position = Vector2(12, 6)
	bar.add_child(title)
	var clock := _label("11:47 PM", 18, Color(0.1, 0.1, 0.1))
	clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	clock.position = Vector2(-120, 6)
	bar.add_child(clock)
	# icons
	var unread := 0
	for i in EMAILS.size():
		if not i in _read():
			unread += 1
	_icon(screen, Vector2(40, 70), "Email" + (" (%d)" % unread if unread > 0 else ""), Color(0.95, 0.85, 0.35), _open_email)
	_icon(screen, Vector2(40, 190), "My Documents", Color(0.85, 0.75, 0.45), func(): _popup("Access denied.\nContact your administrator."))
	_icon(screen, Vector2(40, 310), "Recycle Bin", Color(0.7, 0.75, 0.8), func(): _popup("The Recycle Bin is empty.\nIt was emptied by someone else."))
	# log off
	var off := _button("Log off", 18)
	off.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	off.position = Vector2(-140, -54)
	off.size = Vector2(120, 36)
	off.pressed.connect(_log_off)
	screen.add_child(off)

func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	# (this font draws the line break of an empty line as a symbol - give
	# empty lines a space)
	l.text = text.replace("

", "
 
")
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	# dark text on a light key, a blue one under the mouse
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(0.88, 0.88, 0.86), "hover": Color(0.1, 0.15, 0.45), "pressed": Color(0.05, 0.08, 0.3)}[state]
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	return b

func _icon(parent: Control, at: Vector2, text: String, col: Color, action: Callable) -> void:
	var box := Button.new()
	box.flat = true
	box.focus_mode = Control.FOCUS_NONE
	box.position = at
	box.size = Vector2(130, 100)
	parent.add_child(box)
	var pic := ColorRect.new()
	pic.color = col
	pic.position = Vector2(35, 4)
	pic.size = Vector2(60, 50)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pic)
	var l := _label(text, 16, Color(1, 1, 1))
	l.position = Vector2(0, 62)
	l.size = Vector2(130, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	box.pressed.connect(action)

## A window on the desktop (title bar with an X).
func _window(title_text: String, size: Vector2) -> Control:
	if is_instance_valid(_app):
		_app.queue_free()
	var win := ColorRect.new()
	win.color = Color(0.82, 0.82, 0.8)
	win.size = size
	win.position = (_desktop.size - size) * 0.5 + Vector2(40, 10)
	_desktop.add_child(win)
	var bar := ColorRect.new()
	bar.color = Color(0.1, 0.15, 0.45)
	bar.size = Vector2(size.x, 30)
	win.add_child(bar)
	var t := _label(title_text, 16, Color(1, 1, 1))
	t.position = Vector2(8, 5)
	bar.add_child(t)
	var x := _button("X", 14)
	x.position = Vector2(size.x - 34, 2)
	x.size = Vector2(30, 26)
	x.pressed.connect(func(): if is_instance_valid(win): win.queue_free())
	bar.add_child(x)
	_app = win
	return win

func _popup(text: String) -> void:
	var win := _window("System", Vector2(420, 170))
	var l := _label(text, 18, Color(0.1, 0.1, 0.1))
	l.position = Vector2(20, 50)
	win.add_child(l)

func _open_email() -> void:
	var win := _window("Email - Inbox", Vector2(minf(_desktop.size.x - 200, 900), minf(_desktop.size.y - 120, 560)))
	var list := VBoxContainer.new()
	list.position = Vector2(12, 42)
	list.size = Vector2(win.size.x - 24, win.size.y - 54)
	win.add_child(list)
	for i in EMAILS.size():
		var e: Dictionary = EMAILS[i]
		var unread: bool = not i in _read()
		var b := _button("%s %-18s  %s" % ["*" if unread else " ", e.from, e.subject], 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_open_message.bind(i))
		list.add_child(b)

func _open_message(i: int) -> void:
	if not i in _read():
		_read().append(i)
	var e: Dictionary = EMAILS[i]
	var win := _window("Email - " + e.subject, Vector2(minf(_desktop.size.x - 200, 900), minf(_desktop.size.y - 120, 560)))
	var back := _button("< Inbox", 16)
	back.position = Vector2(12, 40)
	back.pressed.connect(_open_email)
	win.add_child(back)
	var head := _label("From: %s\nSubject: %s" % [e.from, e.subject], 16, Color(0.1, 0.1, 0.1))
	head.position = Vector2(14, 82)
	win.add_child(head)
	var body := _label(e.body, 16, Color(0.1, 0.1, 0.1))
	body.position = Vector2(14, 136)
	body.size = Vector2(win.size.x - 28, win.size.y - 150)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win.add_child(body)

## Esc / right click: log off.
class _KeyCatcher extends Node:
	var on_exit: Callable
	func _input(event: InputEvent) -> void:
		var esc: bool = event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
		var rmb: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
		if esc or rmb:
			get_viewport().set_input_as_handled()
			if on_exit.is_valid():
				on_exit.call()
