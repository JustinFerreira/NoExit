## No Exit
## Overtime Studios
## Stalking Area
## - While the player is inside the trigger area (not in Loop 0) the killer
##   switches to stalking: it fades out, reappears at one of the teleports
##   and circles the player at stalking_distance instead of chasing.
##   Leaving the area ends it; it can start again 30 s later.

extends Node3D

## Seconds after the player leaves before it can start again.
const COOLDOWN := 30.0

## Distance the killer keeps while stalking.
@export var stalking_distance: float = 15.0
## Mute the killer's sounds while it stalks.
@export var make_killer_silent: bool = true
## Places the killer can reappear at (found by name).
@export var teleports: Array[Node]
## True while it's used up (waiting for the cooldown).
@export var activated: bool = false

var cooldown_timer: Timer

func _ready() -> void:
	cooldown_timer = Timer.new()
	cooldown_timer.wait_time = COOLDOWN
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(cooldown_timer)

func _on_area_entered(area: Area3D) -> void:
	if PlayerManager.Loop0 or activated or not HelperManager.is_player_area(area):
		return
	PlayerManager.stalking_mode = true
	if PlayerManager.Enemy and not teleports.is_empty():
		PlayerManager.Enemy.enter_stalking_mode(stalking_distance, teleports.pick_random().name, make_killer_silent)

func _on_area_3d_area_exited(area: Area3D) -> void:
	if not is_inside_tree() or not HelperManager.is_player_area(area):
		return
	PlayerManager.stalking_mode = false
	if is_instance_valid(PlayerManager.Enemy):
		PlayerManager.Enemy.exit_stalking_mode()
	if not activated:
		activated = true
		cooldown_timer.start()

func _on_cooldown_timeout() -> void:
	activated = false
