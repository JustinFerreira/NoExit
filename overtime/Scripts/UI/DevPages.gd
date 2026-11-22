## No Exit
## Overtime Studios
## Dev Pages (dev pause menu only)
## - Turns the dev pause menu into pages you flip through with < > arrows at
##   the top of every page (they replace the old Dev Tools / Previous Screen
##   buttons):
##     Paused     - the normal pause buttons
##     Dev Tools  - killer off, free roam, visibility..., which hand the
##                  battery minigame shows (simple / arm model)
##     Events     - the event director: when the next event can happen, how
##                  many of each kind went off, legendaries seen
##     Flags      - every true/false value in the game managers and on the
##                  player, live (click one to flip it)
##     Event Map  - the garage from above, deck by deck, with every event on
##                  it: left-click one to go there and set it off, right-click
##                  to just go there. M (dev mode) opens it straight away.
##                  "Go to my car", and buttons that start each minigame
##                  (battery, gas, tire, hot-wire) right at the car.
## - Added by PauseMenu when it's the dev menu.

extends Node

const EventDirector = preload("res://Scripts/Events/EventDirector.gd")
const WireHand = preload("res://Scripts/Minigames/WireHand.gd")
const TIER_NAMES := ["common", "rare", "LEGENDARY"]
const TIER_COLORS := [Color(0.75, 0.75, 0.75), Color(0.35, 0.65, 1.0), Color(1.0, 0.2, 0.2)]

var menu: Control
var pages: Array[Control] = []
var titles: Array[String] = []
var _page := 0
var _font: Font
var _refresh := 0.0

# Events page
var _ev_status: Label
var _ev_table: GridContainer
# Flags page
var _flag_grid: GridContainer
var _flag_filter: LineEdit
var _flag_only_on: CheckBox
var _flag_boxes: Dictionary = {}   # "Owner.name" -> CheckBox
# Map page
var _map: Control
var _map_deck := 0
var _map_hint: Label
var _deck_buttons: HBoxContainer

func setup(owner_menu: Control) -> void:
	menu = owner_menu
	_font = menu.get_node("PanelContainer/VBoxContainer/ResumeBtn").get_theme_font("font")
	# the old page buttons go - arrows do it now
	for path in ["PanelContainer/VBoxContainer/DevToolsBtn", "PanelContainer/VBoxContainer/MarginContainer6",
			"PanelContainer2/VBoxContainer/BacktoScreen", "PanelContainer2/VBoxContainer/MarginContainer2"]:
		var n := menu.get_node_or_null(path)
		if n:
			n.visible = false
	_add_page(menu.get_node("PanelContainer"), "Paused", true)
	_add_page(menu.get_node("PanelContainer2"), "Dev Tools", true)
	_add_page(_make_events_page(), "Events", false)
	_add_page(_make_flags_page(), "Flags", false)
	_add_page(_make_map_page(), "Event Map", false)
	# Dev Tools: which hand the battery minigame shows
	var tools: VBoxContainer = menu.get_node("PanelContainer2/VBoxContainer")
	var hand_btn := _button("", func(): pass, 22)
	hand_btn.pressed.connect(func():
		WireHand.use_model = not WireHand.use_model
		_hand_label(hand_btn))
	_hand_label(hand_btn)
	tools.add_child(hand_btn)
	tools.move_child(hand_btn, 4)
	UiManager.screen_opened.connect(func(id): if id == "pause": show_page(0))
	show_page(0)

