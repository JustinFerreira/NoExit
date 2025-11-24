extends Node3D

@onready var player_cubicle = $Cubicle
@onready var animation_player = player_cubicle.get_node("AnimationPlayer")
@onready var cutscene_camera = player_cubicle.get_node("CutSceneCamera")
@onready var player_camera = $Player/Head/Camera3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerManager.ResetPlayer()
	PlayerManager.Office = true
	PlayerManager.ParkingGarage = false
	PlayerManager.testing = false
	PlayerManager.gotKeys = false
	PlayerManager.InAnimation = true;
	PlayerManager.player.CURSOR.visible = false
	PlayerManager.no_enemy = true
	PlayerManager.Loop1 = true
	PlayerManager.player = get_tree().current_scene.get_node("Player") 
	animation_player.connect("animation_finished", _on_animation_finished)
	cutscene_camera.current = true
	animation_player.play("WakingUp")
	
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_animation_finished(anim_name: String):
	#print("Animation Finished: ", anim_name)
	
	if anim_name == "WakingUp":
		PlayerManager.InAnimation = false
		PlayerManager.player.CURSOR.visible = true
		player_camera.current = true
		if PlayerManager.deaths > 0 && PlayerManager.gotKeys == false:
			PlayerManager.Dialog("Where did I leave my keys?")
		else:
			PlayerManager.CharacterHintDialog("That was a great nap... I'm so glad I'm finally leaving this place. I should pack up my things in my box and go.",
			"Click to skip dialog")
