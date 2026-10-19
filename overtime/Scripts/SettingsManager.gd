## No Exit
## Overtime Studios
## Last updated 10/18/26 by Justin Ferreira
## Settings Manager Script
## - Every setting is ONE line in DEFS below. The settings menu builds
##   itself from that list, so adding a setting is:
##     1. add a line to DEFS
##     2. add what it does to _apply() (one `match` case)
## - Saves to user://settings.cfg (same file and keys as before, so old
##   saves still load).
##
## Reading a setting anywhere:  SettingsManager.get_value("video/fov")
## Changing one from code:      SettingsManager.set_value("video/fov", 90)

extends Node

## Emitted after any setting changes (key like "audio/muted").
signal setting_changed(key: String, value: Variant)

enum Type { SLIDER, TOGGLE, OPTION }

## The settings menu tabs, in order.
const TABS: Array[String] = ["VOLUME", "VISUAL", "GAME"]

## ---------------------------------------------------------------------
## Every setting in the game. One line each:
##   _slider(key, tab, label, default, min, max, suffix)
##   _toggle(key, tab, label, default)
##   _option(key, tab, label, default_index, [choices])
## Add `dev_only = true` with _dev() to hide it from players.
## ---------------------------------------------------------------------
var DEFS: Array[Dictionary] = [
	_slider("audio/master_volume", "VOLUME", "Master Volume", 100, 0, 100, "%"),
	_slider("audio/music_volume", "VOLUME", "Music Volume", 100, 0, 100, "%"),
	_slider("audio/sfx_volume", "VOLUME", "SFX Volume", 100, 0, 100, "%"),
	_toggle("audio/muted", "VOLUME", "Mute", false),

	_option("video/window_mode", "VISUAL", "Window", 1, ["Windowed", "Fullscreen", "Exclusive"]),
	_toggle("video/vsync", "VISUAL", "VSync", true),
	_option("video/max_fps", "VISUAL", "FPS Limit", 0, ["Unlimited", "30", "60", "120", "144"]),
	_slider("video/brightness", "VISUAL", "Brightness", 100, 50, 150, "%"),
	_slider("video/fov", "VISUAL", "Field of View", 75, 60, 100, ""),
	_toggle("video/shader", "VISUAL", "PS1 Filter", true),

	_slider("game/mouse_sensitivity", "GAME", "Mouse Sensitivity", 19, 1, 100, "%"),
	_toggle("game/invert_y", "GAME", "Invert Mouse Y", false),
	_toggle("game/hold_shift", "GAME", "Hold Shift To Sprint", false),
	_toggle("game/crouch_toggle", "GAME", "Toggle Crouch", false),
	_toggle("game/headbob", "GAME", "Head Bob", true),
	_toggle("game/lean_tilt", "GAME", "Tilt View When Leaning", true),
	_toggle("game/show_crosshair", "GAME", "Show Crosshair", true),
	_toggle("game/show_stamina", "GAME", "Show Stamina Bar", true),
	_option("game/dialog_speed", "GAME", "Text Speed", 1, ["Slow", "Normal", "Fast", "Very Fast"]),
	_dev(_toggle("game/dev_mode", "GAME", "Dev Mode", false)),
]

## Seconds between dialog letters for each Text Speed choice.
const DIALOG_SPEEDS: Array[float] = [0.08, 0.05, 0.025, 0.01]
const FPS_LIMITS: Array[int] = [0, 30, 60, 120, 144]
## Mouse Sensitivity 1-100% maps onto this raw range.
const MIN_SENSITIVITY: float = 0.001
const MAX_SENSITIVITY: float = 0.05

const SETTINGS_PATH := "user://settings.cfg"
## Wait this long after the last change before writing the file, so
## dragging a slider doesn't write it every frame.
const SAVE_DELAY := 0.5

## Not settings - other managers set these. Loop progress is saved here
## until it moves to a real save file.
var KillerDisabled: bool = false
var Loop0Pass: bool = false
var Loop1Pass: bool = false
var MainMenuShader: ColorRect
var PlayerShader: CanvasLayer

