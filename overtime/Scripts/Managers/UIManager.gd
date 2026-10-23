## No Exit
## Overtime Studios
## Last updated 10/21/26 by Justin Ferreira
## UI Manager (autoload "UiManager")
## - One place that turns every piece of UI on and off, so menus, dialog,
##   the crosshair and the HUD never fight each other.
##
## SCREENS - full-screen UI that takes over (pause, journal, game over):
##   UiManager.open_screen("pause")      UiManager.close_screen("pause")
##   UiManager.is_open("journal")        UiManager.any_screen_open()
##   The first screen to open remembers the game's state (paused, mouse,
##   crosshair, dialog) and hides the HUD; the last one to close puts it all
##   back exactly as it was. Opening the game over screen closes the rest.
##
## HUD - the crosshair, dialog, hints, stamina bar and inventory:
##   set_cursor_visible(bool)  set_cursor_hover(bool)   (hand vs crosshair)
##   hint(text)  say(text)  say_with_hint(text, hint)  say_lines(lines)
##   hide_dialog()  show_inventory(bool)  update_stamina(...)
##
## PANELS - minigame overlays (hotwire, gas intake, hood). Their scripts
## register them once, then anything can show/hide them by name:
##   register_panel("gas_intake", node)  show_panel("gas_intake", false)
##
## LOOK - every Control in the game uses res://Assets/UI/NoExitTheme.tres
## (set in Project Settings > GUI > Theme). Colours live below.

extends Node

signal screen_opened(id: String)
signal screen_closed(id: String)

## ---------------------------------------------------------------------
## Look
## ---------------------------------------------------------------------
const FONT_PATH := "res://Assets/Fonts/Perfect_DOS_VGA_437.ttf"
const THEME_PATH := "res://Assets/UI/NoExitTheme.tres"
## Panel borders, selections, bars.
const ACCENT := Color("#990404")
## Titles ("PAUSED", "END SHIFT", "Game Over").
const TITLE_COLOR := Color(0.537255, 0.0156863, 0.0156863, 1)
## Red text that has to be readable on black (hints, equipped item).
const ACCENT_TEXT := Color("#d42020")
const TEXT_COLOR := Color(0.9, 0.9, 0.9)
const BUTTON_HOVER := Color(0.517647, 0.458824, 0.458824, 1)
const PANEL_BG := Color(0.06, 0.06, 0.06, 0.97)

## Draw order of the UI layers (higher = on top).
const LAYER_HUD := 5
const LAYER_MENU := 50
const LAYER_GAME_OVER := 60
const LAYER_BRIGHTNESS := 120

## ---------------------------------------------------------------------
## Legacy
## ---------------------------------------------------------------------
## Old name for the hotwire panel - use show_panel("hotwire", ...).
var HotWireUI: Control:
	get: return get_panel("hotwire")
	set(value): register_panel("hotwire", value)

## ---------------------------------------------------------------------
## State
## ---------------------------------------------------------------------
var _screens: Array[String] = []          # open screens, last = on top
var _screen_opts: Dictionary = {}         # id -> {pauses, mouse}
var _saved: Dictionary = {}               # game state before the first screen
var _panels: Dictionary = {}              # id -> Control
var _cursor_wanted := true                # what gameplay asked for
var _scene_id := 0

var _hud: CanvasLayer
var _stamina_bar: Control
var _stamina_fill: ColorRect
var _stamina_alpha := 0.0
var _stamina_hide_timer := 0.0
var _inventory: PanelContainer
var _inventory_row: HBoxContainer
var _inventory_held := false        # Tab is down
var _inventory_peek := 0.0          # seconds left of a "you switched items" peek


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	# Z/X switching: update the strip right away (and flash it up if closed).
	PlayerManager.equipped_item_changed.connect(_on_equipped_item_changed)


func _process(delta: float) -> void:
	# New level: everything from the old one is gone, start clean.
	var scene := get_tree().current_scene
	var id := scene.get_instance_id() if scene else 0
	if id != _scene_id:
		_scene_id = id
		_reset_for_new_scene()
	_fade_stamina(delta)
	if _inventory_peek > 0.0:
		_inventory_peek -= delta
		if _inventory_peek <= 0.0 and not _inventory_held:
			_inventory.visible = false


## Called by the Player in its _ready(): a fresh level, a fresh player.
func on_player_ready(player: Node) -> void:
	PlayerManager.player = player
	var scene := get_tree().current_scene
	_scene_id = scene.get_instance_id() if scene else 0
	_reset_for_new_scene()
	set_cursor_visible(true)

func _reset_for_new_scene() -> void:
	_screens.clear()
	_screen_opts.clear()
	_saved.clear()
	for k in _panels.keys():
		if not is_instance_valid(_panels[k]):
			_panels.erase(k)
	show_inventory(false)
	_stamina_alpha = 0.0
	_hud.visible = true

