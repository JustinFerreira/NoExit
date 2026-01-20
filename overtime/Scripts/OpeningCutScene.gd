extends Node3D

@onready var target = $Player
@onready var animation_player = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AnimationManager.OpeningCutSceneAnimationPlayer = animation_player
	PlayerManager.player.CURSOR.visible = false
	$CutSceneCamera.current = true
	AnimationManager.OpeningCutSceneAnimationPlayer.play("OpeningCutscene")
	AudioManager.cancel_loop_sfx()
	PlayerManager.OpeningCutscene = true
	PlayerManager.InAnimation = true
	PlayerManager.Loop0 = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if PlayerManager.player:
		get_tree().call_group("enemy" , "target_position" , target.global_transform.origin)
