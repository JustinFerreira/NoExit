## No Exit
## Overtime Studios
## Last updated 10/18/26 by Justin Ferreira
## Journal Script (autoload)
## - Shows notes on screen:
##     * read_note(note)  - a single note, when the player clicks a NoteItem
##     * the journal      - J opens a list of every note found so far
## - Pauses the game while open. Click, J or Esc closes it.
## - Which notes were found lives in GameState (has_note / get_found_notes).
## - UI is built in code, styled like the dialog box.

extends CanvasLayer

signal opened
signal closed

## Pause the game while a note / the journal is open.
@export var pause_while_open: bool = true

const FONT_PATH := "res://Assets/Fonts/Perfect_DOS_VGA_437.ttf"
const ACCENT := Color("#990404")
# Brighter red for text - ACCENT is too dark to read on black.
const ACCENT_TEXT := Color("#d42020")
const TEXT_COLOR := Color(0.9, 0.9, 0.9)

enum Mode { CLOSED, READING, JOURNAL }
var _mode: Mode = Mode.CLOSED
var _shown_notes: Array[NoteData] = []

var _root: Control
var _list_box: Control
var _list: ItemList
var _title: Label
var _body: RichTextLabel
var _hint: Label
var _found_label: Label


func _ready() -> void:
	layer = UiManager.LAYER_MENU
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false


func is_open() -> bool:
	return _mode != Mode.CLOSED


## Shows one note full screen. first_time adds a "added to journal" line.
func read_note(note: NoteData, first_time: bool = false) -> void:
	if note == null:
		return
	_open(Mode.READING)
	_list_box.visible = false
	_show_note(note)
	_found_label.visible = first_time
	_hint.text = "[Click] Close"


## Opens the journal with every note found so far.
func open_journal() -> void:
	# Never on top of another screen (pause menu, game over).
	if UiManager.any_screen_open() and not UiManager.is_open("journal"):
		return
	_open(Mode.JOURNAL)
	_list_box.visible = true
	_found_label.visible = false
	_hint.text = "[J] Close"
	_list.clear()
	_shown_notes = GameState.get_found_notes()
	if _shown_notes.is_empty():
		_title.text = "Journal"
		_body.text = "You haven't found any notes yet."
		return
	for note in _shown_notes:
		_list.add_item(note.title)
	# Newest first is usually what the player wants to re-read.
	var last := _shown_notes.size() - 1
	_list.select(last)
	_list.ensure_current_is_visible()
	_show_note(_shown_notes[last])


func close() -> void:
	if _mode == Mode.CLOSED:
		return
	_mode = Mode.CLOSED
	_root.visible = false
	UiManager.close_screen("journal")   # puts pause/mouse/HUD back
	closed.emit()


func _input(event: InputEvent) -> void:
	if _mode == Mode.CLOSED:
		if event.is_action_pressed("journal") and _can_open_journal():
			open_journal()
			get_viewport().set_input_as_handled()
		return

	var close_it := event.is_action_pressed("journal") or event.is_action_pressed("ui_cancel")
	# A click closes a single note; in the journal clicks pick from the list.
	if _mode == Mode.READING and event.is_action_pressed("Interact"):
		close_it = true
	if close_it:
		close()
	# Nothing behind the journal (pause menu, player) gets input while open.
	if not (event is InputEventMouseButton and _mode == Mode.JOURNAL):
		get_viewport().set_input_as_handled()


func _can_open_journal() -> bool:
	return UiManager.can_open_gameplay_ui()


func _open(mode: Mode) -> void:
	var first := _mode == Mode.CLOSED
	_mode = mode
	_root.visible = true
	# UiManager pauses, hides the HUD/dialog and shows the mouse (hidden
	# while just reading a note), and restores it all on close.
	UiManager.open_screen("journal", pause_while_open, mode == Mode.JOURNAL)
	if first:
		opened.emit()


func _show_note(note: NoteData) -> void:
	_title.text = note.title
	# The DOS font has no glyph for an empty line and draws a box instead,
	# so give blank lines a space.
	var lines := note.text.split("\n")
	for i in lines.size():
		if lines[i].strip_edges() == "":
			lines[i] = " "
	_body.text = "\n".join(lines)
	_body.scroll_to_line(0)


func _on_list_selected(index: int) -> void:
	if index >= 0 and index < _shown_notes.size():
		_show_note(_shown_notes[index])


## ---------------------------------------------------------------------
## UI
## ---------------------------------------------------------------------

func _build_ui() -> void:
	var font: Font = load(FONT_PATH)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	_root.add_child(margin)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.06, 0.97)
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	outer.add_child(columns)

	# Left: list of found notes (journal only)
	_list_box = VBoxContainer.new()
	_list_box.custom_minimum_size.x = 170
	columns.add_child(_list_box)
	_list_box.add_child(_make_label("JOURNAL", font, ACCENT_TEXT))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_override("font", font)
	_list.add_theme_font_size_override("font_size", 16)
	_list.add_theme_color_override("font_color", TEXT_COLOR)
	_list.add_theme_color_override("font_selected_color", Color.WHITE)
	var sel := StyleBoxFlat.new()
	sel.bg_color = ACCENT
	_list.add_theme_stylebox_override("selected", sel)
	_list.add_theme_stylebox_override("selected_focus", sel)
	_list.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_list.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_list.item_selected.connect(_on_list_selected)
	_list_box.add_child(_list)

	# Right: the note
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	columns.add_child(page)
	_title = _make_label("", font, ACCENT_TEXT)
	page.add_child(_title)
	_body = RichTextLabel.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.scroll_active = true
	_body.add_theme_font_override("normal_font", font)
	_body.add_theme_font_size_override("normal_font_size", 16)
	_body.add_theme_color_override("default_color", TEXT_COLOR)
	page.add_child(_body)

	# Bottom line
	var footer := HBoxContainer.new()
	outer.add_child(footer)
	_found_label = _make_label("Added to your journal (J)", font, ACCENT_TEXT)
	_found_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_found_label)
	_hint = _make_label("", font, Color(0.6, 0.6, 0.6))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_hint)


func _make_label(text: String, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
