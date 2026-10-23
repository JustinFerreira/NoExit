extends Node3D

# Distance killer will maintain
@export var teleports: Array[Node]
@export var activated: bool = false

var cooldown_timer: Timer

func _ready():
	# Create and setup the timer
	cooldown_timer = Timer.new()
	cooldown_timer.wait_time = 60.0
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(cooldown_timer)

func _on_area_entered(_area: Area3D) -> void:
	if PlayerManager.Loop0:
		return
	if PlayerManager.Enemy:
		var random_index = randi() % teleports.size()
		PlayerManager.Enemy.find_teleport_target(teleports[random_index].name)

func _on_area_3d_area_exited(_area: Area3D) -> void:
	cooldown_timer.start()


func _on_cooldown_timeout():
	activated = false
