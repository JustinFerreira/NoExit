## No Exit
## Overtime Studios
## Player Manager (autoload "PlayerManager")
## - The shared "what is the player doing right now" state every script
##   reads: settings copied from SettingsManager, which level they are in,
##   the killer, dialog/minigame/hiding/examining modes, the inventory and
##   the equipped item, and the killer-proximity values that drive the
##   scary sounds (ProcessScared).
## - Long-lived progress (loop, milestones, deaths, collected items) lives in
##   GameState; the matching properties here just forward to it.
## - The dialog helpers (Hint, CharacterDialog, ...) forward to UiManager.

extends Node

## Emitted whenever the equipped item changes ("" = nothing equipped).
signal equipped_item_changed(item_name: String)

## SETTINGS (copied in from SettingsManager)

## Mouse look sensitivity.
var Sensitivity: float = 0.01
## Sprint is hold-to-sprint (true) or toggle (false).
var Hold_Shift: bool = false

## Invert mouse up/down (set from the Invert Mouse Y setting).
var InvertY: bool = false

## Camera bob while walking.
var HeadBob: bool = true
## Developer shortcuts (all loops unlocked, dev pause menu). On by default
## during development - turn off for release builds.
var DevMode: bool = true
## Free-roam mode (no story scripting).
var FreeRoam: bool = false
## Hide the crosshair/hand cursor.
var CursorInvisible: bool = false

## Location (which level the player is in)

var Office: bool = false
var ParkingGarage: bool = false
var MainMenu: bool = true

## Player

## Set to make the killer jump to its teleport spot on its next update.
var teleportEnemy: bool = false
## True when the level has no killer (the scary sounds stay silent).
var no_enemy: bool = true
## The player node (set by the player / level).
var player

## How far (walking distance) the nearest enemy that can kill is - worked out
## by ProcessScared() every frame, from every enemy (killer, weeping angel...).
var scaredDistance: float = 999.0
## How scared the player is: 0 = calm (nothing near) .. 1 = an enemy right
## there. Eases toward the target so it never jumps (ProcessScared).
var fear: float = 0.0
## Fear starts this far from an enemy and is full this close (metres).
const FEAR_FAR := 45.0
const FEAR_NEAR := 6.0
## Heartbeat / breathing from fear: they get FASTER much more than louder.
var scaredPitch: float = 1        # heartbeat speed (1 = resting)
var scaredVolume = -80            # heartbeat volume (dB)
var breathTempo: float = 1.0      # breathing speed
var breathVolume = -80            # breathing volume (dB)
var scaredVolumeSteps = -80       # (old) killer step volume - unused now

var sprint_engaged: bool = false
## True from the moment an enemy catches the player.
var dying: bool = false
## Name of the item in hand ("" = nothing).
var EquippedItem: String = ""

## Ids of the items packed into the Box (GameState remembers them, so they
## survive leaving the office). Only .size() and clearing are meaningful.
var DeskItems: Array:
	get: return GameState.get_collected(GameState.STORED)
	set(value):
		if value.is_empty():
			GameState.forget_collected(GameState.STORED)

var firstdialog: bool = true

## Enemy

var Enemy: CharacterBody3D

var stalking_mode: bool = false




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
## A scripted sequence (the elevator ride) has the player: no moving, no
## looking around, and enemies stand still (Enemy). See set_cutscene().
var cutscene: bool = false
var _cutscene_id: int = 0

## Starts / ends a cutscene. Ends by itself after max_seconds whatever happens
## (a scene that never says it's over must not leave the player stuck).
func set_cutscene(on: bool, max_seconds: float = 30.0) -> void:
	cutscene = on
	InAnimation = on
	_cutscene_id += 1
	if on:
		var id := _cutscene_id
		get_tree().create_timer(max_seconds, true).timeout.connect(func():
			if cutscene and _cutscene_id == id:
				push_warning("cutscene never ended - giving control back")
				set_cutscene(false))
## Hiding (HidingSpot): the player is tucked into a hiding spot, no body or movement.
var hiding: bool = false
## ...and enemies can't see them there (Enemy.can_see_player).
var hidden_from_enemies: bool = false
var current_hiding_spot: Node = null

## Pass Checks

## Milestones live in GameState as flags now - these just forward to it so
## old code keeps working. Prefer GameState.has_flag()/set_flag() in new code.
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

## Loop control - one value in GameState.loop now, so these three can never
## disagree. Setting one true moves to that loop; setting the current one
## false leaves it (back to "not in a run").
var OpeningCutscene: bool:
	get: return GameState.loop == GameState.LOOP_OPENING
	set(value): _set_loop_flag(GameState.LOOP_OPENING, value)
var Loop0: bool:
	get: return GameState.loop == 0
	set(value): _set_loop_flag(0, value)
## Loop1 means "past loop 0" (any later loop counts).
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

## Close Up Objects

var examed: bool = false

var examining: bool = false
var ExamingItem: ExaminableItem


var OfficeLights: Array
var ParkingGarageLights: Array


## Backs the old OpeningCutscene / Loop0 setters.
func _set_loop_flag(loop: int, value: bool) -> void:
	if value:
		GameState.loop = loop
	elif GameState.loop == loop:
		GameState.loop = GameState.LOOP_NONE


## Adds an item to the inventory. equippable = it also goes straight into
## the player's hand. (weight is stored with the item but nothing uses it yet.)
## Picking something up also ends the killer's stalking.
func AddToInventory(itemName: String, weight: float, equippable: bool = false):
	var item: Dictionary
	item.name = itemName
	item.weight = weight
	item.equippable = equippable
	if equippable:
		EquippedItem = item.name
		equipped_item_changed.emit(EquippedItem)
	Inventory.append(item)
	if Enemy != null:
		Enemy.exit_stalking_mode()

