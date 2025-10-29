extends Node

## SETTINGS

var Sensitivity: float = 0.01

var Hold_Shift: bool = true

var HeadBob: bool = true

var DevMode: bool = false

## Player

var player

var player_rotation_x
var player_rotation_y
var player_rotation_z

var scared = false

## Modes

var FirstOpen = true

var MinigameMode = false

var InAnimation = false

## Pass Checks

var testing = true
var gotKeys = false
var gotGas_Canister = false
var gotBattery = false

## Hot Wiring
var minigameOne = false
var minigameOnePassed = false

## Gas Canister
var minigameTwo = false
var minigameTwoPassed = false

var Gas_Canister
var actioning = false

## Hood / Battery
var minigameThree = false
var minigameThreePassed = false
var PositiveConnected = false
var NegativeConnected = false

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
	MinigameMode = false
	PositiveConnected = false
	NegativeConnected = false
	Inventory = []
	CurrentWeight = 0.0
	minigameOnePassed = false
	minigameTwoPassed = false
	minigameThreePassed = false
	
func Dialog(text: String, duration: float = 10.0):
	player.get_node("DialogControl").show_temporary_dialog(text,duration)
	
func SavePlayerRotation():
	player_rotation_x = player.get_node("Head").rotation.x
	player_rotation_y = player.get_node("Head").rotation.y
	player_rotation_z = player.get_node("Head").rotation.z
	#print(player_rotation_x, player_rotation_y, player_rotation_z)
	
func ApplyPlayerRotation():
	player.get_node("Head").rotation.x = player_rotation_x
	player.get_node("Head").rotation.y = player_rotation_y
	player.get_node("Head").rotation.z = player_rotation_z
	
func MiniGameModeOn():
	MinigameMode = true
	player.visible = false
	player.CURSOR.visible = false
	
func MiniGameModeOff():
	if minigameOne == true:
		MinigameMode = false
		player.CURSOR.visible = true
		return
	MinigameMode = false
	player.visible = true
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