## ---------------------------------------------------------------------
## Screens
## ---------------------------------------------------------------------

## Opens a full-screen UI. pauses = freeze the game; mouse = show the mouse
## (false hides it, e.g. while reading a note).
func open_screen(id: String, pauses: bool = true, mouse: bool = true) -> void:
	# Only the first screen remembers the game's state (re-opening one that's
	# already up must not overwrite it with the paused state).
	if _screens.is_empty():
		_save_game_state()
	_screens.erase(id)
	_screens.append(id)
	_screen_opts[id] = {"pauses": pauses, "mouse": mouse}
	show_inventory(false)
	_apply_screens()
	screen_opened.emit(id)

## Closes a screen; when the last one closes the game goes back to how it was.
func close_screen(id: String) -> void:
	if not id in _screens:
		return
	_screens.erase(id)
	_screen_opts.erase(id)
	if _screens.is_empty():
		_restore_game_state()
	else:
		_apply_screens()
	screen_closed.emit(id)

func is_open(id: String) -> bool:
	return id in _screens

func any_screen_open() -> bool:
	return not _screens.is_empty()

## The screen on top (the one getting input), or "".
func top_screen() -> String:
	return _screens.back() if not _screens.is_empty() else ""

## Can gameplay UI (journal, inventory) open right now?
func can_open_gameplay_ui() -> bool:
	if any_screen_open() or PlayerManager.MainMenu or not is_instance_valid(PlayerManager.player):
		return false
	return not (PlayerManager.dying or PlayerManager.examining or PlayerManager.MinigameMode or PlayerManager.InAnimation)

## The game over screen: closes every other screen and freezes the game.
func show_game_over() -> void:
	for s in _screens.duplicate():
		if s != "game_over":
			close_screen(s)
	var player = PlayerManager.player
	if player:
		player.GAMEOVER.layer = LAYER_GAME_OVER
		player.GAMEOVER.visible = true
	open_screen("game_over", true, true)
	_saved.clear()   # nothing to go back to

func _save_game_state() -> void:
	var player = PlayerManager.player
	_saved = {
		"paused": get_tree().paused,
		"mouse": Input.get_mouse_mode(),
		"dialog": is_instance_valid(player) and player.DIALOG.visible,
	}

func _apply_screens() -> void:
	var pauses := false
	for s in _screens:
		pauses = pauses or _screen_opts[s].pauses
	get_tree().paused = pauses
	var top: Dictionary = _screen_opts[top_screen()]
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if top.mouse else Input.MOUSE_MODE_HIDDEN)
	_apply_cursor()
	# Hide the dialog box (even mid-typing) - it comes back on close.
	if is_instance_valid(PlayerManager.player):
		PlayerManager.player.DIALOG.visible = false
	_hud.visible = false

func _restore_game_state() -> void:
	if _saved.is_empty():
		return
	get_tree().paused = _saved.paused
	Input.set_mouse_mode(_saved.mouse)
	_hud.visible = true
	_apply_cursor()
	if is_instance_valid(PlayerManager.player):
		PlayerManager.player.DIALOG.visible = _saved.dialog
	_saved.clear()

## ---------------------------------------------------------------------
## Crosshair
## ---------------------------------------------------------------------

## Show/hide the crosshair. Stays hidden while a screen is open or when the
## "hide cursor" dev setting is on, and comes back afterwards if wanted.
func set_cursor_visible(visible: bool) -> void:
	_cursor_wanted = visible
	_apply_cursor()

## Re-check the crosshair after the "show cursor" setting changes.
func refresh_cursor() -> void:
	_apply_cursor()

func is_cursor_wanted() -> bool:
	return _cursor_wanted

## true = the hand (aiming at something usable), false = the crosshair.
func set_cursor_hover(hand: bool) -> void:
	var player = PlayerManager.player
	if not is_instance_valid(player):
		return
	player._crosshair.visible = not hand
	player._hand.visible = hand

func _apply_cursor() -> void:
	var player = PlayerManager.player
	if not is_instance_valid(player) or player.CURSOR == null:
		return
	player.CURSOR.visible = _cursor_wanted and not PlayerManager.CursorInvisible and not any_screen_open()

## ---------------------------------------------------------------------
## Dialog
## ---------------------------------------------------------------------

func _dialog():
	var player = PlayerManager.player
	return player.DIALOG if is_instance_valid(player) else null

## Red hint text at the top of the screen.
func hint(text: String, duration: float = 10.0) -> void:
	var d = _dialog()
	if d:
		d.show_temporary_dialog("Hint: " + text, duration, "red")

