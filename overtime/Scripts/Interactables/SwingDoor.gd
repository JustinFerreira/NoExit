## No Exit
## Overtime Studios
## Swing Door
## - A hinged door that swings open and shut (Door.gd's lock and key on
##   top): click it to open / close. Locked (is_locked): clicking tries the
##   key (key_name) like any Door, plays locked_sound and says it's locked;
##   unlock() swings it open instead of hiding it.
## - Opens by itself for office NPCs walking through (group "office_npc",
##   and the janitor) - NPC_RANGE from the doorway - and shuts again once
##   they've gone, unless the player opened it. Not while it's locked.
## - Goes on the door panel's StaticBody3D; it turns `hinge` (a Node3D at
##   the hinge side - the panel is its child). OfficeWing.gd builds these
##   for the new rooms (OfficeWing.make_door); set them up by hand the same
##   way anywhere else.
## - open_toward: which way it swings (+1 = the hinge's +Y rotation).

extends Door
class_name SwingDoor

## The node it turns (the panel and this body hang off it).
@export var hinge: Node3D
## How far it swings open (degrees) and how long that takes.
@export var open_angle: float = 100.0
@export var swing_time: float = 0.55
## +1 / -1: which way it swings open.
@export var open_toward: float = 1.0
## NPCs this close to the doorway (level units) get it opened for them.
@export var npc_range: float = 3.5

var is_open := false
var _player_opened := false
var _closed_yaw := 0.0
var _tween: Tween
var _npc_clear := 0.0
var _center := Vector3.INF     # the doorway's middle (the closed door's)

func _ready() -> void:
	hide_on_unlock = false
	super._ready()
	# (Door drops the collision of an unlocked door - this one's solid
	# until it's swung open)
	collision_layer = _default_collision_layer
	visible = true
	if hinge:
		_closed_yaw = hinge.rotation.y

func _on_interacted(_body: Variant) -> void:
	if is_locked:
		_try_unlock_with_key()
		if is_locked:
			UiManager.say("It's locked.")
		return
	_player_opened = not is_open
	set_open(not is_open)

## Unlocked: swings open (instead of Door's vanish).
func unlock() -> void:
	if not is_locked:
		return
	is_locked = false
	_play_unlock_animation()
	door_unlocked.emit()
	_player_opened = true
	set_open(true)

## Locked again: swings shut first.
func lock() -> void:
	if is_locked:
		return
	set_open(false)
	is_locked = true
	door_locked.emit()

## Swings it open or shut.
func set_open(open: bool) -> void:
	if open == is_open or hinge == null:
		return
	is_open = open
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var to := _closed_yaw + (deg_to_rad(open_angle) * open_toward if open else 0.0)
	_tween.tween_property(hinge, "rotation:y", to, swing_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	AudioManager.play_sound(AudioManager.CarDoorOpen if open else AudioManager.CarDoorClose, -14.0)

func _physics_process(delta: float) -> void:
	if _center == Vector3.INF and not is_open:
		_center = global_position
	if is_locked or hinge == null:
		return
	var near := _npc_near()
	if near:
		_npc_clear = 0.0
		if not is_open:
			_player_opened = false
			set_open(true)
	elif is_open and not _player_opened:
		_npc_clear += delta
		if _npc_clear > 2.5 and not _player_in_doorway():
			set_open(false)

## The middle of the doorway (the closed door's middle).
func _doorway() -> Vector3:
	return _center if _center != Vector3.INF else global_position

func _npc_near() -> bool:
	var at := _doorway()
	for n in get_tree().get_nodes_in_group("office_npc"):
		if n is Node3D and _flat_dist(n.global_position, at) < npc_range:
			return true
	var j = PlayerManager.janitor
	if is_instance_valid(j) and j.root and _flat_dist(j.root.global_position, at) < npc_range:
		return true
	return false

func _player_in_doorway() -> bool:
	var p = PlayerManager.player
	return is_instance_valid(p) and _flat_dist(p.global_position, _doorway()) < 2.0

static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