# Old names kept for scripts that used them.
var min_sensitivity: float = MIN_SENSITIVITY
var max_sensitivity: float = MAX_SENSITIVITY

# "section/key" -> current value
var _values: Dictionary = {}
var _defs_by_key: Dictionary = {}
var _config := ConfigFile.new()
var _save_timer: Timer
var _brightness_layer: CanvasLayer
var _brightness_rect: ColorRect

## Old code reads e.g. SettingsManager.settings.video.shader - this builds
## that nested shape from the current values. Read-only: use set_value().
var settings: Dictionary:
	get:
		var nested := {}
		for key in _values:
			var parts: PackedStringArray = key.split("/")
			if not nested.has(parts[0]):
				nested[parts[0]] = {}
			nested[parts[0]][parts[1]] = _values[key]
		return nested


func _ready() -> void:
	for def in DEFS:
		_defs_by_key[def.key] = def
		_values[def.key] = def.default
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(save_settings)
	add_child(_save_timer)
	_build_brightness_layer()
	load_settings()


## ---------------------------------------------------------------------
## Reading / changing settings
## ---------------------------------------------------------------------

func get_value(key: String) -> Variant:
	return _values.get(key)

func set_value(key: String, value: Variant) -> void:
	if not _defs_by_key.has(key):
		push_warning("SettingsManager: unknown setting '%s'." % key)
		return
	value = _clean(_defs_by_key[key], value)
	if _values.get(key) == value:
		return
	_values[key] = value
	_apply(key)
	setting_changed.emit(key, value)
	_save_timer.start()   # saves shortly after the last change