## A page: its arrow row goes at the top (under the PAUSED title on the
## scene's own pages).
func _add_page(page: Control, title: String, scene_page: bool) -> void:
	var idx := pages.size()
	pages.append(page)
	titles.append(title)
	var box: VBoxContainer = page.get_node("VBoxContainer") if scene_page else page.get_child(0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	row.add_child(_button("<", func(): show_page(idx - 1)))
	var name_label := _label(title, 30, UiManager.TITLE_COLOR)
	name_label.custom_minimum_size = Vector2(200, 0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	row.add_child(_button(">", func(): show_page(idx + 1)))
	box.add_child(row)
	box.move_child(row, 3 if scene_page else 0)
	if not scene_page:
		page.visible = false
		menu.add_child(page)

func show_page(i: int) -> void:
	_page = posmod(i, pages.size())
	for k in pages.size():
		pages[k].visible = k == _page
	_refresh = 0.0

## Esc closes the menu from our pages too (the scene's pages do it with their
## Resume button's shortcut, which only works while that button shows).
## M (dev mode only) opens the menu straight on the Event Map, or closes it
## when the map is already showing.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M \
			and PlayerManager.DevMode:
		var map_page := titles.find("Event Map")
		if UiManager.is_open("pause") and UiManager.top_screen() == "pause":
			get_viewport().set_input_as_handled()
			if _page == map_page:
				menu.resume()
			else:
				show_page(map_page)
		elif not UiManager.any_screen_open() and not PlayerManager.MainMenu and not PlayerManager.dying \
				and is_instance_valid(PlayerManager.player):
			get_viewport().set_input_as_handled()
			menu.pause()   # this opens on page 0 ...
			show_page(map_page)   # ... so flip to the map after
		return
	if menu.visible and _page >= 2 and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		menu.resume()

func _process(delta: float) -> void:
	if not menu.visible:
		return
	# our own pages fade in and out with the menu, like the scene's pages
	for k in range(2, pages.size()):
		pages[k].modulate.a = menu.get_node("PanelContainer").modulate.a
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.3
	match titles[_page]:
		"Events": _update_events()
		"Flags": _update_flags()
		"Event Map": _map.queue_redraw()

## ---------------------------------------------------------------------
## Building blocks
## ---------------------------------------------------------------------

## The game draws at 640x480 (wider on wide screens), so a page fills the
## screen with a small margin.
func _page_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 10
	p.offset_right = -10
	p.offset_top = 10
	p.offset_bottom = -10
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.03, 0.03, 0.85)
	bg.border_color = UiManager.ACCENT
	bg.set_border_width_all(2)
	bg.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", bg)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	p.add_child(box)
	return p

func _label(text: String, size: int = 18, color: Color = UiManager.TEXT_COLOR) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, on_press: Callable, size: int = 30) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_hover_color", UiManager.BUTTON_HOVER)
	b.add_theme_color_override("font_pressed_color", UiManager.TITLE_COLOR)
	b.pressed.connect(func():
		AudioManager.play_sound(AudioManager.GetKeyPress())
		on_press.call())
	return b

## ---------------------------------------------------------------------
## Events page
## ---------------------------------------------------------------------

