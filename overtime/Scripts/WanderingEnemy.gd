## No Exit
## Overtime Studios
## WanderingEnemy.gd
## - Wanders between nodes assigned in the Inspector (drag-drop)
## - Switches to chasing the player when they enter its vision cone
## - Returns to wandering once player is out of sight (configurable)

extends CharacterBody3D

# ── Movement ──────────────────────────────────────────────────────────────────
@export var wander_speed: float = 1.5
@export var chase_speed: float = 3.5

## How close the enemy must get to a wander target before picking the next one
@export var arrival_threshold: float = 1.5

# ── Vision ────────────────────────────────────────────────────────────────────
## Max distance the enemy can see the player
@export var sight_range: float = 20.0
## Half-angle (degrees) of the vision cone
@export var sight_fov_degrees: float = 60.0
## Height offset used when casting rays toward the player (chest height)
@export var sight_height_offset: float = 1.0

## If true the enemy returns to wandering when the player leaves vision.
## If false it locks onto the player permanently once spotted (default).
@export var lose_player_on_sight_lost: bool = false

# ── Wander targets — drag Node3D objects here in the Inspector ────────────────
@export var wander_targets: Array[Node3D] = []

# ── Internal state ────────────────────────────────────────────────────────────
enum State { WANDERING, CHASING }
var state: State = State.WANDERING

var current_wander_target: Node3D = null

var player: Node3D = null
var camera: Camera3D = null

@onready var nav: NavigationAgent3D = $NavigationAgent3D

# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# PlayerManager is an autoload node — always exists, but .player may be null
	# in design/test scenes with no player. We'll retry in _update_state each frame.
	_try_get_player()

	nav.path_desired_distance = 1.0
	nav.target_desired_distance = arrival_threshold
	nav.path_max_distance = 3.0

	_pick_new_wander_target()

# ── Physics process ───────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y -= 2

	_update_state()

	match state:
		State.WANDERING:
			_do_wander()
		State.CHASING:
			_do_chase()

	move_and_slide()

# ── State switching ───────────────────────────────────────────────────────────
func _try_get_player() -> void:
	if player == null and PlayerManager.player != null:
		player = PlayerManager.player
		camera = player.CAMERA

func _update_state() -> void:
	# Retry grabbing the player if it wasn't available at _ready() time
	if player == null:
		_try_get_player()

	match state:
		State.WANDERING:
			if _can_see_player():
				state = State.CHASING

		State.CHASING:
			if lose_player_on_sight_lost and not _can_see_player():
				state = State.WANDERING
				_pick_new_wander_target()

# ── Wandering behaviour ───────────────────────────────────────────────────────
func _do_wander() -> void:
	if current_wander_target == null or not is_instance_valid(current_wander_target):
		_pick_new_wander_target()
		return

	nav.target_position = current_wander_target.global_position

	# Arrived? Pick the next target
	if global_position.distance_to(current_wander_target.global_position) <= arrival_threshold:
		_pick_new_wander_target()
		return

	_move_along_nav(wander_speed)

func _pick_new_wander_target() -> void:
	if wander_targets.is_empty():
		return

	# Avoid picking the same target twice in a row
	var candidates := wander_targets.filter(func(t): return t != current_wander_target and is_instance_valid(t))
	if candidates.is_empty():
		candidates = wander_targets.filter(func(t): return is_instance_valid(t))
	if candidates.is_empty():
		return

	current_wander_target = candidates[randi() % candidates.size()]
	nav.target_position = current_wander_target.global_position

# ── Chasing behaviour ─────────────────────────────────────────────────────────
func _do_chase() -> void:
	if not is_instance_valid(player):
		state = State.WANDERING
		_pick_new_wander_target()
		return

	nav.target_position = player.global_position
	_move_along_nav(chase_speed)

# ── Shared movement helper ────────────────────────────────────────────────────
func _move_along_nav(speed: float) -> void:
	var next_pos    := nav.get_next_path_position()
	var current_pos := global_transform.origin
	var direction   := (next_pos - current_pos).normalized()

	# Face movement direction (mirrors Killer.gd look_at logic)
	if direction.length() > 0.001:
		var look_target := global_transform.origin - direction
		var look_dir    := (look_target - global_transform.origin).normalized()
		if abs(look_dir.dot(Vector3.UP)) < 0.999:
			look_at(look_target, Vector3.UP)

	velocity = velocity.move_toward(direction * speed, 0.25)

# ── Vision check (mirrors Disapearing_Enemy.gd) ────────────────────────────────
func _can_see_player() -> bool:
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return false

	var aim_pos := player.global_position + Vector3(0, sight_height_offset, 0)

	# 1. Range check
	if global_position.distance_to(aim_pos) > sight_range:
		return false

	# 2. Vision cone — must be within the enemy's forward FOV
	var to_player := (aim_pos - global_position).normalized()
	var forward   := -global_transform.basis.z  # enemy forward
	var angle     := rad_to_deg(to_player.angle_to(forward))
	if angle > sight_fov_degrees:
		return false

	# 3. Line-of-sight raycast — no geometry blocking the path
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, sight_height_offset, 0),
		aim_pos,
		0xFFFFFFFF,
		[get_rid()]  # exclude self
	)
	query.collide_with_areas = false
	var result := space.intersect_ray(query)

	if result.is_empty():
		return true
	return result["collider"] == player
