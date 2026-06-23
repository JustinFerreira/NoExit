## DisappearEnemy.gd
## Visible when first seen, disappears permanently when player looks away

extends CharacterBody3D

var player: Node3D = null
var camera: Camera3D = null

enum State { WAITING, SEEN, GONE }
var state: State = State.WAITING

func _ready() -> void:
	player = PlayerManager.player
	camera = player.CAMERA
	visible = true  # starts visible so player can encounter it naturally

func _physics_process(_delta: float) -> void:
	print("[DEBUG] processing, state: ", state)
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return
	
	match state:
		State.WAITING:
			# Do nothing until player first sees it
			if _player_can_see_me():
				state = State.SEEN
				print("[DisappearEnemy] First seen by player")
		
		State.SEEN:
			# The moment the player looks away, vanish permanently
			if not _player_can_see_me():
				state = State.GONE
				visible = false
				print("[DisappearEnemy] Player looked away — gone forever")
		
		State.GONE:
			# Do nothing, enemy is permanently gone
			pass

func _player_can_see_me() -> bool:
	# Aim at chest height instead of origin (which is at the floor)
	var aim_pos = global_position + Vector3(0, 1.0, 0)
	return camera.is_position_in_frustum(aim_pos)