func _make_events_page() -> Control:
	var p := _page_panel()
	var box: VBoxContainer = p.get_child(0)
	_ev_status = _label("", 12)
	box.add_child(_ev_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.add_child(_button("Next event ready now", func(): EventDirector.ready_now(), 13))
	buttons.add_child(_button("Forget legendaries seen", func(): EventDirector.reset_seen(), 13))
	box.add_child(buttons)
	var alarms := HBoxContainer.new()
	alarms.add_theme_constant_override("separation", 10)
	alarms.add_child(_label("Car alarm here, level:", 12))
	for lv in [1, 2, 3, 4]:
		var level: int = lv
		alarms.add_child(_button(str(level), func(): _alarm_nearest(level), 13))
	box.add_child(alarms)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ev_table = GridContainer.new()
	_ev_table.columns = 6
	_ev_table.add_theme_constant_override("h_separation", 14)
	_ev_table.add_theme_constant_override("v_separation", 0)
	scroll.add_child(_ev_table)
	box.add_child(scroll)
	return p

func _update_events() -> void:
	var t := EventDirector.seconds_to_next()
	var status := "Next event allowed in %.0f s" % t if t > 0.0 else "An event can happen now (quiet for %.0f s)" % -t
	if EventDirector.last_kind != "":
		status += "\nLast: %s, %.0f s ago" % [EventDirector.last_kind, (Time.get_ticks_msec() - EventDirector.last_ms) / 1000.0]
	var k_node = PlayerManager.Enemy
	if not PlayerManager.no_enemy and is_instance_valid(k_node) and k_node.is_inside_tree() and is_instance_valid(PlayerManager.player):
		status += "\nKiller is %.0f m away" % k_node.global_position.distance_to(PlayerManager.player.global_position)
	else:
		status += "\nKiller is off"
	_ev_status.text = status
	for c in _ev_table.get_children():
		c.queue_free()
	for h in ["Event", "Tier", "Placed", "Run/total", "Seen", "Killer away"]:
		_ev_table.add_child(_label(h, 12, UiManager.ACCENT_TEXT))
	var kinds := {}
	for ev in _all_events():
		var k: String = ev.get_kind()
		if not kinds.has(k):
			kinds[k] = {"tier": ev.tier, "n": 0, "far": ev.min_killer_distance}
		kinds[k].n += 1
	var seen := EventDirector.seen_legendaries()
	var names := kinds.keys()
	names.sort_custom(func(a, b): return kinds[a].tier > kinds[b].tier or (kinds[a].tier == kinds[b].tier and a < b))
	for k in names:
		var tier: int = kinds[k].tier
		_ev_table.add_child(_label(k, 12, TIER_COLORS[tier]))
		_ev_table.add_child(_label(TIER_NAMES[tier], 12, TIER_COLORS[tier]))
		_ev_table.add_child(_label(str(kinds[k].n), 12))
		_ev_table.add_child(_label("%d / %d" % [EventDirector.fired_this_run.get(k, 0), EventDirector.fired_total.get(k, 0)], 12))
		_ev_table.add_child(_label(("yes" if seen.has(k) else "no") if tier == 2 else "-", 12))
		_ev_table.add_child(_label(">= %.0f m" % kinds[k].far if kinds[k].far > 0.0 else "any", 12))
	if names.is_empty():
		_ev_table.add_child(_label("No events in this level.", 12))

func _all_events() -> Array:
	var out := []
	var scene := get_tree().current_scene
	if scene == null:
		return out
	for n in scene.find_children("*", "", true, false):
		if n.has_method("get_kind") and n.has_method("can_fire"):
			out.append(n)
	return out

## ---------------------------------------------------------------------
## Flags page
## ---------------------------------------------------------------------

const FLAG_OWNERS := ["PlayerManager", "EventManager", "AnimationManager", "GameState", "RogueRun", "SettingsManager", "AudioManager", "UiManager", "HelperManager"]

func _make_flags_page() -> Control:
	var p := _page_panel()
	var box: VBoxContainer = p.get_child(0)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	_flag_filter = LineEdit.new()
	_flag_filter.placeholder_text = "search..."
	_flag_filter.custom_minimum_size = Vector2(200, 0)
	_flag_filter.add_theme_font_size_override("font_size", 12)
	_flag_filter.add_theme_font_override("font", _font)
	_flag_filter.text_changed.connect(func(_t): _refresh = 0.0)
	top.add_child(_flag_filter)
	_flag_only_on = CheckBox.new()
	_flag_only_on.text = "only show ON"
	_flag_only_on.add_theme_font_override("font", _font)
	_flag_only_on.add_theme_font_size_override("font_size", 12)
	_flag_only_on.toggled.connect(func(_b): _refresh = 0.0)
	top.add_child(_flag_only_on)
	top.add_child(_label("(click one to flip it)", 11, Color(0.6, 0.6, 0.6)))
	box.add_child(top)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_flag_grid = GridContainer.new()
	_flag_grid.columns = 2
	_flag_grid.add_theme_constant_override("h_separation", 12)
	_flag_grid.add_theme_constant_override("v_separation", 0)
	scroll.add_child(_flag_grid)
	box.add_child(scroll)
	return p

## Every bool on the managers and the player: [owner name, object, property].
func _flags() -> Array:
	var out := []
	for owner_name in FLAG_OWNERS:
		var obj := get_node_or_null("/root/" + owner_name)
		if obj:
			_bools_of(obj, owner_name, out)
	if is_instance_valid(PlayerManager.player):
		_bools_of(PlayerManager.player, "Player", out)
	return out

func _bools_of(obj: Object, owner_name: String, out: Array) -> void:
	for prop in obj.get_property_list():
		if prop.type == TYPE_BOOL and prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not String(prop.name).begins_with("_"):
			out.append([owner_name, obj, prop.name])

func _update_flags() -> void:
	var want := _flag_filter.text.strip_edges().to_lower()
	var seen := {}
	for f in _flags():
		var key: String = f[0] + "." + f[2]
		var value: bool = f[1].get(f[2])
		var show := (want == "" or key.to_lower().contains(want)) and (value or not _flag_only_on.button_pressed)
		seen[key] = true
		var cb: CheckBox = _flag_boxes.get(key)
		if cb == null:
			cb = CheckBox.new()
			cb.text = key
			cb.focus_mode = Control.FOCUS_NONE
			cb.add_theme_font_override("font", _font)
			cb.add_theme_font_size_override("font_size", 11)
			var obj: Object = f[1]
			var prop: String = f[2]
			cb.toggled.connect(func(on: bool): if is_instance_valid(obj): obj.set(prop, on))
			_flag_grid.add_child(cb)
			_flag_boxes[key] = cb
		cb.set_pressed_no_signal(value)
		cb.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if value else Color(0.55, 0.55, 0.55))
		cb.visible = show
	for key in _flag_boxes.keys():
		if not seen.has(key):
			_flag_boxes[key].queue_free()
			_flag_boxes.erase(key)

