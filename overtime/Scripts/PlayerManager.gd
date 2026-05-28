## No Exit
## Overtime Studios
## Last updated 3/16/26 by Justin Ferreira
## Player Manager Script
## - this script keeps a lot of settings variables
## also has modes, location of player,
## enemy,
## volume stuff
## close up object variables
## states of player
## functions for major player functions and gameplay

extends Node

## SETTINGS

var Sensitivity: float = 0.01

var Hold_Shift: bool = false

var HeadBob: bool = true

var DevMode: bool = true

var FreeRoam: bool = false

var CursorInvisible: bool = false

## Location

var Office: bool = false

var ParkingGarage: bool = false

var NotClickOnBoxSpace: bool

var MainMenu: bool = true

## Player

var teleportEnemy: bool = false

var no_enemy: bool = true

var player

var player_rotation_x: float
var player_rotation_y: float
var player_rotation_z: float

var scaredDistance: float = 0
var scaredPitch: float = 1
var scaredVolume = -80
var scaredVolumeSteps = -80

var sprint_engaged: bool = false

var dying: bool = false

var EquippedItem: String = ''

var DeskItems: Array[ExaminableItem] = []

var firstdialog: bool = true

## Enemy

var Enemy: CharacterBody3D

var stalking_mode: bool = false

var killer_visible: bool = true

var killer_audible: bool = true


## Janitor

var janitor: Interactable

#Dialog Controls

var hint: bool = false

var dialoging: bool = false

var finishedDialogAnimation: bool = false

var multiDialog: bool = false

var startMultiDialog: bool = true

## Modes

var FirstOpen: bool = true

var MinigameMode: bool = false

var InAnimation: bool = false

## Pass Checks

var testing: bool = true
var gotKeys: bool = false
var gotGas_Canister: bool = false
var gotBattery: bool = false
var talkToJanitor: bool = false

# Loop control
var OpeningCutscene: bool = false
var Loop1: bool = false
var Loop0: bool = false

## Hot Wiring
var minigameOne: bool = false
var minigameOnePassed: bool = false

## Gas Canister
var minigameTwo: bool = false
var minigameTwoPassed: bool = false

var gasIntakeUI: Control
var gasIntakeSweetSpot: MeshInstance3D
var Gas_Canister: MeshInstance3D
var actioning: bool = false

## Hood / Battery
var minigameThree: bool = false
var minigameThreePassed: bool = false
var PositiveConnected: bool = false
var NegativeConnected: bool = false

var hoodUI: Control
var Hood: Interactable
var Battery: MeshInstance3D
var PositiveWire: StaticBody3D
var NegativeWire: StaticBody3D

## Key fob sound

var car_audio_player: AudioStreamPlayer3D

## Death Count

var deaths: int 

var Inventory: Array = []
var MaxWeight: float = 10.0
var CurrentWeight: float = 0.0

## Close Up Objects

var examed: bool = false

var closeup: bool = true
var examining: bool = false
var ExamingItem: ExaminableItem
var PictureFrame1: ExaminableItem
var Stapler: ExaminableItem
var StickyNotes: ExaminableItem
var Mug1A: ExaminableItem
var Mug2A: ExaminableItem
var Keys: ExaminableItem
var Box: ExaminableItem
var BatteryExamine: ExaminableItem
var GasCanisterExamine: ExaminableItem


var OfficeLights: Array
var ParkingGarageLights: Array

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

		

# AddToInventory
# this function takes in the parameters
# name, weight, equippable,
# weight currently useless
# then adds this to the inventory list
func AddToInventory(itemName: String, weight: float, equippable: bool = false):
	var item: Dictionary
	item.name = itemName
	item.weight = weight
	item.equippable = equippable
	if equippable:
		EquippedItem = item.name
	CurrentWeight += weight
	#print(CurrentWeight)
	Inventory.append(item)
	if Enemy != null:
		Enemy.exit_stalking_mode()
	
# RemoveItemByName
# takes a name and tries to find it in the inventory
# if found it will remove otherwise it will just return false
func RemoveItemByName(itemName: String) -> bool:
	for item in Inventory:
		if item.name == itemName:
			CurrentWeight -= item.weight
			Inventory.erase(item)
			#print(CurrentWeight)
			return true
	#print(CurrentWeight)
	return false
	
# ResetPlayer
# This function sets player stats all back to default
func ResetPlayer() -> void:
	Inventory = []
	CurrentWeight = 0.0
	sprint_engaged = false
	dying = false
	if player != null:
		player = get_tree().current_scene.get_node("Player") 
	EquippedItem = ''
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
	
	# EventManager
	EventManager.Comingfromelevator = false
	EventManager.ElevatorDoorOpen = false
	EventManager.CameFromGarage = false
	
	
## Dialog Functions

# Hint
# This function is for a type of red Dialog
# that appears at the top of the screen 
func Hint(text: String, duration: float = 10.0):
	text = "Hint: " + text
	player.get_node("DialogControl").show_temporary_dialog(text,duration, "red")
	
# Dialog
# this is for basic dialog 
# without a panel background
func Dialog(text: String):
	hint = false
	player.get_node("DialogControl").player_interact_dialog(text)
	
# HideDialog
# this function hides all dialog
func HideDialog():
	if player.DIALOG.timer:
		player.DIALOG.timer.stop()
	if finishedDialogAnimation:
		player.DIALOG.animation_player.play("hide")
	finishedDialogAnimation = false
	
# RevealDialog
# this function shows dialog if it was suppose to
# show up
func RevealDialog():
	player.DIALOG.visible = true
	player.DIALOG.animation_player.play("reveal")
	finishedDialogAnimation = true
	
