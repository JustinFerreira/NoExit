## No Exit
## Overtime Studios

extends Node3D

@onready var player_cubicle = $NavigationRegion3D/Cubicle
@onready var animation_player = player_cubicle.get_node("AnimationPlayer")
@onready var cutscene_camera = player_cubicle.get_node("CutSceneCamera")
@onready var player_camera = $Player/Head/Camera3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if EventManager.Comingfromelevator:
		$Player.position = Vector3(-41.611, 0, 8.08) 
		EventManager.Comingfromelevator = false
		player_camera.current = true
		animation_player.play("blackoff")
		PlayerManager.no_enemy = true
		PlayerManager.Office = true
		PlayerManager.ParkingGarage = false
		AudioManager.play_music(AudioManager.OfficeWhiteNoise)
		AudioManager.OfficeMusicOn = true
		PlayerManager.startMultiDialog = false
		AnimationManager.ElevatorDoorButtonAnimationPlayer.play("Take 001")
		$Elevator/ElevatorCollisions/DoorCollision.translate(Vector3(0,3,0))
	else:
		$Player.position = Vector3(-1.848, 0, 17.72) 
		PlayerManager.ResetPlayer()
		
		AudioManager.play_music(AudioManager.OfficeWhiteNoise)
		AudioManager.OfficeMusicOn = true
		
		#EventManager Function fix
		SettingsManager.Loop0Pass = true
		SettingsManager.save_settings()
		
		
		
		PlayerManager.Office = true
		PlayerManager.ParkingGarage = false
		
		PlayerManager.testing = false
		#Needed?
		PlayerManager.gotKeys = false
		PlayerManager.InAnimation = true;
		PlayerManager.player.CURSOR.visible = false
		PlayerManager.no_enemy = true
		PlayerManager.Loop1 = true
		PlayerManager.player = get_tree().current_scene.get_node("Player") 
		#Animation and Camera Manager!!!
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
		if PlayerManager.Loop0:
			PlayerManager.CharacterHintDialog("Oh, must have dozed off. Is the day still not over? It’s always the last day that feels like forever. Might as well pack up.",
			"Click to skip dialog")
		else:
			PlayerManager.startMultiDialog = false
			PlayerManager.MultiDialog(["Oh thank god…oh thank god it was just a dream. Ok…Ok, good. I need to stop pulling all-nighters like that. It’s screwing with my head.",
			"It looks like I already took everything down.",
			"Why would I come back up ... It doesn’t matter, I’m leaving for good"])
