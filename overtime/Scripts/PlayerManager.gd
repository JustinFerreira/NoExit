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

signal equipped_item_changed(item_name: String)

## SETTINGS

var Sensitivity: float = 0.01

var Hold_Shift: bool = false

# Invert mouse up/down (set from the Invert Mouse Y setting).
var InvertY: bool = false

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


var scaredDistance: float = 0
var scaredPitch: float = 1
var scaredVolume = -80
var scaredVolumeSteps = -80

var sprint_engaged: bool = false

var dying: bool = false

var EquippedItem: String = ''

# Ids of the items packed into the Box (GameState remembers them, so they
# survive leaving the office). Only .size() and clearing are meaningful.
var DeskItems: Array:
	get: return GameState.get_collected(GameState.STORED)
	set(value):
		if value.is_empty():
			GameState.forget_collected(GameState.STORED)

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
# Milestones live in GameState as flags now - these just forward to it so
# old code keeps working. Prefer GameState.has_flag()/set_flag() in new code.
var gotKeys: bool:
	get: return GameState.has_flag(GameState.FLAG_GOT_KEYS)
	set(value): GameState.set_flag(GameState.FLAG_GOT_KEYS, value)
var gotGas_Canister: bool:
	get: return GameState.has_flag(GameState.FLAG_GOT_GAS_CANISTER)
	set(value): GameState.set_flag(GameState.FLAG_GOT_GAS_CANISTER, value)
var gotBattery: bool:
	get: return GameState.has_flag(GameState.FLAG_GOT_BATTERY)
	set(value): GameState.set_flag(GameState.FLAG_GOT_BATTERY, value)
var talkToJanitor: bool:
	get: return GameState.has_flag(GameState.FLAG_TALK_TO_JANITOR)
	set(value): GameState.set_flag(GameState.FLAG_TALK_TO_JANITOR, value)

# Loop control - one value in GameState.loop now, so these three can never
# disagree. Setting one true moves to that loop; setting the current one
# false leaves it (back to "not in a run").
var OpeningCutscene: bool:
	get: return GameState.loop == GameState.LOOP_OPENING
	set(value): _set_loop_flag(GameState.LOOP_OPENING, value)
var Loop0: bool:
	get: return GameState.loop == 0
	set(value): _set_loop_flag(0, value)
# Loop1 means "past loop 0" (any later loop counts).
var Loop1: bool:
	get: return GameState.loop >= 1
	set(value):
		if value:
			if GameState.loop < 1:
				GameState.loop = 1
		elif GameState.loop >= 1:
			GameState.loop = GameState.LOOP_NONE

## Hot Wiring
var minigameOne: bool = false
var minigameOnePassed: bool:
	get: return GameState.has_flag(GameState.FLAG_HOTWIRE_DONE)
	set(value): GameState.set_flag(GameState.FLAG_HOTWIRE_DONE, value)

## Gas Canister
var minigameTwo: bool = false
var minigameTwoPassed: bool:
	get: return GameState.has_flag(GameState.FLAG_GAS_DONE)
	set(value): GameState.set_flag(GameState.FLAG_GAS_DONE, value)

var gasIntakeUI: Control
var gasIntakeSweetSpot: MeshInstance3D
var Gas_Canister: MeshInstance3D
var actioning: bool = false

## Hood / Battery
var minigameThree: bool = false
var minigameThreePassed: bool:
	get: return GameState.has_flag(GameState.FLAG_BATTERY_DONE)
	set(value): GameState.set_flag(GameState.FLAG_BATTERY_DONE, value)
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

var deaths: int:
	get: return GameState.deaths
	set(value): GameState.deaths = value

var Inventory: Array = []
var MaxWeight: float = 10.0
var CurrentWeight: float = 0.0

## Close Up Objects

var examed: bool = false

var closeup: bool = true
var examining: bool = false
var ExamingItem: ExaminableItem


var OfficeLights: Array
var ParkingGarageLights: Array

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# _set_loop_flag
# Backs the old OpeningCutscene / Loop0 setters.
func _set_loop_flag(loop: int, value: bool) -> void:
	if value:
		GameState.loop = loop
	elif GameState.loop == loop:
		GameState.loop = GameState.LOOP_NONE

		

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
		equipped_item_changed.emit(EquippedItem)
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
	InAnimation = false
	if player != null:
		player = get_tree().current_scene.get_node("Player") 
	EquippedItem = ''
	# Inventory is empty again, so every picked-up / stored item comes back.
	GameState.forget_collected()
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
	
	
# EndFocus
# stops the focus on an examine item
func EndFocus():
	# Every ExaminableItem registers itself as ExamingItem when examined,
	# so new items don't need to be listed here.
	if ExamingItem and ExamingItem.should_stay_in_focus:
		ExamingItem.end_focus()
		
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
			equipped_item_changed.emit(EquippedItem)
			return

	# If no equippable items found
	EquippedItem = ''
	equipped_item_changed.emit(EquippedItem)

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
			equipped_item_changed.emit(EquippedItem)
			return

	# If no equippable items found
	EquippedItem = ''
	equipped_item_changed.emit(EquippedItem)
