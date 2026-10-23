##No Exit
## Overtime Studios
## Last updated 10/18/26 by Justin Ferreira
## Settings Menu Script
## - Builds its rows from SettingsManager.DEFS - nothing to edit here when
##   adding a setting.
## - Rows are copies of the slider / checkbox already in this scene, so they
##   keep the red/black folder look. Restyle those in the scene and every
##   row follows.

extends Control

const TAB_PATH := "CenterContainer/ColorRect/TabContainer"
# Where each tab's rows go (the VBoxes already in the scene).
const TAB_VBOXES := {
	"VOLUME": "VOLUME/SoundSettingsVbox",
	"VISUAL": "VISUAL/VisualSettingsVbox",
	"GAME": "GAME/GameSettingsVbox",
}
const MUTED_COLOR := Color.RED
const ACCENT := Color(0.6, 0.0156863, 0.0156863)
# Brighter red for clickable text - ACCENT is too dark to read on black.
const ACCENT_TEXT := Color("#d42020")

@onready var tabs: TabContainer = get_node(TAB_PATH)

# Templates copied from the scene's own Master Volume block and Mute box.
var _slider_template: Control
var _toggle_template: CheckBox
var _font: Font
# setting key -> the control showing it
var _widgets: Dictionary = {}
var _option_labels: Dictionary = {}


func _ready() -> void:
	_take_templates()
	for tab in SettingsManager.TABS:
		_build_tab(tab)
	# Templates were only needed to build the rows.
	_slider_template.free()
	_toggle_template.free()
	SettingsManager.setting_changed.connect(_on_setting_changed)
	_refresh_mute_state()
	_center()
	get_viewport().size_changed.connect(_center)
	visibility_changed.connect(_on_visibility_changed)


func _input(event: InputEvent) -> void:
	if visible and is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


# Close (X) button - connected in the scene.
func _on_button_pressed() -> void:
	_close()

func _close() -> void:
	AudioManager.play_sound(AudioManager.GetKeyPress())
	SettingsManager.save_settings()
	visible = false

func _on_visibility_changed() -> void:
	if not visible:
		SettingsManager.save_settings()

func _on_tab_container_tab_clicked(_tab: int) -> void:
	AudioManager.play_sound(AudioManager.GetKeyPress())


## ---------------------------------------------------------------------
## Building rows
## ---------------------------------------------------------------------

func _take_templates() -> void:
	var volume_box := tabs.get_node(TAB_VBOXES.VOLUME)
	# Copy without signal connections - the old per-slider handlers are gone.
	var flags := Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION
	_slider_template = volume_box.get_node("MasterVbox").duplicate(flags)
	_toggle_template = volume_box.get_node("MuteCheckBox").duplicate(flags)
	_font = _toggle_template.get_theme_font("font")
	# Clear the hand-made rows; they're rebuilt from SettingsManager.DEFS.
	for tab in TAB_VBOXES.values():
		for child in tabs.get_node(tab).get_children():
			child.get_parent().remove_child(child)
			child.queue_free()


func _build_tab(tab: String) -> void:
	var box: VBoxContainer = tabs.get_node(TAB_VBOXES[tab])
	box.add_theme_constant_override("separation", 6)
	_wrap_in_scroll(box)
	var top_gap := Control.new()
	top_gap.custom_minimum_size.y = 6
	box.add_child(top_gap)

	for def in SettingsManager.get_defs_for_tab(tab):
		match def.type:
			SettingsManager.Type.SLIDER:
				box.add_child(_make_slider(def))
			SettingsManager.Type.TOGGLE:
				box.add_child(_make_toggle(def))
			SettingsManager.Type.OPTION:
				box.add_child(_make_option(def))

	var reset := _make_text_button("Reset To Defaults")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func():
		AudioManager.play_sound(AudioManager.GetKeyPress())
		SettingsManager.reset_tab(tab))
	box.add_child(reset)


func _make_slider(def: Dictionary) -> Control:
	var row := _slider_template.duplicate()
	# The scene's spacer above each slider is taller than needed - drop it,
	# and move the bar sprite (placed by hand, not by the layout) up to match.
	var removed := 0.0
	for child in row.get_children():
		if child is MarginContainer:
			removed = maxf(child.custom_minimum_size.y,
				child.get_theme_constant("margin_top") + child.get_theme_constant("margin_bottom"))
			removed += row.get_theme_constant("separation")
			row.remove_child(child)
			child.queue_free()
	for child in row.get_children():
		if child is Node2D:
			child.position.y -= removed
	for child in row.get_children():
		if child is Label and child.get_script() == null:
			child.text = def.label
		elif child is HSlider:
			var slider: HSlider = child
			slider.min_value = def.min
			slider.max_value = def.max
			slider.step = 1
			slider.set_value_no_signal(SettingsManager.get_value(def.key))
			slider.value_changed.connect(func(v):
				SettingsManager.set_value(def.key, v)
				AudioManager.play_sound(AudioManager.GetKeyPress()))
			_widgets[def.key] = slider
		elif child is Label:   # the number under the bar (SettingsLabel.gd)
			child.suffix = def.suffix
	return row


func _make_toggle(def: Dictionary) -> CheckBox:
	var box: CheckBox = _toggle_template.duplicate()
	box.text = def.label
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.set_pressed_no_signal(SettingsManager.get_value(def.key))
	box.toggled.connect(func(on):
		AudioManager.play_sound(AudioManager.GetKeyPress())
		SettingsManager.set_value(def.key, on))
	_widgets[def.key] = box
	return box


