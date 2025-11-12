extends Node

## SETTINGS

var Sensitivity: float = 0.01

var Hold_Shift: bool = false

var HeadBob: bool = true

var DevMode: bool = true

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

var Loop1 = false

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

var Hood
var Battery
var PositiveWire
var NegativeWire



## Death Count

var deaths: int 

var Inventory: Array = []
var MaxWeight: float = 10.0
var CurrentWeight: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
		


func AddToInventory(name: String, weight: float):
	var item: Dictionary
	item.name = name
	item.weight = weight
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
	
	##Minigames avtives
	MinigameMode = false
	minigameOne = false
	minigameTwo = false
	minigameThree = false
	
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
	
	# Dialog
	hint = false
	dialoging = false
	finishedDialogAnimation = false
	multiDialog = false
	startMultiDialog = true
	
	
## Dialog Functions

func Hint(text: String, duration: float = 10.0):
	hint = true
	player.get_node("DialogControl").show_temporary_dialog(text,duration, "yellow")
	
func Dialog(text: String):
	hint = false
	player.get_node("DialogControl").player_interact_dialog(text)
	
func HideDialog():
	if player.DIALOG.timer:
		player.DIALOG.timer.stop()
	player.DIALOG.animation_player.play("hide")
	finishedDialogAnimation = false
	
func RevealDialog():
	player.DIALOG.visible = true
	player.DIALOG.animation_player.play("reveal")
	finishedDialogAnimation = true
	
func CharacterDialog(text: String):
	hint = false
	player.get_node("DialogControl").player_interact_dialog_pic(text)

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
	player.get_node("Head").rotation.x = player_rotation_x
	player.get_node("Head").rotation.y = player_rotation_y + PI/2
	player.get_node("Head").rotation.z = player_rotation_z 
	
func MiniGameModeOn():
	MinigameMode = true
	player.CURSOR.visible = false
	AudioManager.stop_loop("step")
	
func MiniGameModeOff():
	if minigameOne == true:
		MinigameMode = false
		player.CURSOR.visible = true
		return
	MinigameMode = false
	player.CURSOR.visible = true
	
func TestConnection():
	if PositiveConnected && NegativeConnected:
		MiniGameModeOff()
		minigameThreePassed = true
		minigameThree = false
		player.CAMERA.current = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		player.prompt.visible = true
		PositiveWire.visible = false
		NegativeWire.visible = false
		Battery.visible = false
		Hood._on_interaction_complete()
		
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