## Settings for one menu tab (dev-only ones only in debug builds).
func get_defs_for_tab(tab: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for def in DEFS:
		if def.tab == tab and (not def.dev_only or OS.is_debug_build()):
			result.append(def)
	return result

func reset_tab(tab: String) -> void:
	for def in get_defs_for_tab(tab):
		set_value(def.key, def.default)


## ---------------------------------------------------------------------
## Save / load
## ---------------------------------------------------------------------

func save_settings() -> void:
	_save_timer.stop()
	for key in _values:
		var parts: PackedStringArray = key.split("/")
		_config.set_value(parts[0], parts[1], _values[key])
	_config.set_value("loops", "loop0", Loop0Pass)
	_config.set_value("loops", "loop1", Loop1Pass)
	_config.save(SETTINGS_PATH)

func load_settings() -> void:
	if _config.load(SETTINGS_PATH) == OK:
		for key in _values:
			var parts: PackedStringArray = key.split("/")
			if _config.has_section_key(parts[0], parts[1]):
				_values[key] = _clean(_defs_by_key[key], _config.get_value(parts[0], parts[1]))
		_migrate_old_settings()
		Loop0Pass = _config.get_value("loops", "loop0", false)
		Loop1Pass = _config.get_value("loops", "loop1", false)
	apply_settings()

## Applies every setting (on start, and for old code that calls this).
func apply_settings() -> void:
	for key in _values:
		_apply(key)

## Player-side settings. The Player calls this when it spawns, since a new
## Player is made every level.
func apply_player_settings(player) -> void:
	for key in ["video/fov", "game/crouch_toggle", "game/lean_tilt", "game/show_crosshair",
			"game/show_stamina", "game/dialog_speed", "video/shader"]:
		_apply(key, player)


# Settings saved by older versions of the game.
func _migrate_old_settings() -> void:
	if _config.has_section_key("video", "fullscreen") and not _config.has_section_key("video", "window_mode"):
		_values["video/window_mode"] = 1 if _config.get_value("video", "fullscreen") else 0
	if _config.has_section_key("game", "sensitivity") and not _config.has_section_key("game", "mouse_sensitivity"):
		var raw: float = _config.get_value("game", "sensitivity")
		_values["game/mouse_sensitivity"] = clampf(round(inverse_lerp(MIN_SENSITIVITY, MAX_SENSITIVITY, raw) * 100.0), 1, 100)


## ---------------------------------------------------------------------
## What each setting does. One case per setting key.
## ---------------------------------------------------------------------

func _apply(key: String, player = null) -> void:
	var v = _values[key]
	if player == null:
		player = PlayerManager.player if is_instance_valid(PlayerManager.player) else null
	match key:
		"audio/master_volume":
			_set_bus_volume("Master", v)
		"audio/music_volume":
			_set_bus_volume("Music", v)
		"audio/sfx_volume":
			_set_bus_volume("SFX", v)
		"audio/muted":
			AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), v)

		"video/window_mode":
			var modes := [Window.MODE_WINDOWED, Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
			if get_window().mode != modes[v]:
				get_window().mode = modes[v]
		"video/vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v else DisplayServer.VSYNC_DISABLED)
		"video/max_fps":
			Engine.max_fps = FPS_LIMITS[v]
		"video/brightness":
			_brightness_rect.material.set_shader_parameter("brightness", v / 100.0)
			_brightness_layer.visible = not is_equal_approx(v, 100.0)
		"video/fov":
			if player:
				player.camera.fov = v
		"video/shader":
			if PlayerShader and is_instance_valid(PlayerShader):
				PlayerShader.visible = v
			if MainMenuShader and is_instance_valid(MainMenuShader):
				MainMenuShader.visible = v

		"game/mouse_sensitivity":
			PlayerManager.Sensitivity = lerpf(MIN_SENSITIVITY, MAX_SENSITIVITY, v / 100.0)
		"game/invert_y":
			PlayerManager.InvertY = v
		"game/hold_shift":
			PlayerManager.Hold_Shift = v
		"game/crouch_toggle":
			if player:
				player.crouch_toggle = v
		"game/headbob":
			PlayerManager.HeadBob = v
		"game/lean_tilt":
			if player:
				player.lean_tilt_enabled = v
		"game/show_crosshair":
			PlayerManager.CursorInvisible = not v
			if player and not v:
				player.CURSOR.visible = false
			elif player and not (PlayerManager.examining or PlayerManager.InAnimation or PlayerManager.MinigameMode):
				player.CURSOR.visible = true
		"game/show_stamina":
			if player:
				player.show_stamina_bar = v
		"game/dialog_speed":
			if player:
				player.DIALOG.typewriter_speed = DIALOG_SPEEDS[v]
		"game/dev_mode":
			PlayerManager.DevMode = v


## ---------------------------------------------------------------------
## Helpers
## ---------------------------------------------------------------------

static func _slider(key: String, tab: String, label: String, default: float, min_v: float, max_v: float, suffix: String) -> Dictionary:
	return {key = key, tab = tab, label = label, type = Type.SLIDER, default = default,
		min = min_v, max = max_v, suffix = suffix, dev_only = false}

static func _toggle(key: String, tab: String, label: String, default: bool) -> Dictionary:
	return {key = key, tab = tab, label = label, type = Type.TOGGLE, default = default, dev_only = false}

static func _option(key: String, tab: String, label: String, default: int, choices: Array) -> Dictionary:
	return {key = key, tab = tab, label = label, type = Type.OPTION, default = default,
		choices = choices, dev_only = false}

static func _dev(def: Dictionary) -> Dictionary:
	def.dev_only = true
	return def

# Makes a loaded/assigned value the right type and in range.
func _clean(def: Dictionary, value: Variant) -> Variant:
	match def.type:
		Type.SLIDER:
			return clampf(float(value), def.min, def.max)
		Type.TOGGLE:
			return bool(value)
		Type.OPTION:
			return clampi(int(value), 0, def.choices.size() - 1)
	return value

func _set_bus_volume(bus: String, percent: float) -> void:
	# percent / 100.0 (not / 100) - integer division turned 50 into 0 = silent.
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(percent / 100.0))

# Full-screen pass that brightens/darkens everything (only shown when
# Brightness isn't 100%).
func _build_brightness_layer() -> void:
	_brightness_layer = CanvasLayer.new()
	_brightness_layer.layer = 120
	_brightness_layer.visible = false
	add_child(_brightness_layer)
	_brightness_rect = ColorRect.new()
	_brightness_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_brightness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://Assets/Shaders/Brightness.gdshader")
	_brightness_rect.material = mat
	_brightness_layer.add_child(_brightness_rect)
