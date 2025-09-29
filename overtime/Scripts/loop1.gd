extends Node3D

@onready var animation_player = $AnimationPlayer
@onready var cutscene_camera = $CutSceneCamera
@onready var player_camera = $Player/Head/Camera3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.connect("animation_finished", _on_animation_finished)
	cutscene_camera.current = true
	animation_player.play("Wakingup")
	
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_animation_finished(anim_name: String):
	print("Animation Finished: ", anim_name)
	
	if anim_name == "Wakingup":
		player_camera.current = true
		if PlayerManager.deaths > 0 && PlayerManager.gotKeys == false:
			PlayerManager.Dialog("Where did I leave my keys?", 5)
		else:
			PlayerManager.Dialog("Oh, must have dozed off. Is the day still not over? It’s always the last day that feels like forever.", 5)