## ---------------------------------------------------------------------
## Event map page
## ---------------------------------------------------------------------

func _make_map_page() -> Control:
	var p := _page_panel()
	var box: VBoxContainer = p.get_child(0)
	_deck_buttons = HBoxContainer.new()
	_deck_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_deck_buttons.add_theme_constant_override("separation", 12)
	box.add_child(_deck_buttons)
	# your car, and every minigame started right where it's played
	var car_row := HBoxContainer.new()
	car_row.alignment = BoxContainer.ALIGNMENT_CENTER
	car_row.add_theme_constant_override("separation", 12)
	car_row.add_child(_button("Go to my car", func(): _car_action("go"), 13))
	car_row.add_child(_label("Play here:", 12, Color(0.7, 0.7, 0.7)))
	for game in ["Battery", "Gas", "Tire", "Hot-wire"]:
		var g: String = game
		car_row.add_child(_button(g, func(): _car_action(g), 13))
	box.add_child(car_row)
	_map = Control.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_on_map_input)
	box.add_child(_map)
	_map_hint = _label("Left-click an event: go there and set it off.   Right-click: just go there.", 11, Color(0.7, 0.7, 0.7))
	box.add_child(_map_hint)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 24)
	for t in 3:
		legend.add_child(_label("● " + TIER_NAMES[t], 11, TIER_COLORS[t]))
	legend.add_child(_label("▲ you", 11, Color(0.3, 1.0, 0.4)))
	legend.add_child(_label("■ your car", 11, Color(1.0, 0.85, 0.2)))
	box.add_child(legend)
	return p

## Decks of the split-level garage: floor heights, ~2.56 m apart.
const DECK_BASE := 0.16
const DECK_STEP := 2.56

func _deck_of(y: float) -> int:
	return maxi(int(round((y - DECK_BASE) / DECK_STEP)), 0)

## Each event with its floor deck and where it is (cached per level).
var _map_events: Array = []
var _map_level_id := 0
var _nav_polys: Array = []   # [PackedVector2Array, deck]
var _bounds := Rect2()
var _deck_bounds: Dictionary = {}   # deck -> Rect2 (what that deck covers)

func _collect_map() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.get_instance_id() == _map_level_id:
		return
	_map_level_id = scene.get_instance_id()
	_map_events.clear()
	_nav_polys.clear()
	_deck_bounds.clear()
	var space: PhysicsDirectSpaceState3D = scene.get_viewport().get_world_3d().direct_space_state
	var pts: Array[Vector2] = []
	for ev in _all_events():
		var at: Vector3 = ev.global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 6.0))
		var floor_y: float = hit.position.y if hit else at.y
		_map_events.append({"ev": ev, "deck": _deck_of(floor_y), "pos": at, "floor": floor_y})
		pts.append(Vector2(at.x, at.z))
		_grow_deck(_deck_of(floor_y), Vector2(at.x, at.z))
	for region in scene.find_children("*", "NavigationRegion3D", true, false):
		var nm: NavigationMesh = region.navigation_mesh
		if nm == null:
			continue
		var verts := nm.vertices
		for i in nm.get_polygon_count():
			var poly := nm.get_polygon(i)
			var flat := PackedVector2Array()
			var y := 0.0
			for idx in poly:
				var v: Vector3 = region.global_transform * verts[idx]
				flat.append(Vector2(v.x, v.z))
				y += v.y
				pts.append(Vector2(v.x, v.z))
			var d := _deck_of(y / poly.size() - 0.5)
			_nav_polys.append([flat, d])
			for v in flat:
				_grow_deck(d, v)
	_bounds = Rect2(pts[0], Vector2.ZERO) if not pts.is_empty() else Rect2(-50, -50, 100, 100)
	for p in pts:
		_bounds = _bounds.expand(p)
	_bounds = _bounds.grow(4.0)
	# deck buttons
	for c in _deck_buttons.get_children():
		c.queue_free()
	var decks := {}
	for e in _map_events:
		decks[e.deck] = true
	var list := decks.keys()
	list.sort()
	for d in list:
		var deck: int = d
		_deck_buttons.add_child(_button("Deck %d" % (deck + 1), func(): _map_deck = deck; _map.queue_redraw(), 14))
	if is_instance_valid(PlayerManager.player):
		_map_deck = _deck_of(PlayerManager.player.global_position.y)

