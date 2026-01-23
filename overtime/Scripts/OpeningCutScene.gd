## No Exit
## Overtime Studios
## Last upadated 1/23/26 by Justin Ferreira
## OpeningCutScne Script
## - This is the scene at the begining of the game
## gets scene ready to start game and 
## 
extends Node3D

@onready var target = $Player
@onready var animation_player = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#Event Manager?
	PlayerManager.OpeningCutscene = true
	PlayerManager.player.CURSOR.visible = false
	PlayerManager.InAnimation = true
	#deaths 0?
	PlayerManager.Loop0 = true
	
	#set up animation manager
	AnimationManager.OpeningCutSceneAnimationPlayer = animation_player
	AnimationManager.OpeningCutSceneAnimationPlayer.play("OpeningCutscene")
	
	#Fix Audio
	AudioManager.cancel_loop_sfx()
	
	$CutSceneCamera.current = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if PlayerManager.player:
		get_tree().call_group("enemy" , "target_position" , target.global_transform.origin)
