extends "res://Scripts/Levels/ModelLineup.gd"
## Real-size review level: everything in metres, with the real-size player and killer.
## Free walking from the start, whether opened from Loop Select or straight from the editor.

## How close the killer follows you here (the story levels use 20 m).
@export var killer_follow_distance: float = 5.0

var _player: Node3D
var _enemies: Array = []


func _ready() -> void:
	PlayerManager.MainMenu = false
	PlayerManager.firstdialog = false
	PlayerManager.OpeningCutscene = false
	PlayerManager.Loop0 = false
	PlayerManager.Loop1 = false
	super._ready()
	_player = get_node_or_null("Player")
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_ancestor_of(e) and e.has_method("target_position"):
			_enemies.append(e)
			if "follow_distance" in e:
				e.follow_distance = killer_follow_distance


## Like the story levels: tell each enemy where the player is every frame.
func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	for e in _enemies:
		if is_instance_valid(e):
			e.target_position(_player.global_position)