## takes a name and tries to find it in the inventory
## if found it will remove otherwise it will just return false
func RemoveItemByName(itemName: String) -> bool:
	for item in Inventory:
		if item.name == itemName:
			Inventory.erase(item)
			return true
	return false

## This function sets player stats all back to default
func ResetPlayer() -> void:
	Inventory = []
	sprint_engaged = false
	dying = false
	InAnimation = false
	cutscene = false
	hiding = false
	hidden_from_enemies = false
	current_hiding_spot = null
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
	fear = 0.0

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

## This function is for a type of red Dialog
## that appears at the top of the screen
func Hint(text: String, duration: float = 10.0):
	UiManager.hint(text, duration)

## this is for basic dialog
## without a panel background
func Dialog(text: String):
	UiManager.say_plain(text)

## this function hides all dialog
func HideDialog():
	UiManager.hide_dialog()

## this function shows dialog if it was suppose to
## show up
func RevealDialog():
	UiManager.reveal_dialog()

## basic dialog with a panel behind it
func CharacterDialog(text: String):
	UiManager.say(text)

## this shows both Hint Dialog at the top of the screen
## and character dialog with a panel at the bottom
func CharacterHintDialog(characterText: String, hintText: String):
	UiManager.say_with_hint(characterText, hintText)

## used for MultiDialog to show the next dialog in the squence
## or just end the dialog if finished
func NextDialog():
	UiManager.next_line()

## This take an array of strings so that it can display
## on piece of dialog one after another
func MultiDialog(text_array: Array[String]):
	UiManager.say_lines(text_array)

## turns on MinigameMode and sets up for minigame
func MiniGameModeOn():
	MinigameMode = true
	UiManager.set_cursor_visible(false)
	AudioManager.stop_loop("step")

## turns MinigameMode off and sets player back up for game
func MiniGameModeOff():
	MinigameMode = false
	UiManager.set_cursor_visible(true)

## This is for the Battery Mini Game
## this is to see if the player has won also
## sets up net steps of minigame
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
		UiManager.show_panel("hood", false)
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

## Works out fear from the nearest enemy that can kill the player, then the
## heartbeat / breathing speed and volume from it. Called every physics frame.
func ProcessScared() -> void:
	var target := 0.0
	scaredDistance = 999.0
	if not no_enemy and not cutscene and is_instance_valid(player) and player.is_inside_tree():
		scaredDistance = _nearest_enemy_distance()
		target = clampf((FEAR_FAR - scaredDistance) / (FEAR_FAR - FEAR_NEAR), 0.0, 1.0)
	# rises quicker than it settles
	var rate := 0.05 if target > fear else 0.012
	fear = lerpf(fear, target, rate)
	if fear < 0.02:
		scaredVolume = -80
		breathVolume = -80
	else:
		var f := smoothstep(0.0, 1.0, fear)
		# louder mostly as it gets rapid (fear past halfway)
		scaredVolume = lerpf(-24.0, -5.0, pow(fear, 1.4))
		breathVolume = lerpf(-28.0, -13.0, f)
	scaredPitch = lerpf(1.0, 3.0, fear)
	breathTempo = lerpf(1.0, 1.8, fear)

## Walking distance to the nearest enemy that can kill (straight line, or
## further if its path is longer - another floor feels far away).
func _nearest_enemy_distance() -> float:
	var best := 999.0
	var me: Vector3 = player.global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D) or not e.is_inside_tree() or not e.is_visible_in_tree():
			continue
		if "can_kill_player" in e and not e.can_kill_player:
			continue
		var d: float = me.distance_to(e.global_position)
		if "nav" in e and e.nav and not e.nav.is_navigation_finished() and e.has_method("path_distance"):
			d = maxf(d, e.path_distance())
		best = minf(best, d)
	return best

## Checks player Inventory to see if they
## have an item
func has_item(item_name: String) -> bool:
	for item in Inventory:
		if item.name == item_name:
			return true
	return false

## checks if player has keys and if so
## tries to play car beep sound
## The car is in this level (its key-fob sound player is still there - it's
## freed with the garage, but the reference stays and still counts as true).
func has_car_fob() -> bool:
	return is_instance_valid(car_audio_player) and car_audio_player.is_inside_tree()

func KeyFobSound():
	if not has_car_fob():
		return
	if has_item("Car Keys"):
		car_audio_player.playsound()
	else:
		CharacterDialog(EventManager.key_fob_no_keys)


## stops the focus on an examine item
func EndFocus():
	# Every ExaminableItem registers itself as ExamingItem when examined,
	# so new items don't need to be listed here.
	if ExamingItem and ExamingItem.should_stay_in_focus:
		ExamingItem.end_focus()

## Equips the next (direction = true) or previous equippable item in the
## inventory, wrapping round. Nothing equippable = nothing equipped.
func SwitchEquippedItem(direction: bool):
	_switch_equipped(1 if direction else -1)
	UiManager.on_item_switched()

func _switch_equipped(step: int) -> void:
	var count := Inventory.size()
	var current := -1
	for i in count:
		if Inventory[i].name == EquippedItem:
			current = i
			break
	# with nothing equipped, start just outside the list so step lands on an end
	if current == -1:
		current = -1 if step > 0 else count
	for i in count:
		var index := posmod(current + step * (i + 1), count)
		if Inventory[index].equippable:
			EquippedItem = Inventory[index].name
			equipped_item_changed.emit(EquippedItem)
			return
	EquippedItem = ""
	equipped_item_changed.emit(EquippedItem)