## Plain line of dialog (no panel).
func say_plain(text: String) -> void:
	var d = _dialog()
	if d:
		PlayerManager.hint = false
		d.player_interact_dialog(text)

## A line of dialog in the character panel.
func say(text: String) -> void:
	var d = _dialog()
	if d:
		PlayerManager.hint = false
		d.player_interact_dialog_pic(text)

## A line of dialog plus a hint at the top.
func say_with_hint(text: String, hint_text: String) -> void:
	var d = _dialog()
	if d:
		PlayerManager.hint = true
		d.player_interact_dialog_pic_and_hint(text, hint_text)

## Several lines, clicked through one at a time.
func say_lines(lines: Array[String]) -> void:
	var d = _dialog()
	if d:
		d.player_interact_multi_dialog_pic(lines)

func next_line() -> void:
	var d = _dialog()
	if d:
		d.show_next_dialog()

func hide_dialog() -> void:
	var d = _dialog()
	if d == null:
		return
	if d.timer:
		d.timer.stop()
	if PlayerManager.finishedDialogAnimation:
		d.animation_player.play("hide")
	PlayerManager.finishedDialogAnimation = false

func reveal_dialog() -> void:
	var d = _dialog()
	if d == null:
		return
	d.visible = true
	d.animation_player.play("reveal")
	PlayerManager.finishedDialogAnimation = true

## ---------------------------------------------------------------------
## Minigame panels
## ---------------------------------------------------------------------

func register_panel(id: String, panel: Control) -> void:
	if panel:
		_panels[id] = panel

func get_panel(id: String) -> Control:
	var p = _panels.get(id)
	return p if is_instance_valid(p) else null

func show_panel(id: String, visible: bool) -> void:
	var p := get_panel(id)
	if p:
		p.visible = visible

func hide_all_panels() -> void:
	for id in _panels:
		show_panel(id, false)

## ---------------------------------------------------------------------
## HUD: inventory + stamina (built here so they share the game's look)
## ---------------------------------------------------------------------

## Shows the inventory strip (Tab). Ignored while a screen is open.
func show_inventory(visible: bool) -> void:
	if _inventory == null:
		return
	_inventory_held = visible
	_inventory_peek = 0.0
	if visible and any_screen_open():
		visible = false
	_inventory.visible = visible
	if visible:
		_fill_inventory()

## Equipped item changed (Z/X, picking something up): redraw the strip if
## it's open. (Pickups don't pop it open - only an actual Z/X switch does.)
func _on_equipped_item_changed(_item_name: String) -> void:
	if _inventory and _inventory.visible:
		_fill_inventory()

## The player pressed Z/X: show the strip for a moment so the switch is
## visible (or just refresh it if Tab is already holding it open).
func on_item_switched() -> void:
	if _inventory == null:
		return
	if _inventory.visible:
		_fill_inventory()
	elif not any_screen_open() and is_instance_valid(PlayerManager.player):
		_inventory.visible = true
		_fill_inventory()
		_inventory_peek = 1.5

## Redraw the inventory if it's showing (after picking up / switching items).
func refresh_inventory() -> void:
	if _inventory and _inventory.visible:
		_fill_inventory()

func _fill_inventory() -> void:
	for c in _inventory_row.get_children():
		c.queue_free()
	if PlayerManager.Inventory.is_empty():
		var empty := Label.new()
		empty.text = "Inventory empty"
		empty.add_theme_color_override("font_color", BUTTON_HOVER)
		_inventory_row.add_child(empty)
		return
	for item in PlayerManager.Inventory:
		var label := Label.new()
		var equipped: bool = item.name == PlayerManager.EquippedItem
		label.text = ("[%s]" if equipped else " %s ") % item.name
		label.add_theme_color_override("font_color", ACCENT_TEXT if equipped else TEXT_COLOR)
		_inventory_row.add_child(label)

## Called by the Player every frame. ratio 0-1; red while fatigued; fades
## out a moment after it's full.
func update_stamina(ratio: float, fatigued: bool, in_use: bool, enabled: bool) -> void:
	if _stamina_fill == null:
		return
	ratio = clampf(ratio, 0.0, 1.0)
	_stamina_fill.anchor_right = ratio
	_stamina_fill.offset_right = -1.0 if ratio >= 1.0 else 0.0
	_stamina_fill.color = ACCENT if fatigued else Color(0.85, 0.85, 0.85)
	if in_use:
		_stamina_hide_timer = 1.5
	_stamina_bar.set_meta("enabled", enabled)