# CharacterDialog
# basic dialog with a panel behind it
func CharacterDialog(text: String):
	hint = false
	player.get_node("DialogControl").player_interact_dialog_pic(text)

# CharacterHintDialog
# this shows both Hint Dialog at the top of the screen
# and character dialog with a panel at the bottom
func CharacterHintDialog(characterText: String, hintText: String):
	hint = true
	player.DIALOG.player_interact_dialog_pic_and_hint(characterText, hintText)

# NextDialog
# used for MultiDialog to show the next dialog in the squence 
# or just end the dialog if finished
func NextDialog():
	player.get_node("DialogControl").show_next_dialog()
	
# MultiDialog
# This take an array of strings so that it can display
# on piece of dialog one after another
func MultiDialog(text_array: Array[String]):
	player.get_node("DialogControl").player_interact_multi_dialog_pic(text_array)

# SavePlayerRotation
# Use for when changing scenes to keep the player facing the saem direction
# this messes with the player mesh rotation
func SavePlayerRotation():
	player_rotation_x = player.get_node("Head").rotation.x
	player_rotation_y = player.get_node("Head").rotation.y
	player_rotation_z = player.get_node("Head").rotation.z
	#print(player_rotation_x, player_rotation_y, player_rotation_z)
	
# ApplyPlayerRotation
# When entering a new scene this is used to have the same rotation
# as the last scene
func ApplyPlayerRotation():
	if player and not EventManager.Comingfromelevator:
		player.get_node("Head").rotation.x = player_rotation_x
		player.get_node("Head").rotation.y = player_rotation_y + PI/4
		player.get_node("Head").rotation.z = player_rotation_z 
	else:
		player.get_node("Head").rotation.x = player_rotation_x
		player.get_node("Head").rotation.y = player_rotation_y - PI/4
		player.get_node("Head").rotation.z = player_rotation_z 
	
# MiniGameModeOn
# turns on MinigameMode and sets up for minigame
func MiniGameModeOn():
	MinigameMode = true
	player.CURSOR.visible = false
	AudioManager.stop_loop("step")
	
# MiniGameModeOff
# turns MinigameMode off and sets player back up for game
func MiniGameModeOff():
	MinigameMode = false
	if not PlayerManager.CursorInvisible:
		player.CURSOR.visible = true
	
# TestConnection
# This is for the Battery Mini Game
# this is to see if the player has won also 
# sets up net steps of minigame
func TestConnection():
	AnimationManager.HideResetZones()
	if PositiveConnected:
		AnimationManager.PositiveConnection.visible = true
	if NegativeConnected:
		AnimationManager.NegativeConnection.visible = true
	if PositiveConnected && NegativeConnected:
		if Enemy && Enemy.stalking_mode:
			Enemy.exit_stalking_mode()
		AudioManager.play_sound(AudioManager.HoodOpen)
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
		
# ProcessScared
# gets the values for volumes of sounds
# related to killer and player proximity
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
		
# has_item
# Checks player Inventory to see if they
# have an item
func has_item(item_name: String) -> bool:
	for item in Inventory:
		if item.name == item_name:
			return true
	return false

# KeyFobSound
# checks if player has keys and if so
# tries to play car beep sound
func KeyFobSound():
	if has_item("Car Keys"):
		car_audio_player.playsound()
	else:
		CharacterDialog(EventManager.key_fob_no_keys)
	
# EnemyKill
# Starts the enemy killing the player
func EnemyKill():
	Enemy.kill()
	
# EndFocus
# stops the focus on an examine item
func EndFocus():
	closeup = !closeup
	if Office && PictureFrame1: 
		if PictureFrame1.should_stay_in_focus && closeup == false:
			PictureFrame1.end_focus()
		
	if Office && Stapler:
		if Stapler.should_stay_in_focus && closeup == false:
			Stapler.end_focus()
		
	if Office && StickyNotes:
		if StickyNotes.should_stay_in_focus && closeup == false:
			StickyNotes.end_focus()
		
	if Office && Mug1A:
		if Mug1A.should_stay_in_focus && closeup == false:
			Mug1A.end_focus()
		
	if Office && Mug2A:
		if Mug2A.should_stay_in_focus && closeup == false:
			Mug2A.end_focus()
		
	if Office && Keys:
		if Keys.should_stay_in_focus && closeup == false:
			Keys.end_focus()
		
	if Office && Box:
		if Box.should_stay_in_focus && closeup == false:
			Box.end_focus()
		
	if ParkingGarage && BatteryExamine:
		if BatteryExamine.should_stay_in_focus && closeup == false:
			BatteryExamine.end_focus()
			
	if ParkingGarage and GasCanisterExamine:
		if GasCanisterExamine.should_stay_in_focus and closeup == false:
			GasCanisterExamine.end_focus()
		
# SwitchEquippedItem
# changes the players equipped item
func SwitchEquippedItem(direction: bool):
	if direction:
		_switch_equipped_up()
	else:
		_switch_equipped_down()
		
# _switch_equipped_up
# assist in switching equip item this will switch item that are higher
# in the list 
func _switch_equipped_up():
	if Inventory.size() == 0:
		EquippedItem = ''
		return
	
	var current_index = -1
	# Find current equipped item index
	if EquippedItem != '':
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
	EquippedItem = ''

# _switch_equipped_down
# assist in switching equip item this will switch item that are lower
# in the list 
func _switch_equipped_down():
	if Inventory.size() == 0:
		EquippedItem = ''
		return
	
	var current_index = -1
	# Find current equipped item index
	if EquippedItem != '':
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
	EquippedItem = ''