func _to_map(p: Vector2) -> Vector2:
	var b: Rect2 = _deck_bounds[_map_deck].grow(3.0) if _deck_bounds.has(_map_deck) else _bounds
	var s := minf(_map.size.x / b.size.x, _map.size.y / b.size.y)
	var off := (_map.size - b.size * s) * 0.5
	return off + (p - b.position) * s

func _draw_map() -> void:
	_collect_map()
	_map.draw_rect(Rect2(Vector2.ZERO, _map.size), Color(0, 0, 0, 0.5))
	for np in _nav_polys:
		if np[1] == _map_deck:
			var poly := PackedVector2Array()
			for v in np[0]:
				poly.append(_to_map(v))
			if poly.size() >= 3:
				_map.draw_colored_polygon(poly, Color(0.25, 0.25, 0.28, 0.9))
		elif absi(np[1] - _map_deck) == 1:
			var poly2 := PackedVector2Array()
			for v in np[0]:
				poly2.append(_to_map(v))
			if poly2.size() >= 3:
				_map.draw_colored_polygon(poly2, Color(0.14, 0.14, 0.16, 0.6))
	var hover = _event_at(_map.get_local_mouse_position())
	for e in _map_events:
		if e.deck != _map_deck or not is_instance_valid(e.ev):
			continue
		var at := _to_map(Vector2(e.pos.x, e.pos.z))
		var col: Color = TIER_COLORS[e.ev.tier]
		if e.ev.fired and not e.ev.repeatable:
			col = col.darkened(0.6)
		_map.draw_circle(at, 5.0 if e == hover else 3.5, col)
	# your car
	var car := _player_car()
	if car:
		var cp: Vector3 = car.global_position
		var here_car := _deck_of(cp.y - 0.5) == _map_deck
		var cm := _to_map(Vector2(cp.x, cp.z))
		_map.draw_rect(Rect2(cm - Vector2(6, 4), Vector2(12, 8)), Color(1.0, 0.85, 0.2, 1.0 if here_car else 0.35))
	if is_instance_valid(PlayerManager.player):
		var pp: Vector3 = PlayerManager.player.global_position
		var c := _to_map(Vector2(pp.x, pp.z))
		var here := _deck_of(pp.y) == _map_deck
		# the triangle points where the player is looking (map x = world x,
		# map y = world z, so the flat look direction carries straight over)
		var fwd3: Vector3 = -PlayerManager.player.HEAD.global_basis.z
		var fwd := Vector2(fwd3.x, fwd3.z)
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector2.UP
		var side := Vector2(-fwd.y, fwd.x)
		_map.draw_colored_polygon(PackedVector2Array([c + fwd * 10.0, c - fwd * 6.0 + side * 7.0, c - fwd * 6.0 - side * 7.0]), Color(0.3, 1.0, 0.4, 1.0 if here else 0.35))
	_map.draw_string(_font, Vector2(10, 22), "Deck %d" % (_map_deck + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiManager.ACCENT_TEXT)
	if hover:
		var ev = hover.ev
		var txt := "%s (%s)%s" % [ev.get_kind(), TIER_NAMES[ev.tier], "  - already went off" if ev.fired and not ev.repeatable else ""]
		_map.draw_string(_font, _map.get_local_mouse_position() + Vector2(12, -10), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

func _event_at(m: Vector2):
	var best = null
	var best_d := 10.0
	for e in _map_events:
		if e.deck != _map_deck or not is_instance_valid(e.ev):
			continue
		var d := _to_map(Vector2(e.pos.x, e.pos.z)).distance_to(m)
		if d < best_d:
			best_d = d
			best = e
	return best

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_map.queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var e = _event_at(event.position)
		if e == null:
			return
		_go_to(e, event.button_index == MOUSE_BUTTON_LEFT)

## Teleports the player next to an event (on its floor) and, optionally, sets
## it off a moment after the menu closes.
func _go_to(e: Dictionary, fire: bool) -> void:
	var p = PlayerManager.player
	if not is_instance_valid(p):
		return
	var ev = e.ev
	var target: Vector3 = Vector3(e.pos.x, e.floor, e.pos.z)
	# stand a couple of metres off it, on its floor, somewhere the body fits
	p.global_position = _safe_stand(target + Vector3(2.0, 0, 2.0), e.floor)
	p.velocity = Vector3.ZERO
	var look: Vector3 = Vector3(e.pos.x, p.CAMERA.global_position.y, e.pos.z) - p.CAMERA.global_position
	if look.length() > 0.1:
		p.HEAD.rotation.y = atan2(-look.x, -look.z) - p.global_basis.get_euler().y
		p.CAMERA.rotation.x = 0.0
	menu.resume()
	if fire:
		get_tree().create_timer(0.6, true).timeout.connect(func(): EventDirector.debug_fire(ev))

func _grow_deck(deck: int, p: Vector2) -> void:
	_deck_bounds[deck] = _deck_bounds[deck].expand(p) if _deck_bounds.has(deck) else Rect2(p, Vector2.ZERO)

## Dev: the alarm car nearest the player goes off at `level` (skipping the
## director), the menu closes so it can be heard.
func _alarm_nearest(level: int) -> void:
	var p = PlayerManager.player
	if not is_instance_valid(p):
		return
	var best = null
	for ev in _all_events():
		if ev.has_method("fire_level") and (best == null or ev.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position)):
			best = ev
	if best == null:
		return
	menu.resume()
	best.fire_level(level)

## ---------------------------------------------------------------------
## Event map: your car and its minigames
## ---------------------------------------------------------------------

func _player_car() -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var car := scene.get_node_or_null("NavigationRegion3D/Car") as Node3D
	return car if car else scene.find_child("Car", true, false) as Node3D

## Stands the player on the floor near `near` - on the floor at `floor_y`
## (the target's own floor, never the deck above or below), somewhere their
## body fits - looking at `look`.
func _teleport(near: Vector3, look: Vector3, floor_y: float = NAN) -> void:
	var p = PlayerManager.player
	if not is_instance_valid(p):
		return
	if is_nan(floor_y):
		floor_y = near.y
	p.global_position = _safe_stand(near, floor_y)
	p.velocity = Vector3.ZERO
	var d: Vector3 = look - p.CAMERA.global_position
	if Vector2(d.x, d.z).length() > 0.05:
		p.HEAD.rotation.y = atan2(-d.x, -d.z) - p.global_basis.get_euler().y
		p.CAMERA.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-60), deg_to_rad(60))

