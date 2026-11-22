## No Exit
## Overtime Studios
## Opening Cutscene
## - The scene at the very start of the game: gets the state ready for a
##   new run and plays the opening.


extends Node3D

@onready var target: Node3D = $Player
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:

	#Event Manager?
	UiManager.set_cursor_visible(false)
	PlayerManager.InAnimation = true


	#set up animation manager
	AnimationManager.OpeningCutSceneAnimationPlayer = animation_player
	AnimationManager.OpeningCutSceneAnimationPlayer.play("OpeningCutscene")

	#Fix Audio
	AudioManager.cancel_loop_sfx()

	$CutSceneCamera.current = true

func _process(_delta: float) -> void:
	if PlayerManager.player:
		get_tree().call_group("enemy" , "target_position" , target.global_transform.origin)
