## No Exit
## Overtime Studios
## WanderingEnemy.gd
## - Wanders between nodes assigned in the Inspector (drag-drop)
## - Switches to chasing the player when they enter its vision cone
## - Returns to wandering once player is out of sight (configurable)
## - built on Enemy (vision range/cone/height are in its Vision group)

extends Enemy

# ── Movement ──────────────────────────────────────────────────────────────────
@export var wander_speed: float = 1.5
@export var chase_speed: float = 3.5

## How close the enemy must get to a wander target before picking the next one
@export var arrival_threshold: float = 1.5

## If true the enemy returns to wandering when the player leaves vision.
## If false it locks onto the player permanently once spotted (default).
@export var lose_player_on_sight_lost: bool = false

# ── Wander targets — drag Node3D objects here in the Inspector ────────────────
@export var wander_targets: Array[Node3D] = []

# ── Internal state ────────────────────────────────────────────────────────────
enum State { WANDERING, CHASING }
var state: State = State.WANDERING

var current_wander_target: Node3D = null

func _enemy_ready() -> void:
	nav.path_desired_distance = 1.0
	nav.target_desired_distance = arrival_threshold
	nav.path_max_distance = 3.0
	_pick_new_wander_target()

func _enemy_physics(_delta: float) -> void:
	_update_state()
	match state:
		State.WANDERING:
			_do_wander()
		State.CHASING:
			_do_chase()

## The level calls this with the player's position every frame - this enemy
## finds the player with its own eyes instead, so it's ignored.
func target_position(_target: Vector3) -> void:
	pass

# ── State switching ───────────────────────────────────────────────────────────
func _update_state() -> void:
	match state:
		State.WANDERING:
			if can_see_player():
				state = State.CHASING

		State.CHASING:
			if lose_player_on_sight_lost and not can_see_player():
				state = State.WANDERING
				_pick_new_wander_target()

# ── Wandering behaviour ───────────────────────────────────────────────────────
func _do_wander() -> void:
	if current_wander_target == null or not is_instance_valid(current_wander_target):
		_pick_new_wander_target()
		return

	# Arrived? Pick the next target
	if global_position.distance_to(current_wander_target.global_position) <= arrival_threshold:
		_pick_new_wander_target()
		return

	set_nav_target(current_wander_target.global_position)
	move_along_nav(wander_speed)

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
	set_nav_target(current_wander_target.global_position)

# ── Chasing behaviour ─────────────────────────────────────────────────────────
func _do_chase() -> void:
	if not is_instance_valid(player):
		state = State.WANDERING
		_pick_new_wander_target()
		return

	set_nav_target(player.global_position)
	move_along_nav(chase_speed)