## Dev: go to the car, or start one of its minigames there (whatever the
## round says - it's set up so it can be played).
func _car_action(what: String) -> void:
	var car := _player_car()
	if car == null:
		return
	var level := get_tree().current_scene
	var box: AABB = level._car_box(car) if level.has_method("_car_box") else AABB(car.global_position, Vector3.ONE)
	var front: Vector3 = level._front_of(car) if level.has_method("_front_of") else car.global_basis.z
	var side := front.cross(Vector3.UP).normalized()
	var mid := box.get_center()
	var half_len := (absf(front.x) * box.size.x + absf(front.z) * box.size.z) * 0.5
	var half_w := (absf(side.x) * box.size.x + absf(side.z) * box.size.z) * 0.5
	menu.resume()
	await get_tree().create_timer(0.35).timeout
	match what:
		"go":
			_teleport(mid + side * (half_w + 1.5), mid, box.position.y)
		"Battery":
			var hood := _with_script(car, "Minigames/Hood.gd")
			if hood == null:
				return
			_teleport(mid + front * (half_len + 1.5), hood.global_position, box.position.y)
			PlayerManager.minigameThreePassed = false
			PlayerManager.PositiveConnected = false
			PlayerManager.NegativeConnected = false
			hood._on_interacted(null)
		"Gas":
			var intake := _with_script(car, "Minigames/GasIntake.gd")
			if intake == null:
				return
			var at: Vector3 = intake.global_position
			var out := Vector3(at.x - mid.x, 0, at.z - mid.z)
			out = side * signf(side.dot(out)) if out.length() > 0.01 else side
			_teleport(at + out * 1.6, at, box.position.y)
			PlayerManager.minigameTwoPassed = false
			intake._on_interacted(null)
		"Tire":
			var flat := car.find_child("FlatTire", true, false)
			if flat == null:
				RogueRun._make_flat_tire(level)
				await get_tree().process_frame
				flat = car.find_child("FlatTire", true, false)
			if flat == null:
				return
			RogueRun.tire_fixed = false
			if not PlayerManager.has_item("Spare Tire"):
				PlayerManager.AddToInventory("Spare Tire", 0.5, true)
			await get_tree().physics_frame
			_teleport(flat.global_position + flat._out * 1.8, flat.global_position, box.position.y)
			flat._on_interacted(null)
		"Hot-wire":
			# the driver's door (the clickable part with CarDoor.gd under the door mesh)
			var door: Node3D = null
			for n in car.find_children("*", "", true, false):
				if n.get_script() and n.get_script().resource_path.ends_with("Minigames/CarDoor.gd") and str(n.get_path()).contains("DriverDoor"):
					door = n
			if door == null:
				door = _with_script(car, "Minigames/CarDoor.gd")
			if door == null:
				return
			if not PlayerManager.player.Incar:
				_teleport(door.global_position + side * signf(side.dot(door.global_position - mid)) * 1.5, door.global_position, box.position.y)
				if not PlayerManager.has_item("Car Keys"):
					PlayerManager.AddToInventory("Car Keys", 0.5, true)
				door.unlocked = false
				door._on_interacted(null)
				for i in 300:   # the getting-in animation
					if PlayerManager.player.Incar:
						break
					await get_tree().process_frame
			PlayerManager.minigameOnePassed = false
			PlayerManager.minigameOne = true
			PlayerManager.MiniGameModeOn()

