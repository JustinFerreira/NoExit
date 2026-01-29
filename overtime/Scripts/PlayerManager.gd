## No Exit
## Overtime Studios

extends Node

## SETTINGS

var Sensitivity: float = 0.01

var Hold_Shift: bool = false

var HeadBob: bool = true

var DevMode: bool = true

## Location

var Office = false

var ParkingGarage = false

## Player

var teleportEnemy = false

var no_enemy = true

var player

var player_rotation_x
var player_rotation_y
var player_rotation_z

var scaredDistance = 0
var scaredPitch = 1
var scaredVolume = -80
var scaredVolumeSteps = -80

var sprint_engaged = false

var dying = false

var EquippedItem = null

var DeskItems = []

## Enemy

var Enemy

## Janitor

var janitor

#Dialog Controls

var hint = false

var dialoging = false

var finishedDialogAnimation = false

var multiDialog = false

var startMultiDialog = true

## Modes

var FirstOpen = true

var MinigameMode = false

var InAnimation = false

## Pass Checks

var testing = true
var gotKeys = false
var gotGas_Canister = false
var gotBattery = false
var talkToJanitor = false

# Loop control
var OpeningCutscene = false
var Loop1 = false
var Loop0 = false

## Hot Wiring
var minigameOne = false
var minigameOnePassed = false

## Gas Canister
var minigameTwo = false
var minigameTwoPassed = false

var gasIntakeUI
var gasIntakeSweetSpot
var Gas_Canister
var actioning = false

## Hood / Battery
var minigameThree = false
var minigameThreePassed = false
var PositiveConnected = false
var NegativeConnected = false

var hoodUI
var Hood
var Battery
var PositiveWire
var NegativeWire

## Key fob sound

var car_audio_player

## Death Count

var deaths: int 

var Inventory: Array = []
var MaxWeight: float = 10.0
var CurrentWeight: float = 0.0

## Close Up Objects

var examed = false

var closeup = true
var examining = false
var ExamingItem
var PictureFrame1
var Stapler
var StickyNotes
var Mug1A
var Mug2A

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
		


func AddToInventory(name: String, weight: float, equippable: bool = false):
	var item: Dictionary
	item.name = name
	item.weight = weight
	item.equippable = equippable
	if equippable:
		EquippedItem = item.name
	CurrentWeight += weight
	#print(CurrentWeight)
	Inventory.append(item)
	
func RemoveItemByName(name: String) -> bool:
	for item in Inventory:
		if item.name == name:
			CurrentWeight -= item.weight
			Inventory.erase(item)
			#print(CurrentWeight)
			return true
	#print(CurrentWeight)
	return false
	
	
func ResetPlayer() -> void:
	Inventory = []
	CurrentWeight = 0.0
	sprint_engaged = false
	dying = false
	player = get_tree().current_scene.get_node("Player") 
	EquippedItem = null
	DeskItems = []
	examed = false
	
	if not Loop0:
		AddToInventory("Box", 0.5, true)
		AddToInventory("Car Keys", 0.5, true)
	
	## Location
	
	Office = false
	ParkingGarage = false
	
	##Minigames avtives
	MinigameMode = false
	minigameOne = false
	minigameTwo = false
	minigameThree = false
	gotGas_Canister = false
	gotBattery = false
	
	## Minigames passed
	minigameOnePassed = false
	minigameTwoPassed = false
	minigameThreePassed = false
	PositiveConnected = false
	NegativeConnected = false
	
	Battery = null
	PositiveWire = null
	NegativeWire = null
	
	## Sound Mods
	scaredPitch = 1
	scaredVolume = -80
	
	## Objects
	Gas_Canister = null
	car_audio_player = null
	
	# Dialog
	hint = false
	dialoging = false
	finishedDialogAnimation = false
	multiDialog = false
	startMultiDialog = true
	
	# Close Up
	examining = false
	
	AudioManager.KillerShutUp = false
	
	
## Dialog Functions

func Hint(text: String, duration: float = 10.0):
	text = "Hint: " + text
	player.get_node("DialogControl").show_temporary_dialog(text,duration, "red")
	
func Dialog(text: String):
	hint = false
	player.get_node("DialogControl").player_interact_dialog(text)
	
func HideDialog():
	if player.DIALOG.timer:
		player.DIALOG.timer.stop()
	if finishedDialogAnimation:
		player.DIALOG.animation_player.play("hide")
	finishedDialogAnimation = false
	
func RevealDialog():
	player.DIALOG.visible = true
	player.DIALOG.animation_player.play("reveal")
	finishedDialogAnimation = true
	
func CharacterDialog(text: String):
	hint = false
	player.get_node("DialogControl").player_interact_dialog_pic(text)
	
func CharacterHintDialog(characterText: String, hintText: String):
	hint = true
	player.DIALOG.player_interact_dialog_pic_and_hint(characterText, hintText)

func NextDialog():
	player.get_node("DialogControl").show_next_dialog()
	
func MultiDialog(text_array: Array[String]):
	player.get_node("DialogControl").player_interact_multi_dialog_pic(text_array)

