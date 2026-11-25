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

## ---------------------------------------------------------------------
## Coins and stamina charges (found by searching - see Scripts/Loot/)
## ---------------------------------------------------------------------

## Emitted when the coin count changes.
signal coins_changed(coins: int)
## Coins found (shown in the inventory strip, not an inventory item).
var coins: int = 0

func add_coins(amount: int) -> void:
	coins = maxi(coins + amount, 0)
	coins_changed.emit(coins)
	UiManager.refresh_inventory()

const STAMINA_CHARGE := "Stamina Charge"

## A stamina charge goes in the inventory. It's put in hand only if nothing
## else is (so finding one doesn't swap the keys out); the first one found
## says how to use it.
func add_stamina_charge() -> void:
	var first := not has_item(STAMINA_CHARGE)
	Inventory.append({"name": STAMINA_CHARGE, "weight": 0.0, "equippable": true})
	if EquippedItem == "":
		EquippedItem = STAMINA_CHARGE
		equipped_item_changed.emit(EquippedItem)
	UiManager.refresh_inventory()
	if first and not _told_stamina_charge:
		_told_stamina_charge = true
		Hint("Stamina Charge: hold it (Z / X) and press F to refill your stamina")
var _told_stamina_charge := false

func stamina_charge_count() -> int:
	var n := 0
	for item in Inventory:
		if item.name == STAMINA_CHARGE:
			n += 1
	return n

## ---------------------------------------------------------------------
## Office food and drink (rogue office - OfficeJobs.gd)
## ---------------------------------------------------------------------

## A snack from the vending machine: hold it, F to eat - SNACK_HEAL health.
const SNACK := "Snack"
const SNACK_HEAL := 25.0
## Coffee: stamina full, and it runs down at CAFFEINE_DRAIN of the usual
## rate for CAFFEINE_TIME seconds (Player._update_stamina).
const CAFFEINE_TIME := 90.0
const CAFFEINE_DRAIN := 0.5
var _caffeine_until := 0

func add_snack() -> void:
	Inventory.append({"name": SNACK, "weight": 0.0, "equippable": true})
	if EquippedItem == "":
		EquippedItem = SNACK
		equipped_item_changed.emit(EquippedItem)
	UiManager.refresh_inventory()

## F with a snack in hand: eaten, some health back (not if already full).
func eat_snack() -> void:
	if EquippedItem != SNACK:
		return
	if health >= MAX_HEALTH:
		UiManager.say("I'm not hungry.")
		return
	if not RemoveItemByName(SNACK):
		return
	var before := health
	health = minf(health + SNACK_HEAL, MAX_HEALTH)
	health_changed.emit(health, before - health)   # (negative: healing)
	AudioManager.play_sound(AudioManager.ItemPickup, -8.0)
	if not has_item(SNACK):
		SwitchEquippedItem(true)
	UiManager.refresh_inventory()

func drink_coffee() -> void:
	_caffeine_until = Time.get_ticks_msec() + int(CAFFEINE_TIME * 1000.0)
	if is_instance_valid(player):
		player.stamina = player.max_stamina
		player.fatigue_time_left = 0.0

## Still buzzing from a coffee?
func caffeinated() -> bool:
	return Time.get_ticks_msec() < _caffeine_until

## F with a stamina charge in hand: stamina full, the tiredness gone, one
## charge used up. Works on any level.
func use_stamina_charge() -> void:
	if EquippedItem != STAMINA_CHARGE or not is_instance_valid(player):
		return
	if not RemoveItemByName(STAMINA_CHARGE):
		return
	player.stamina = player.max_stamina
	player.fatigue_time_left = 0.0
	AudioManager.play_sound(AudioManager.ItemPickup, -8.0)
	# none left: hand goes to the next thing
	if not has_item(STAMINA_CHARGE):
		_switch_equipped(1)
	UiManager.refresh_inventory()

## ---------------------------------------------------------------------
## Shields (found by searching): a second chance. Caught with one, the enemy
## is stunned and knocked back instead (Enemy.kill) and the shield breaks.
## ---------------------------------------------------------------------

## Emitted when the shield count changes. used = one just broke saving them.
signal shields_changed(shields: int, used: bool)
const MAX_SHIELDS := 3
var shields: int = 0
## After a shield saves them, nothing can catch them again for this long
## (so a second enemy right there doesn't take the next one straight away).
const SHIELD_GRACE := 1.5
var _shield_grace_until := 0

