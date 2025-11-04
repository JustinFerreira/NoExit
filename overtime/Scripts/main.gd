extends Node3D

@onready var target = $Player
@export var fog_remover: FogVolume


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print(PlayerManager.sprint_engaged)
	if PlayerManager.sprint_engaged:
		PlayerManager.player.is_sprinting = PlayerManager.sprint_engaged

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	get_tree().call_group("enemy" , "target_position" , target.global_transform.origin)
	if fog_remover:
		fog_remover.position = target.position