func _with_script(root: Node, script_end: String) -> Node:
	for n in root.find_children("*", "", true, false):
		if n.get_script() and n.get_script().resource_path.ends_with(script_end):
			return n
	return null

func _hand_label(b: Button) -> void:
	b.text = "Battery hand: %s" % ("Arm model" if WireHand.use_model else "Simple")

## A spot on the floor at `floor_y` near `near` where the player's body fits
## (rings outward up to 4 m). Their feet go right on the floor - the nav
## mesh floats above it, and it can be on another deck near a ramp or a
## barrier, which used to drop / teleport them when a minigame let go.
func _safe_stand(near: Vector3, floor_y: float) -> Vector3:
	var p = PlayerManager.player
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var ex: Array[RID] = [p.get_rid()]
	var body := PhysicsShapeQueryParameters3D.new()
	body.shape = p.COLLISIONSHAPE3D.shape
	body.exclude = ex
	body.collide_with_areas = false
	for r in [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0]:
		var steps: int = 1 if r == 0.0 else 12
		for k in steps:
			var at: Vector3 = near + Vector3(r, 0, 0).rotated(Vector3.UP, TAU * k / steps)
			var down := PhysicsRayQueryParameters3D.create(Vector3(at.x, floor_y + 1.5, at.z), Vector3(at.x, floor_y - 1.0, at.z), 0xFFFFFFFF, ex)
			var hit := space.intersect_ray(down)
			if hit.is_empty() or (hit.normal as Vector3).y < 0.9 or absf(hit.position.y - floor_y) > 0.6:
				continue
			var feet: Vector3 = hit.position + Vector3.UP * 0.02
			body.transform = Transform3D(p.global_basis, feet) * p.COLLISIONSHAPE3D.transform
			if space.intersect_shape(body, 1).is_empty():
				return feet
	return Vector3(near.x, floor_y + 0.05, near.z)