## Adds a shield. False (nothing added) if they already carry MAX_SHIELDS.
func add_shield() -> bool:
	if shields >= MAX_SHIELDS:
		return false
	shields += 1
	shields_changed.emit(shields, false)
	return true

## Right after a shield saved them: kills don't land.
func shield_protected() -> bool:
	return Time.get_ticks_msec() < _shield_grace_until

## Caught: uses a shield if they have one. True = they're saved.
func use_shield() -> bool:
	if shields <= 0:
		return false
	shields -= 1
	_shield_grace_until = Time.get_ticks_msec() + int(SHIELD_GRACE * 1000.0)
	shields_changed.emit(shields, true)
	return true

## ---------------------------------------------------------------------
## Health: 100, knocked down by enemy grabs (Enemy.kill - rogue mode; the
## story's enemies still kill in one go). Shown by the screen's red tint and
## cracks (DamageOverlay.gd); none left = dead. Full again every round
## (ResetPlayer), and it comes back on its own once the player has kept
## clear of every enemy for a while (REGEN_*, _regen). Coming back doesn't
## undo the grabs: each one this round still makes the next worse
## (RogueRun.grab_damage / struggle_presses / struggle_time).
## ---------------------------------------------------------------------

## Emitted when health changes. hit = how much was just lost (0 = reset to
## full, negative = coming back on its own - see _regen).
signal health_changed(health: float, hit: float)
const MAX_HEALTH := 100.0
var health: float = MAX_HEALTH
## True while an enemy holds the player and they're mashing F to get free
## (Enemy._struggle) - nobody else can grab them meanwhile.
var grabbed := false

## Health comes back once the player has been at least REGEN_DISTANCE
## (metres) from every enemy for REGEN_DELAY seconds straight, at REGEN_RATE
## a second until full. Getting closer than that starts the wait again.
const REGEN_DISTANCE := 20.0
const REGEN_DELAY := 10.0
const REGEN_RATE := 5.0
## Seconds they've been clear of every enemy so far.
var regen_wait := 0.0

func _process(delta: float) -> void:
	_regen(delta)

func _regen(delta: float) -> void:
	if health >= MAX_HEALTH or health <= 0.0 or dying or grabbed or cutscene or not is_instance_valid(player):
		regen_wait = 0.0
		return
	if _enemy_within(REGEN_DISTANCE):
		regen_wait = 0.0
		return
	regen_wait += delta
	if regen_wait < REGEN_DELAY:
		return
	var before := health
	health = minf(health + REGEN_RATE * delta, MAX_HEALTH)
	health_changed.emit(health, before - health)   # negative: healing

## Is any enemy closer than `metres` to the player?
func _enemy_within(metres: float) -> bool:
	var at: Vector3 = player.global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node3D and e.is_inside_tree() and e.global_position.distance_to(at) < metres:
			return true
	return false

## Takes `amount` off. True if they're still alive afterwards.
func take_damage(amount: float) -> bool:
	var before := health
	health = clampf(health - amount, 0.0, MAX_HEALTH)
	regen_wait = 0.0
	health_changed.emit(health, before - health)
	return health > 0.0

## Health to 0 (killed outright).
func lose_all_health() -> void:
	take_damage(health)

func heal_full() -> void:
	health = MAX_HEALTH
	regen_wait = 0.0
	health_changed.emit(health, 0.0)

## Nothing can grab them for `seconds` (just escaped a grab, or a shield
## saved them) - same window as the shield's.
func grant_grace(seconds: float) -> void:
	_shield_grace_until = maxi(_shield_grace_until, Time.get_ticks_msec() + int(seconds * 1000.0))

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
	coins = 0
	coins_changed.emit(coins)
	shields = 0
	shields_changed.emit(shields, false)
	grabbed = false
	heal_full()
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
		# (several of the same thing, like stamina charges, are one stop)
		if Inventory[index].equippable and Inventory[index].name != EquippedItem:
			EquippedItem = Inventory[index].name
			equipped_item_changed.emit(EquippedItem)
			return
	# nothing else to switch to: keep holding what's in hand (if still had)
	if current >= 0 and current < count and Inventory[current].equippable:
		return
	EquippedItem = ""
	equipped_item_changed.emit(EquippedItem)
