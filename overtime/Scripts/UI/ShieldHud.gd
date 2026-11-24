## No Exit
## Overtime Studios
## Shield HUD
## - The shields the player carries, as up to three shield symbols under the
##   stamina bar (UIManager builds it and fades it in and out - only while
##   it matters: a shield found or used, or the inventory held open).
## - Carried shields are filled in the stamina bar's colour, empty slots are
##   faint outlines, and a shield that just broke saving the player flashes red
##   and shrinks away.

extends Control

const ICON := Vector2(16.0, 20.0)
const GAP := 7.0
const FILL := Color(0.85, 0.85, 0.85)
const EMPTY := Color(1, 1, 1, 0.22)
const BROKE := Color("#d42020")
const BREAK_TIME := 0.9

var shields := 0
var slots := 3
var _broke_at := -1      # slot index that just broke
var _broke_left := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(slots * ICON.x + (slots - 1) * GAP, ICON.y)
	size = custom_minimum_size

func set_count(count: int, used: bool) -> void:
	if used:
		_broke_at = count   # the one that was there
		_broke_left = BREAK_TIME
	shields = count
	queue_redraw()

func _process(delta: float) -> void:
	if _broke_left > 0.0:
		_broke_left = maxf(_broke_left - delta, 0.0)
		queue_redraw()

func _draw() -> void:
	for i in slots:
		var at := Vector2(i * (ICON.x + GAP), 0.0)
		var pts := _shield(at, ICON)
		if i < shields:
			draw_colored_polygon(pts, FILL)
			draw_polyline(_closed(pts), Color(0, 0, 0, 0.5), 1.0, true)
		elif i == _broke_at and _broke_left > 0.0:
			# breaking: red, shrinking into its middle
			var k := _broke_left / BREAK_TIME
			var c := at + ICON * 0.5
			var small := _shield(c - ICON * 0.5 * k, ICON * k)
			draw_colored_polygon(small, Color(BROKE, k))
			draw_polyline(_closed(pts), EMPTY, 1.0, true)
		else:
			draw_polyline(_closed(pts), EMPTY, 1.0, true)

## A shield shape in the box at `at` sized `s`: flat-ish top, straight
## sides, curving down to a point.
static func _shield(at: Vector2, s: Vector2) -> PackedVector2Array:
	var p := PackedVector2Array()
	p.append(at + Vector2(0.0, s.y * 0.08))
	p.append(at + Vector2(s.x * 0.5, 0.0))
	p.append(at + Vector2(s.x, s.y * 0.08))
	p.append(at + Vector2(s.x, s.y * 0.5))
	p.append(at + Vector2(s.x * 0.85, s.y * 0.75))
	p.append(at + Vector2(s.x * 0.5, s.y))
	p.append(at + Vector2(s.x * 0.15, s.y * 0.75))
	p.append(at + Vector2(0.0, s.y * 0.5))
	return p

static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var c := p.duplicate()
	c.append(p[0])
	return c
