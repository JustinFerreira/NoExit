extends Node3D


@export var stalking_distance: float = 15.0  # Distance killer will maintain
@export var make_killer_invisible: bool = true
@export var make_killer_silent: bool = true
@export var teleports: Array[Node]
@export var activated: bool = false

var cooldown_timer: Timer

func _ready():
	# Create and setup the timer
	cooldown_timer = Timer.new()
	cooldown_timer.wait_time = 30.0
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(cooldown_timer)

func _on_area_entered(area: Area3D) -> void:
	if PlayerManager.Loop0:
		return
	
	if not activated && (area.is_in_group("player") or area.name == "Player"):
		PlayerManager.stalking_mode = true
		PlayerManager.stalking_area = self
		
		# Update killer behavior
		if PlayerManager.Enemy:
			var random_index = randi() % teleports.size()
			PlayerManager.Enemy.enter_stalking_mode(stalking_distance, teleports[random_index].name, make_killer_invisible, make_killer_silent)
			print(teleports[random_index].name)
		
		if activated == false:
			activated = true
			cooldown_timer.start()
			

func _on_area_3d_area_exited(area: Area3D) -> void:
	if area.is_in_group("player") or area.name == "Player":
		PlayerManager.stalking_mode = false
		PlayerManager.stalking_area = null
		
		# Update killer behavior
		if PlayerManager.Enemy:
			PlayerManager.Enemy.exit_stalking_mode()


func _on_cooldown_timeout():
	activated = false
