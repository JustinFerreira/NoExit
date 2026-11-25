## No Exit
## Overtime Studios
## Damage Overlay
## - The player's health on screen (PlayerManager.health): the less they
##   have, the redder the picture gets (edges first, then all of it, with a
##   heartbeat pulse when it's low) and the further the cracks spread.
## - Every hit cracks the screen where it lands (a new star of cracks, bigger
##   for a bigger hit) with a red flash; up to MAX_IMPACTS at once.
## - Dead (no health left): a moment of the kill, then the whole screen
##   fades to solid red (DEATH_DELAY, DEATH_FADE) - drawn over the kill's
##   own black-out (layer LAYER_DEAD), under the game over screen - whose
##   background is the same red (DEAD_RED), so it carries straight on.
## - Health coming back (PlayerManager regen): the red eases off and the
##   cracks fade with it (crack_alpha = how hurt now / how hurt at worst) -
##   gone by the time it's full.
## - Full health again (a new round, a restart, healed): all clear.
## - UIManager makes it; the look itself is Assets/Shaders/DamageOverlay.gdshader.

extends CanvasLayer

const SHADER := preload("res://Assets/Shaders/DamageOverlay.gdshader")
## Under the HUD while alive; over everything but the game over screen dead.
const LAYER_ALIVE := 4
const LAYER_DEAD := 55
const MAX_IMPACTS := 8
## Dying: DEATH_DELAY seconds of the kill first, then DEATH_FADE to completely red.
const DEATH_DELAY := 1.1
const DEATH_FADE := 1.3
## The solid red of death - the game over screen's background is the same.
const DEAD_RED := Color(0.62, 0.0, 0.0)

var _mat: ShaderMaterial
var _hurt := 0.0          # shown (eases to _hurt_target)
var _hurt_target := 0.0
var _flash := 0.0
var _dead := 0.0
var _dead_wait := 0.0
## How hurt it got at worst since last all clear: the cracks show at
## _hurt / _worst, so they fade out as health comes back.
var _worst := 0.0
## [Vector4(x, y, reach, seed)] - reach at full spread (shown scaled by hurt)
var _impacts: Array[Vector4] = []

func _ready() -> void:
	layer = LAYER_ALIVE
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.name = "Damage"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	rect.material = _mat
	add_child(rect)
	visible = false
	_mat.set_shader_parameter("dead_color", Vector3(DEAD_RED.r, DEAD_RED.g, DEAD_RED.b))
	PlayerManager.health_changed.connect(_on_health_changed)

func _on_health_changed(health: float, hit: float) -> void:
	_hurt_target = 1.0 - health / PlayerManager.MAX_HEALTH
	if health >= PlayerManager.MAX_HEALTH and hit <= 0.0:
		# a reset (new round, restart) clears at once; healed back up
		# (hit < 0) lets the last of it ease out
		if hit == 0.0 or _impacts.is_empty():
			clear()
		return
	if hit > 0.0:
		_worst = maxf(_worst, _hurt_target)
		_flash = clampf(0.45 + hit / 60.0, 0.0, 1.0)
		_crack(hit, health <= 0.0)

## How much of the screen the death red covers right now (0-1, as drawn).
func dead_shown() -> float:
	return ease(_dead, 1.6)

## Is the death red on its way (the player is dead and dying)?
func dying_red() -> bool:
	return _hurt_target >= 1.0 and PlayerManager.dying

## All clear (full health).
func clear() -> void:
	_hurt = 0.0
	_hurt_target = 0.0
	_flash = 0.0
	_dead = 0.0
	_dead_wait = 0.0
	_worst = 0.0
	_impacts.clear()
	layer = LAYER_ALIVE
	visible = false

## A new star of cracks: somewhere off-centre, bigger for a bigger hit; the
## killing blow smashes the middle.
func _crack(hit: float, fatal: bool) -> void:
	var at := Vector2(randf_range(0.15, 0.85), randf_range(0.18, 0.82))
	var reach := clampf(0.3 + hit / 100.0 * 0.7, 0.3, 0.8)
	if fatal:
		at = Vector2(0.5, 0.5) + Vector2(randf_range(-0.08, 0.08), randf_range(-0.08, 0.08))
		reach = 1.3
	_impacts.append(Vector4(at.x, at.y, reach, randf() * 100.0))
	while _impacts.size() > MAX_IMPACTS:
		_impacts.pop_front()

func _process(delta: float) -> void:
	_hurt = move_toward(_hurt, _hurt_target, delta * 1.5)
	_flash = move_toward(_flash, 0.0, delta * 2.5)
	if _hurt_target <= 0.0 and _hurt <= 0.001 and not _impacts.is_empty():
		clear()   # eased all the way back to full
	if _hurt_target >= 1.0 and PlayerManager.dying:
		_dead_wait += delta
		if _dead_wait >= DEATH_DELAY:
			_dead = move_toward(_dead, 1.0, delta / DEATH_FADE)
	layer = LAYER_DEAD if _dead > 0.0 else LAYER_ALIVE
	visible = _hurt > 0.001 or _flash > 0.001 or _dead > 0.0
	if not visible:
		return
	var size := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_mat.set_shader_parameter("hurt", _hurt)
	_mat.set_shader_parameter("flash", _flash)
	_mat.set_shader_parameter("crack_alpha", clampf(_hurt / _worst, 0.0, 1.0) if _worst > 0.0 else 0.0)
	_mat.set_shader_parameter("dead", dead_shown())
	# cracks spread as health falls (a crack from a small hit stays small)
	var spread := 0.55 + 0.45 * _hurt
	var list: Array[Vector4] = []
	for im in _impacts:
		list.append(Vector4(im.x, im.y, im.z * spread, im.w))
	while list.size() < MAX_IMPACTS:
		list.append(Vector4.ZERO)
	_mat.set_shader_parameter("impact_count", _impacts.size())
	_mat.set_shader_parameter("impacts", list)
