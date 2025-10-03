extends Node

## SETTINGS

var Sensitivity: float = 0.01

var Hold_Shift: bool = true

var HeadBob: bool = true

## Player

var player;

## Modes

var MinigameMode = false

var InAnimation = false

## Pass Checks

var gotKeys = false
var minigameOne = false

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
	
	
func ResetInventory() -> void:
	Inventory = []
	CurrentWeight = 0.0
	
func Dialog(text: String, duration: float = 10.0):
	player.get_node("DialogControl").show_temporary_dialog(text,duration)