# "Label:  < Choice >" - click the arrows to cycle through the choices.
func _make_option(def: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation", 6)
	row.add_child(_make_label(def.label + ":"))
	var left := _make_text_button("<")
	row.add_child(left)
	var value_label := _make_label("")
	value_label.custom_minimum_size.x = 150
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	var right := _make_text_button(">")
	row.add_child(right)
	_option_labels[def.key] = value_label
	_show_option(def.key)
	var count: int = def.choices.size()
	left.pressed.connect(func():
		AudioManager.play_sound(AudioManager.GetKeyPress())
		SettingsManager.set_value(def.key, posmod(SettingsManager.get_value(def.key) - 1, count)))
	right.pressed.connect(func():
		AudioManager.play_sound(AudioManager.GetKeyPress())
		SettingsManager.set_value(def.key, posmod(SettingsManager.get_value(def.key) + 1, count)))
	return row


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 25)
	return label

func _make_text_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", ACCENT_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	return button


# Puts a tab's VBox in a ScrollContainer at the same spot, so tabs with
# lots of settings scroll instead of running off the folder.
func _wrap_in_scroll(box: VBoxContainer) -> void:
	var tab := box.get_parent()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# The built-in bar would sit on the right - hide it and use our own on
	# the left instead (mouse wheel still scrolls).
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# Fill the tab's full height, so tabs that only just fit don't scroll.
	scroll.anchor_bottom = 1.0
	scroll.offset_left = box.position.x
	scroll.offset_top = box.position.y
	scroll.offset_right = box.position.x + box.size.x
	scroll.offset_bottom = -6
	tab.remove_child(box)
	tab.add_child(scroll)
	scroll.add_child(box)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size.x = 413

	# Scroll bar on the left, kept in sync with the hidden built-in one.
	var bar := VScrollBar.new()
	bar.custom_minimum_size.x = 0
	# Shorter than the list and centred beside it.
	var bar_height := 260.0
	bar.anchor_top = 0.5
	bar.anchor_bottom = 0.5
	bar.offset_left = box.position.x - 14
	bar.offset_right = box.position.x - 9
	bar.offset_top = -bar_height / 2.0 + box.position.y / 2.0
	bar.offset_bottom = bar_height / 2.0 + box.position.y / 2.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.1, 0, 0)
	# Same red as the folder's tabs and borders.
	var grab := StyleBoxFlat.new()
	grab.bg_color = ACCENT
	# Fixed handle length (top + bottom margin) - with page = 0 below, the
	# handle stays this size and travels the whole bar.
	grab.content_margin_top = 12
	grab.content_margin_bottom = 12
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab)
	bar.add_theme_stylebox_override("grabber_pressed", grab)
	tab.add_child(bar)

	var inner := scroll.get_v_scroll_bar()
	var sync := func():
		# Range = how far the list can actually scroll, and no "page", so
		# the top of the bar is the top of the list and the bottom of the
		# bar is the bottom of the list.
		bar.max_value = maxf(inner.max_value - inner.page, 0.0)
		bar.page = 0
		bar.set_value_no_signal(inner.value)
		# Only show it when there's something to scroll.
		bar.visible = inner.max_value - inner.page > 8.0
	inner.changed.connect(sync)
	inner.value_changed.connect(func(_v): sync.call())
	bar.value_changed.connect(func(v): scroll.scroll_vertical = int(v))


## ---------------------------------------------------------------------
## Keeping rows in sync
## ---------------------------------------------------------------------

# A setting changed (from this menu, Reset, or code) - update its row
# without firing its signal again.
func _on_setting_changed(key: String, value: Variant) -> void:
	var widget = _widgets.get(key)
	if widget is HSlider and widget.value != value:
		widget.set_value_no_signal(value)
		_refresh_slider_visuals(widget)
	elif widget is CheckBox and widget.button_pressed != value:
		widget.set_pressed_no_signal(value)
	if _option_labels.has(key):
		_show_option(key)
	if key == "audio/muted":
		_refresh_mute_state()

# The bar sprite and number listen to value_changed, which
# set_value_no_signal skips - poke them directly.
func _refresh_slider_visuals(slider: HSlider) -> void:
	for sibling in slider.get_parent().get_children():
		if sibling.has_method("update_sprite"):
			sibling.update_sprite(slider.value)
		elif sibling.has_method("update_text"):
			sibling.update_text(slider.value)

func _show_option(key: String) -> void:
	var def: Dictionary = SettingsManager._defs_by_key[key]
	_option_labels[key].text = def.choices[SettingsManager.get_value(key)]

# Muted: volume sliders locked and the Mute box red (also right on open).
func _refresh_mute_state() -> void:
	var muted: bool = SettingsManager.get_value("audio/muted")
	for key in ["audio/master_volume", "audio/music_volume", "audio/sfx_volume"]:
		if _widgets.has(key):
			_widgets[key].editable = not muted
	var mute_box = _widgets.get("audio/muted")
	if mute_box:
		if muted:
			mute_box.add_theme_color_override("font_color", MUTED_COLOR)
		else:
			mute_box.remove_theme_color_override("font_color")


# Keep the folder centered on wide windows.
func _center() -> void:
	var view := get_viewport_rect().size
	var shown := size * scale
	position = ((view - shown) / 2.0).floor()
