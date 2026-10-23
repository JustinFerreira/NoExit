## DisappearEnemy.gd
## Visible when first seen, disappears permanently when player looks away
## - built on Enemy (see Enemy.gd). sight_fov_degrees (Vision group) is the
##   half-angle of the PLAYER's view cone that counts as "seen".

extends Enemy

## Maximum distance at which the enemy counts as "seen"
@export var max_sight_range: float = 80.0

enum State { WAITING, SEEN, GONE }
var state: State = State.WAITING

func _enemy_ready() -> void:
	use_gravity = false
	can_kill_player = false   # it only appears and vanishes
	visible = true  # starts visible so player can encounter it naturally

## Doesn't walk anywhere, so the level's chase target is ignored.
func target_position(_target: Vector3) -> void:
	pass

func _enemy_physics(_delta: float) -> void:
	velocity = Vector3.ZERO
	match state:
		State.WAITING:
			# Do nothing until player first sees it
			if _seen():
				state = State.SEEN

		State.SEEN:
			# The moment the player looks away, vanish permanently
			if not _seen():
				state = State.GONE
				visible = false

		State.GONE:
			# Do nothing, enemy is permanently gone
			pass

func _seen() -> bool:
	# Chest height so the check doesn't clip the floor
	return player_can_see_me([global_position + Vector3(0, 1.0, 0)], sight_fov_degrees, max_sight_range)