func _fade_stamina(delta: float) -> void:
	if _stamina_bar == null:
		return
	_stamina_hide_timer = maxf(_stamina_hide_timer - delta, 0.0)
	var enabled: bool = _stamina_bar.get_meta("enabled", true)
	var target := 1.0 if _stamina_hide_timer > 0.0 and enabled and is_instance_valid(PlayerManager.player) else 0.0
	_stamina_alpha = move_toward(_stamina_alpha, target, delta * 3.0)
	_stamina_bar.modulate.a = _stamina_alpha

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "HUD"
	_hud.layer = LAYER_HUD
	add_child(_hud)

	# Stamina: small bar in the top-left corner, clear of the dialog box.
	_stamina_bar = Control.new()
	_stamina_bar.name = "StaminaBar"
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bar.offset_left = 16.0
	_stamina_bar.offset_top = 16.0
	_stamina_bar.offset_right = 136.0
	_stamina_bar.offset_bottom = 22.0
	_stamina_bar.modulate.a = 0.0
	_hud.add_child(_stamina_bar)
	var back := ColorRect.new()
	back.color = Color(1, 1, 1, 0.15)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stamina_bar.add_child(back)
	_stamina_fill = ColorRect.new()
	_stamina_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_fill.anchor_bottom = 1.0
	_stamina_fill.offset_left = 1.0
	_stamina_fill.offset_top = 1.0
	_stamina_fill.offset_bottom = -1.0
	_stamina_bar.add_child(_stamina_fill)

	# Inventory: a panel across the top centre, like the dialog box.
	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_top", 84)   # below the hint line
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(top)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(center)
	_inventory = PanelContainer.new()
	_inventory.name = "Inventory"
	_inventory.theme_type_variation = "FramePanel"
	_inventory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory.visible = false
	center.add_child(_inventory)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	_inventory.add_child(inner)
	var title := Label.new()
	title.text = "INVENTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", ACCENT_TEXT)
	inner.add_child(title)
	_inventory_row = HBoxContainer.new()
	_inventory_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_inventory_row.add_theme_constant_override("separation", 10)
	inner.add_child(_inventory_row)
	var tip := Label.new()
	tip.text = "[Z/X] Switch item"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_color_override("font_color", BUTTON_HOVER)
	tip.add_theme_font_size_override("font_size", 12)
	inner.add_child(tip)

## ---------------------------------------------------------------------
## Theme (the file is generated once; edit the .tres in the editor after)
## ---------------------------------------------------------------------

static func build_theme() -> Theme:
	var t := Theme.new()
	var font: Font = load(FONT_PATH)
	t.default_font = font
	t.default_font_size = 16

	for type in ["Label", "RichTextLabel"]:
		t.set_color("font_color", type, TEXT_COLOR)
	t.set_color("default_color", "RichTextLabel", TEXT_COLOR)
	t.set_font("normal_font", "RichTextLabel", font)

	# Titles: Label with theme_type_variation = "TitleLabel"
	t.add_type("TitleLabel")
	t.set_type_variation("TitleLabel", "Label")
	t.set_color("font_color", "TitleLabel", TITLE_COLOR)
	t.set_font_size("font_size", "TitleLabel", 64)

	# Buttons: text only, like the menus.
	for type in ["Button", "CheckBox", "CheckButton", "OptionButton", "MenuButton"]:
		t.set_color("font_color", type, Color(0.875, 0.875, 0.875))
		t.set_color("font_hover_color", type, BUTTON_HOVER)
		t.set_color("font_pressed_color", type, TITLE_COLOR)
		t.set_color("font_focus_color", type, Color(0.875, 0.875, 0.875))
		t.set_color("font_hover_pressed_color", type, TITLE_COLOR)
	# A ticked checkbox keeps normal text (pressed red is for click feedback).
	for type in ["CheckBox", "CheckButton"]:
		t.set_color("font_pressed_color", type, Color(0.875, 0.875, 0.875))
		t.set_color("font_hover_pressed_color", type, BUTTON_HOVER)
	for style in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		t.set_stylebox(style, "Button", StyleBoxEmpty.new())

	# Boxes: dark with the red border. Panel (the dialog box) gets it by
	# default; PanelContainers are invisible (full-screen menus) unless they
	# use the "FramePanel" variation (inventory, any new boxed UI).
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL_BG
	panel.border_color = ACCENT
	panel.set_border_width_all(2)
	panel.set_content_margin_all(12)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	t.add_type("FramePanel")
	t.set_type_variation("FramePanel", "PanelContainer")
	t.set_stylebox("panel", "FramePanel", panel)

	# Lists (journal)
	var sel := StyleBoxFlat.new()
	sel.bg_color = ACCENT
	t.set_stylebox("selected", "ItemList", sel)
	t.set_stylebox("selected_focus", "ItemList", sel)
	t.set_stylebox("panel", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_color("font_color", "ItemList", TEXT_COLOR)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)

	# Progress bars (gas minigame etc.)
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(1, 1, 1, 0.15)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = ACCENT
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	return t
