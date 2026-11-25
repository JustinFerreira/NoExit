## No Exit
## Overtime Studios
## Struggle HUD
## - Shown while an enemy has hold of the player (Enemy._struggle): "MASH F"
##   in the middle, a bar that fills with every press, and under it a thin
##   red bar running out with the time left. Jumps on each press.
## - Made and freed by Enemy._struggle; finish(escaped) flashes it white
##   (free) or red (not) before it goes.

extends CanvasLayer

const BAR := Vector2(260.0, 14.0)
const TIME_BAR_H := 4.0

var _root: Control
var _label: Label
var _fill: ColorRect
var _time: ColorRect
var _kick := 0.0

func _ready() -> void:
	layer = 6   # just over the HUD (UIManager.LAYER_HUD)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var full := Control.new()
	full.set_anchors_preset(Control.PRESET_FULL_RECT)
	full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(full)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0.68
	_root.anchor_bottom = 0.68
	full.add_child(_root)

	_label = Label.new()
	_label.text = "MASH  [F]"
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 6)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(BAR.x, 40.0)
	_label.position = Vector2(-BAR.x * 0.5, -48.0)
	_label.pivot_offset = _label.size * 0.5
	_root.add_child(_label)

	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.55)
	back.size = BAR + Vector2(4, 4)
	back.position = Vector2(-BAR.x * 0.5 - 2.0, -2.0)
	_root.add_child(back)
	_fill = ColorRect.new()
	_fill.color = Color(0.92, 0.92, 0.92)
	_fill.size = Vector2(0.0, BAR.y)
	_fill.position = Vector2(-BAR.x * 0.5, 0.0)
	_root.add_child(_fill)
	_time = ColorRect.new()
	_time.color = Color("#d42020")
	_time.size = Vector2(BAR.x, TIME_BAR_H)
	_time.position = Vector2(-BAR.x * 0.5, BAR.y + 6.0)
	_root.add_child(_time)
	for c in _root.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE

## progress 0-1 (presses so far / needed), time_left 0-1.
func set_state(progress: float, time_left: float) -> void:
	_fill.size.x = BAR.x * clampf(progress, 0.0, 1.0)
	_time.size.x = BAR.x * clampf(time_left, 0.0, 1.0)

## A press: the prompt jumps.
func kick() -> void:
	_kick = 1.0

func _process(delta: float) -> void:
	_kick = move_toward(_kick, 0.0, delta * 7.0)
	var s := 1.0 + 0.18 * _kick
	_label.scale = Vector2(s, s)
	_label.rotation = deg_to_rad(randf_range(-4.0, 4.0)) * _kick
	# urgent: the prompt pulses red as the time runs out
	var low := 1.0 - _time.size.x / BAR.x
	_label.modulate = Color(1, 1, 1).lerp(Color(1, 0.35, 0.35), low * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)))

## Free (white flash) or not (red), then gone.
func finish(escaped: bool) -> void:
	_label.text = "FREE!" if escaped else ""
	_fill.color = Color(1, 1, 1) if escaped else Color("#d42020")
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.5 if escaped else 0.2)
	tw.tween_callback(queue_free)
