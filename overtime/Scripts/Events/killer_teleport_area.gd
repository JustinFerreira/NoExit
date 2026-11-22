## No Exit
## Overtime Studios
## Killer Teleport Area
## - When the player walks into the trigger area (not in Loop 0), the killer
##   (PlayerManager.Enemy) jumps to one of the teleports (picked at random)
##   for a scare. It won't fire again until COOLDOWN seconds after the
##   player has left the area.

extends Node3D

## Seconds after the player leaves before it can fire again.
const COOLDOWN := 60.0

## Places the killer can be sent to (it finds them by name, see
## Killer.find_teleport_target).
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
	if PlayerManager.Loop0 or activated or teleports.is_empty():
		return
	if not HelperManager.is_player_area(area) or not PlayerManager.Enemy:
		return
	activated = true
	cooldown_timer.stop()
	PlayerManager.Enemy.find_teleport_target(teleports.pick_random().name)

func _on_area_3d_area_exited(area: Area3D) -> void:
	if activated and HelperManager.is_player_area(area):
		cooldown_timer.start()

func _on_cooldown_timeout() -> void:
	activated = false