func SavePlayerRotation():
	player_rotation_x = player.get_node("Head").rotation.x
	player_rotation_y = player.get_node("Head").rotation.y
	player_rotation_z = player.get_node("Head").rotation.z
	#print(player_rotation_x, player_rotation_y, player_rotation_z)
	
func ApplyPlayerRotation():
	if player:
		player.get_node("Head").rotation.x = player_rotation_x
		player.get_node("Head").rotation.y = player_rotation_y + PI/2
		player.get_node("Head").rotation.z = player_rotation_z 
	
func MiniGameModeOn():
	MinigameMode = true
	player.CURSOR.visible = false
	AudioManager.stop_loop("step")
	
func MiniGameModeOff():
	MinigameMode = false
	player.CURSOR.visible = true
	
func TestConnection():
	AnimationManager.HideResetZones()
	if PositiveConnected:
		AnimationManager.PositiveConnection.visible = true
	if NegativeConnected:
		AnimationManager.NegativeConnection.visible = true
	if PositiveConnected && NegativeConnected:
		MiniGameModeOff()
		hoodUI.visible = false
		minigameThreePassed = true
		minigameThree = false
		CameraManager.FPCamera.current = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		PositiveWire.visible = false
		NegativeWire.visible = false
		Battery.visible = false
		Hood._on_interaction_complete()
		RemoveItemByName("Battery")
		AnimationManager.HoodCollision.call_deferred("set_disabled", false)
		AnimationManager.CarCollision.call_deferred("set_disabled", false)
		if PlayerManager.Hood.open == true:
			AnimationManager.HoodAnimationPlayer.play_backwards("Hood")
			PlayerManager.Hood.open = false
		if not PlayerManager.minigameOnePassed or (PlayerManager.minigameOnePassed and PlayerManager.minigameTwoPassed and PlayerManager.minigameThreePassed):
			AnimationManager.DoorFlash.start_flashing()
		if not PlayerManager.minigameTwoPassed and PlayerManager.has_item("Gas Canister"):
			AnimationManager.GasIntakeFlash.start_flashing()
		
		
		
		
func ProcessScared():
	if no_enemy:
		scaredVolume = -80
		scaredVolumeSteps = -80
		scaredPitch = 1
		return -80
		
	if scaredDistance > 70:
		scaredVolumeSteps = -80
		scaredVolume = -80
		scaredPitch = 1
	elif scaredDistance > 45:
		scaredVolumeSteps = 4 - scaredDistance
		scaredVolume = -80
		scaredPitch = 1
	else:
		scaredVolumeSteps = 4 - scaredDistance
		scaredVolume = 4 - scaredDistance
		scaredPitch = 4 - (scaredDistance / 10)  
		if scaredPitch < 3:
			scaredPitch = 3
		return 4 
		
		
func has_item(item_name: String) -> bool:
	for item in Inventory:
		if item.name == item_name:
			return true
	return false

func KeyFobSound():
	if has_item("Car Keys"):
		car_audio_player.playsound()
	else:
		CharacterDialog("Damn where did I put those keys?")
	
func EnemyKill():
	Enemy.kill()
	
func EndFocus():
	closeup = !closeup
	if PictureFrame1 and PictureFrame1.should_stay_in_focus && closeup == false:
		PictureFrame1.end_focus()
		
	if Stapler and Stapler.should_stay_in_focus && closeup == false:
		Stapler.end_focus()
		
	if StickyNotes and StickyNotes.should_stay_in_focus && closeup == false:
		StickyNotes.end_focus()
		
	if Mug1A and Mug1A.should_stay_in_focus && closeup == false:
		Mug1A.end_focus()
		
	if Mug2A and Mug2A.should_stay_in_focus && closeup == false:
		Mug2A.end_focus()
		
func SwitchEquippedItem(direction: bool):
	if direction:
		_switch_equipped_up()
	else:
		_switch_equipped_down()
		
func _switch_equipped_up():
	if Inventory.size() == 0:
		EquippedItem = null
		return
	
	var current_index = -1
	# Find current equipped item index
	if EquippedItem != null:
		for i in range(Inventory.size()):
			if Inventory[i].name == EquippedItem:
				current_index = i
				break
	
	# Search upwards from current position
	var search_index = current_index
	for i in range(Inventory.size()):
		search_index = (search_index + 1) % Inventory.size()
		if Inventory[search_index].equippable:
			EquippedItem = Inventory[search_index].name
			return
	
	# If no equippable items found
	EquippedItem = null

func _switch_equipped_down():
	if Inventory.size() == 0:
		EquippedItem = null
		return
	
	var current_index = -1
	# Find current equipped item index
	if EquippedItem != null:
		for i in range(Inventory.size()):
			if Inventory[i].name == EquippedItem:
				current_index = i
				break
	
	# Search downwards from current position
	var search_index = current_index
	for i in range(Inventory.size()):
		search_index = (search_index - 1) % Inventory.size()
		if search_index < 0:
			search_index = Inventory.size() - 1
		if Inventory[search_index].equippable:
			EquippedItem = Inventory[search_index].name
			return
	
	# If no equippable items found
	EquippedItem = null
