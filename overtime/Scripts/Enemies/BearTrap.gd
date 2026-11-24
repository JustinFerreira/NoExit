## No Exit
## Overtime Studios
## Bear Trap
## - Hidden in Loop 0. The first time the player steps in it, it snaps shut:
##   the player is trapped (can't move) until they hold the click on the trap
##   long enough to pry it open (see BearTrapInteract on its StaticBody3D).
##   The jaws open as they pry (set_jaws_open), then the trap is gone.

extends Node3D
const EnemyNoise = preload("res://Scripts/Enemies/EnemyNoise.gd")

var activated: bool = false

## The jaws as modelled (open), to swing them shut and back open from.
var _jaws_open: Array[Transform3D] = []
const JAW_CLOSE_ANGLE := PI * 0.5

func _ready() -> void:
	if PlayerManager.Loop0:
		visible = false
		$Area3D/CollisionShape3D.disabled = true
		$StaticBody3D/CollisionShape3D.disabled = true
	$StaticBody3D.is_interactable = false
	for jaw in _jaws():
		_jaws_open.append(jaw.transform)

func _jaws() -> Array[Node3D]:
	return [$BearTrapAnimated/BearJaw1, $BearTrapAnimated/BearJaw2]

func _on_area_3d_area_entered(area: Area3D) -> void:
	if PlayerManager.Loop0 or activated or not HelperManager.is_player_area(area):
		return
	activated = true
	$StaticBody3D.is_interactable = true
	AudioManager.play_sound(AudioManager.BearTrap)
	EnemyNoise.make(get_tree(), global_position, EnemyNoise.BEAR_TRAP, true)
	AudioManager.play_sound(AudioManager.HeavyDamage)
	PlayerManager.player.trapped = true
	_snap_jaws()

## The jaws swing up on their hinges and slam together (fast, speeding up).
## The open model is kept - the separate closed model sits in a slightly
## different spot, so swapping to it made the trap jump.
func _snap_jaws() -> void:
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void: set_jaws_open(1.0 - t), 0.0, 1.0, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## 0 = snapped shut, 1 = wide open (as modelled).
func set_jaws_open(amount: float) -> void:
	var jaws := _jaws()
	for i in jaws.size():
		jaws[i].transform = _jaws_open[i].rotated_local(Vector3.RIGHT, JAW_CLOSE_ANGLE * (1.0 - clampf(amount, 0.0, 1.0)))

## Pried open: the player is free and the trap is gone.
func release() -> void:
	PlayerManager.player.trapped = false
	visible = false
	$Area3D/CollisionShape3D.disabled = true
	$StaticBody3D/CollisionShape3D.disabled = true
	$StaticBody3D.is_interactable = false
