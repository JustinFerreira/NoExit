## No Exit
## Overtime Studios
## Office
## - Sets up the office for the current loop: a fresh start (opening
##   cutscene, intro dialog, starting items) or coming back up in the
##   elevator from the garage.

extends Node3D

const ElevatorRide = preload("res://Scripts/Elevator/ElevatorRide.gd")

@onready var player_cubicle: Node3D = $NavigationRegion3D/Cubicle
@onready var animation_player: AnimationPlayer = player_cubicle.get_node("AnimationPlayer")
@onready var cutscene_camera: Camera3D = player_cubicle.get_node("CutSceneCamera")
@onready var player_camera: Camera3D = $Player/Head/Camera3D

func _ready() -> void:
	# the bins under the desks can be searched (coins, stamina charges, notes)
	load("res://Scripts/Loot/LootSpots.gd").attach_bins(self)
	if RogueRun.active and not EventManager.Comingfromelevator:
		_setup_rogue_round()   # a new round (riding back up mid-round arrives by elevator as usual)
		return
	if EventManager.Comingfromelevator:
		if PlayerManager.sprint_engaged:
			PlayerManager.player.is_sprinting = PlayerManager.sprint_engaged
		# Position and facing come from the ElevatorSpawn marker
		# (GameState.change_level).
		EventManager.Comingfromelevator = false
		player_camera.current = true
		animation_player.play("blackoff")
		PlayerManager.no_enemy = true
		PlayerManager.Office = true
		PlayerManager.ParkingGarage = false
		PlayerManager.talkToJanitor = true
		AudioManager.play_music(AudioManager.OfficeWhiteNoise)
		AudioManager.OfficeMusicOn = true
		PlayerManager.startMultiDialog = false
		AnimationManager.ElevatorDoorButtonAnimationPlayer.play("Take 001")
		$Elevator/ElevatorCollisions/DoorCollision.translate(Vector3(0,3,0))
		# Desk items the player took before going down stay gone on their
		# own - each item checks GameState when it loads.
		EventManager.ElevatorDoorOpen = true
		EventManager.CameFromGarage = true
		# came up by the ride cutscene: control comes back as the doors open
		if PlayerManager.cutscene:
			ElevatorRide.arrive_as_doors_open(AnimationManager.ElevatorDoorButtonAnimationPlayer, "Take 001")
	else:
		$Player.position = Vector3(-1.151, 0, 16.523)
		$Player.get_node("Head").get_node("Camera3D").rotation.x = deg_to_rad(-20.0)
		PlayerManager.ResetPlayer()

		AudioManager.play_music(AudioManager.OfficeWhiteNoise)
		AudioManager.OfficeMusicOn = true


		PlayerManager.Office = true
		PlayerManager.ParkingGarage = false

		#Needed?
		PlayerManager.gotKeys = false
		PlayerManager.InAnimation = true;
		UiManager.set_cursor_visible(false)
		PlayerManager.no_enemy = true
		if not PlayerManager.Loop0:
			PlayerManager.Loop1 = true
		PlayerManager.player = get_tree().current_scene.get_node("Player")
		#Animation and Camera Manager!!!
		animation_player.connect("animation_finished", _on_animation_finished)
		cutscene_camera.current = true
		animation_player.play("WakingUp")

func _on_animation_finished(anim_name: String):

	if anim_name == "WakingUp":
		PlayerManager.InAnimation = false
		UiManager.set_cursor_visible(true)
		player_camera.current = true
		if PlayerManager.deaths > 0 && PlayerManager.gotKeys == false:
			PlayerManager.Dialog(EventManager.office_wake_up_no_keys)
		if PlayerManager.Loop0:
			PlayerManager.CharacterDialog(EventManager.office_wake_up_loop0)
			PlayerManager.firstdialog = true
			PlayerManager.player.DIALOG.get_node("MouseClicking").visible = true
		else:
			PlayerManager.firstdialog = false
			PlayerManager.startMultiDialog = false
			PlayerManager.MultiDialog(EventManager.office_wake_up_loop1)

## Rogue mode: every round starts here, waking up at the desk like the story
## (the office is the hub - shops and side games go here later), but with no
## story dialog and no story items on the desk (the keys are already in hand).
func _setup_rogue_round() -> void:
	PlayerManager.player = $Player
	$Player.position = Vector3(-1.151, 0, 16.523)
	$Player.get_node("Head").get_node("Camera3D").rotation.x = deg_to_rad(-20.0)
	for item in ["Box", "CarKeys"]:
		var node := player_cubicle.get_node_or_null(item)
		if node:
			node.queue_free()
	PlayerManager.no_enemy = true
	PlayerManager.Office = true
	PlayerManager.ParkingGarage = false
	PlayerManager.firstdialog = false
	PlayerManager.startMultiDialog = false
	PlayerManager.InAnimation = true
	UiManager.set_cursor_visible(false)
	AudioManager.play_music(AudioManager.OfficeWhiteNoise)
	AudioManager.OfficeMusicOn = true
	animation_player.animation_finished.connect(_on_rogue_wake_up_finished)
	cutscene_camera.current = true
	animation_player.play("WakingUp")

func _on_rogue_wake_up_finished(anim_name: String) -> void:
	if anim_name != "WakingUp":
		return
	PlayerManager.InAnimation = false
	UiManager.set_cursor_visible(true)
	player_camera.current = true
	RogueRun.setup_office(self)
