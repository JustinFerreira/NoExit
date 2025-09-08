extends CharacterBody3D

@export var movement_speed: float = 1.0
@export var navigation_region: NavigationRegion3D
@onready var navigation_agent: NavigationAgent3D = get_node("NavigationAgent3D")

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _ready():
	navigation_agent.velocity_computed.connect(Callable(_on_velocity_computed))
	patroll()
	
func set_movement_target(movement_target: Vector3):
	navigation_agent.set_target_position(movement_target)
	


func _physics_process(_delta: float) -> void:
	if $ShapeCast3D.is_colliding(): set_movement_target($ShapeCast3D.get_collider(0).global_position)
	if navigation_agent.is_navigation_finished():
		patroll()
		return
		
	var next_path_position: Vector3 = navigation_agent.get_next_path_position()
	var new_velocity: Vector3 = global_position.direction_to(next_path_position) * movement_speed
	if navigation_agent.avoidance_enabled:
		navigation_agent.velocity = new_velocity
	else:
		_on_velocity_computed(new_velocity)
		
func _on_velocity_computed(safe_velocity: Vector3):
	velocity = safe_velocity
	move_and_slide()

func patroll():
	set_movement_target(navigation_region.navigation_mesh.get_vertices()[randi_range(0, navigation_region.navigation_mesh.get_vertices().size() - 1)])
