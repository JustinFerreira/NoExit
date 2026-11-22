## No Exit
## Overtime Studios
## Bear Trap Interact
## - The clickable part of the bear trap (BearTrap). Once it has snapped
##   shut, hold the click on it to pry it open: a red ring fills around the
##   crosshair while the jaws slowly open with it. Let go (or look away) and
##   it springs back shut. When the ring is full the player is free and the
##   trap is gone.

extends Interactable

## Seconds of holding to pry the trap open.
@export var hold_time: float = 2.0
## Seconds it takes to spring back shut after letting go too early.
@export var spring_back_time: float = 0.25

var _holding := false
var _progress := 0.0
var _ring: HoldRing
var _spring_tween: Tween

func _ready() -> void:
	# outline every part of the trap - base, springs, chain and jaws
	has_outline = true
	mesh_list.clear()
	for part in $"../BearTrapAnimated".find_children("*", "MeshInstance3D", true, false):
		if part.mesh:
			mesh_list.append(part)
	mesh = mesh_list[0]
	super._ready()
	add_to_group("enemy_passthrough")   # enemies walk over the trap, not into it

## Clicked: start prying (the hold is watched in _process).
func _on_interacted(_body: Variant) -> void:
	if _holding or not $"..".activated:
		return
	_holding = true
	if _spring_tween and _spring_tween.is_valid():
		_spring_tween.kill()
	_show_ring(true)

func _process(delta: float) -> void:
	if not _holding:
		return
	if not Input.is_action_pressed("Interact") or not _aimed_at() or PlayerManager.dying:
		_let_go()
		return
	_progress = minf(_progress + delta / hold_time, 1.0)
	# the jaws give slowly at first, then open up
	$"..".set_jaws_open(smoothstep(0.0, 1.0, _progress))
	_ring.value = _progress
	_ring.queue_redraw()
	if _progress >= 1.0:
		_holding = false
		_show_ring(false)
		$"..".release()

## Is the player still looking at the trap?
func _aimed_at() -> bool:
	var p = PlayerManager.player
	return is_instance_valid(p) and "last_collider" in p and p.last_collider == self

## Let go too early: the jaws snap back shut and the ring empties.
func _let_go() -> void:
	_holding = false
	_show_ring(false)
	var from := _progress
	_progress = 0.0
	if from <= 0.0:
		return
	AudioManager.play_sound(AudioManager.BearTrap, -14.0)
	_spring_tween = create_tween()
	_spring_tween.tween_method(func(v: float) -> void: $"..".set_jaws_open(v), smoothstep(0.0, 1.0, from), 0.0, spring_back_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _show_ring(on: bool) -> void:
	if on and not is_instance_valid(_ring):
		var layer := CanvasLayer.new()
		layer.layer = UiManager.LAYER_HUD + 1
		_ring = HoldRing.new()
		_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_ring)
		add_child(layer)
	if is_instance_valid(_ring):
		_ring.value = _progress
		_ring.get_parent().visible = on
		_ring.queue_redraw()

## The hold indicator: a ring around the screen centre that fills clockwise
## from the top in the game's red (UiManager.ACCENT).
class HoldRing extends Control:
	var value := 0.0
	const RADIUS := 26.0
	const WIDTH := 5.0

	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, RADIUS, 0.0, TAU, 64, Color(0, 0, 0, 0.55), WIDTH + 3.0, true)
		draw_arc(c, RADIUS, 0.0, TAU, 64, Color(1, 1, 1, 0.12), WIDTH, true)
		if value > 0.0:
			draw_arc(c, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * value, maxi(4, int(64 * value)), UiManager.ACCENT, WIDTH, true)
