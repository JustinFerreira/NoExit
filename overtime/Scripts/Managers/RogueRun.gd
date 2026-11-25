## No Exit
## Overtime Studios
## Rogue Run (autoload "RogueRun")
## - The rogue-like mode: survive round after round of fixing your car.
##   Each round starts in the office (the hub - shops and side games go
##   here later); take the elevator down, find what the car needs, fix it
##   and start the car to win the round. Dying ends the run.
## - Every round rolls which problems the car has (gas, battery, flat tire)
##   and how many - more as the rounds go on - and the killer gets faster
##   and closer. The parts spawn around the garage; the toll booth on the
##   bottom floor is the most common spot, less so in later rounds.
## - Uses the correctly sized levels (Office_Fitted, ParkingGarage_Fitted).

extends Node

## Emitted when a round starts (in the office).
signal round_started(round_number: int, problems: Array)
## Emitted when the car starts and the round is won.
signal round_won(round_number: int)
## Emitted when the player dies (rounds won so far).
signal run_ended(rounds_survived: int)

const OFFICE := "res://Levels/Fitted/Office_Fitted.tscn"
const GARAGE := "res://Levels/Fitted/ParkingGarage_Fitted.tscn"
const SAVE_PATH := "user://rogue.cfg"

## Car problems.
const GAS := "gas"
const BATTERY := "battery"
const TIRE := "tire"
const ALL_PROBLEMS: Array[String] = [GAS, BATTERY, TIRE]
## How each problem is described to the player.
const PROBLEM_NAMES := {GAS: "an empty gas tank", BATTERY: "a dead battery", TIRE: "a flat tire"}
## The inventory item that fixes each problem.
const PROBLEM_ITEMS := {GAS: "Gas Canister", BATTERY: "Battery", TIRE: "Spare Tire"}

@export_group("Difficulty")
## Rogue killers' speed, times the story's (every round - their chase,
## trailing and lunge).
@export var killer_speed_base: float = 1.1
## Extra killer speed per round from the speed rounds on (0.07 = 7% faster
## each round).
@export var killer_speed_per_round: float = 0.07
## The killer never gets faster than this many times its normal speed.
@export var killer_speed_max: float = 1.6
## How far short of the player the killer stops in round 1 (the story uses
## 20); it closes in by follow_distance_per_round every round after.
@export var follow_distance_start: float = 20.0
@export var follow_distance_per_round: float = 3.0
## Chance (0-1) a part spawns in the toll booth in round 2 (round 1 always
## puts them there); it drops by hub_chance_per_round every round after,
## down to hub_chance_min.
@export var hub_chance_start: float = 0.75
@export var hub_chance_per_round: float = 0.12
@export var hub_chance_min: float = 0.15
## Parts never spawn closer than this to the car (garage units).
@export var min_distance_from_car: float = 10.0

@export_group("Enemies")
## Rounds 1..lenient_rounds are forgiving: an enemy can grab the player any
## time it only hurts (grab_survivable), but a grab that would kill them needs
## them caught in a trap or standing still too long (still_limit) - otherwise
## it closes in and looms (Enemy.HOLD_OFF) but can't touch them.
@export var lenient_rounds: int = 4
## Rounds 1..minigame_safe_rounds: nobody can be killed during a minigame.
@export var minigame_safe_rounds: int = 5
## Standing still this long (seconds) lets them get you in round 1; a second
## less each round, down to still_limit_min.
@export var still_limit_start: float = 8.0
@export var still_limit_min: float = 3.5
## Enemies start at least this far from the player (garage units).
@export var enemy_spawn_distance: float = 60.0
## A wandering (hunter) killer picking where to look next heads for near
## the player's real spot (within hunch_radius) this often: hunch_chance_start
## in round 1, more each round, up to hunch_chance_max.
@export var hunch_chance_start: float = 0.3
@export var hunch_chance_per_round: float = 0.03
@export var hunch_chance_max: float = 0.6
@export var hunch_radius: float = 14.0

func hunch_chance() -> float:
	return minf(hunch_chance_start + hunch_chance_per_round * (round_number - 1), hunch_chance_max)

@export_group("Grabs")
## Being caught is a grab, not the end: it takes grab_damage off the
## player's 100 health (none left = dead), then they mash F to break free
## (Enemy._struggle) - fail and they're killed. From one_hit_round on, a grab
## kills outright again.
@export var one_hit_round: int = 25
## Health a grab takes in round 1, more each round, up to grab_damage_max.
@export var grab_damage_start: float = 25.0
@export var grab_damage_per_round: float = 1.5
@export var grab_damage_max: float = 50.0
## Extra health every grab already this round takes on top (health coming
## back doesn't undo it - the next grab still hits harder), up to
## grab_damage_cap all told.
@export var grab_damage_per_grab: float = 8.0
@export var grab_damage_cap: float = 75.0
## F presses needed to break free: struggle_presses_start in round 1, more
## each round and more for every time they've already been grabbed this
## round - never more than struggle_presses_max.
@export var struggle_presses_start: int = 7
@export var struggle_presses_per_round: float = 0.5
@export var struggle_presses_per_grab: int = 3
@export var struggle_presses_max: int = 26
## Seconds they get to do it: struggle_time_start in round 1, less each
## round and each grab this round, never under struggle_time_min.
@export var struggle_time_start: float = 3.5
@export var struggle_time_per_round: float = 0.08
@export var struggle_time_per_grab: float = 0.3
@export var struggle_time_min: float = 2.2
## Broken free: the enemy is staggered back this long (random in range;
## shorter in hard rounds) and nothing can grab them for ESCAPE_GRACE.
@export var escape_stun_easy := Vector2(3.0, 5.0)
@export var escape_stun_hard := Vector2(1.5, 2.5)
const ESCAPE_GRACE := 1.5

## Grabs so far this round (each makes the next struggle harder).
var grabs_this_round := 0

## The office's people this run - the staff roster and their lost-item
## requests (Scripts/Office/OfficeQuests.gd keeps it). Empty on a new run.
var office_data := {}

## Does a grab hurt (and can be struggled out of) instead of killing? Rogue
## mode, before one_hit_round.
func grabs_hurt() -> bool:
	return active and round_number < one_hit_round

## Would a grab right now leave the player alive (it only hurts)?
func grab_survivable() -> bool:
	return grabs_hurt() and PlayerManager.health > grab_damage()

func grab_damage() -> float:
	var base := minf(grab_damage_start + grab_damage_per_round * (round_number - 1), grab_damage_max)
	return minf(base + grab_damage_per_grab * grabs_this_round, grab_damage_cap)

## F presses needed to break free from this grab (call before counting it).
func struggle_presses() -> int:
	var n := struggle_presses_start + int(struggle_presses_per_round * (round_number - 1)) + struggle_presses_per_grab * grabs_this_round
	return mini(n, struggle_presses_max)

func struggle_time() -> float:
	return maxf(struggle_time_start - struggle_time_per_round * (round_number - 1) - struggle_time_per_grab * grabs_this_round, struggle_time_min)

func escape_stun_time() -> float:
	var k := clampf(float(round_number - 1) / float(STUN_HARD_ROUND - 1), 0.0, 1.0) if active else 0.0
	return randf_range(lerpf(escape_stun_easy.x, escape_stun_hard.x, k), lerpf(escape_stun_easy.y, escape_stun_hard.y, k))

## True while a run is going.
const EventDirector = preload("res://Scripts/Events/EventDirector.gd")
const EnemyNoise = preload("res://Scripts/Enemies/EnemyNoise.gd")

var active := false
## The current round (1 = first).
var round_number := 0
## The janitor walks up and talks to the player at the elevator button only on
## the first round (false), or every round (true).
var janitor_every_round := false

## Should the janitor stop the player at the elevator button this round?
func janitor_talks_this_round() -> bool:
	return janitor_every_round or round_number <= 1
## This round's problems (some of GAS, BATTERY, TIRE).
var problems: Array[String] = []
## Most rounds survived in any run (saved).
var best_rounds := 0
## The flat tire has been changed this round.
var tire_fixed := false

func _ready() -> void:
	_load_best()

## ---------------------------------------------------------------------
## Run flow
## ---------------------------------------------------------------------

## Starts a new run at round 1 (from the main menu or the game over screen).
func start_run() -> void:
	active = true
	_last_lineup = ""
	GameState.clear_preloads()
	EventDirector.new_run()   # rare garage events can happen again
	round_number = 1
	GameState.forget_notes()
	PlayerManager.deaths = 0
	PlayerManager.coins = 0   # coins last the whole run (kept between rounds)
	office_data = {}          # a new office staff, no requests yet
	_begin_round()

## Dev (Enemies page): a line-up of its own - [{kind, speed, starer}] - used
## instead of the rolled one at the next round start (or every round).
var dev_plan: Array = []
var dev_illusions := false
var dev_plan_every_round := false

## Dev: jumps straight to round `n` (starting a run if there isn't one) - its
## problems, enemies and rules are rolled as for that round. In the office,
## or straight into the garage.
func dev_jump_to_round(n: int, to_garage: bool = false) -> void:
	if not active:
		active = true
		_last_lineup = ""
		GameState.clear_preloads()
		EventDirector.new_run()
		GameState.forget_notes()
		PlayerManager.deaths = 0
	round_number = maxi(n, 1)
	_begin_round(GARAGE if to_garage else OFFICE)

## The car started: the round is won, on to the next one (back in the office).
func complete_round() -> void:
	round_won.emit(round_number)
	_save_best(round_number)
	round_number += 1
	_begin_round()

## The player died: the run is over. Returns how many rounds they survived.
func end_run() -> int:
	var survived := maxi(round_number - 1, 0)
	_save_best(survived)
	active = false
	run_ended.emit(survived)
	return survived

## Leaves rogue mode (back to the main menu).
func quit_run() -> void:
	if active:
		end_run()

func _begin_round(level: String = OFFICE) -> void:
	problems = roll_problems(round_number)
	tire_fixed = not problems.has(TIRE)
	grabs_this_round = 0
	GameState.clear_all_flags()
	GameState.loop = 1
	SettingsManager.KillerDisabled = false
	PlayerManager.MainMenu = false
	var coins := PlayerManager.coins
	PlayerManager.ResetPlayer()       # fresh inventory, nothing fixed
	PlayerManager.add_coins(coins)    # ...but the coins found so far stay
	PlayerManager.RemoveItemByName("Box")   # story item - just the keys in rogue mode
	PlayerManager.talkToJanitor = true   # (the janitor decides when he loads - see janitor_talks_this_round)
	PlayerManager.player = null       # nothing to carry over between rounds
	AudioManager.cancel_music()
	AudioManager.cancel_loop_sfx()
	AudioManager.KillerShutUp = false
	get_tree().paused = false
	enemy_plan = plan_round(round_number)
	# the dev menu's own line-up (Enemies page) wins - once, or every round
	if not dev_plan.is_empty():
		enemy_plan = dev_plan.duplicate(true)
		illusions = dev_illusions
		if not dev_plan_every_round:
			dev_plan = []
	round_started.emit(round_number, problems)
	GameState.change_level(level)   # the office wakes the player up at their desk

## Picks this round's problems: 1 in round 1, up to all 3 from round 5.
func roll_problems(round_index: int) -> Array[String]:
	var count := 1
	if round_index >= 5:
		count = 3
	elif round_index >= 3:
		count = 2 + (1 if randf() < 0.35 * (round_index - 2) else 0)
	elif round_index == 2:
		count = 1 + (1 if randf() < 0.5 else 0)
	var pool := ALL_PROBLEMS.duplicate()
	pool.shuffle()
	var out: Array[String] = []
	for i in mini(count, pool.size()):
		out.append(pool[i])
	return out

## True if this round's problem is fixed (or wasn't a problem this round).
func is_fixed(problem: String) -> bool:
	match problem:
		GAS: return PlayerManager.minigameTwoPassed
		BATTERY: return PlayerManager.minigameThreePassed
		TIRE: return tire_fixed
	return true

## This round's problems that still need fixing.
func unfixed_problems() -> Array[String]:
	var out: Array[String] = []
	for p in problems:
		if not is_fixed(p):
			out.append(p)
	return out

## "an empty gas tank and a flat tire" style list.
func describe(list: Array[String]) -> String:
	var names: Array[String] = []
	for p in list:
		names.append(PROBLEM_NAMES.get(p, p))
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]

## ---------------------------------------------------------------------
## Difficulty
## ---------------------------------------------------------------------

## How much faster than normal the killer is this round.
## How long a shield stuns an enemy (Enemy.stun_from): random every time,
## from a range that shrinks as the rounds get harder - stun_time_easy in
## round 1 down to stun_time_hard from STUN_HARD_ROUND on. Always kept
## within STUN_LIMITS. (Story mode: the round 1 range.)
@export var stun_time_easy := Vector2(10.0, 30.0)
@export var stun_time_hard := Vector2(2.0, 8.0)
const STUN_HARD_ROUND := 12
const STUN_LIMITS := Vector2(2.0, 30.0)

func stun_time() -> float:
	var k := 0.0
	if active:
		k = clampf(float(round_number - 1) / float(STUN_HARD_ROUND - 1), 0.0, 1.0)
	var lo := lerpf(stun_time_easy.x, stun_time_hard.x, k)
	var hi := lerpf(stun_time_easy.y, stun_time_hard.y, k)
	return clampf(randf_range(lo, hi), STUN_LIMITS.x, STUN_LIMITS.y)

func killer_speed_scale() -> float:
	if not active:
		return 1.0
	# a grab doesn't kill any more, so it's quicker than the story's from the
	# start; no speeding up until the speed rounds (see plan_enemies) - then a
	# little each round
	if round_number < SPEED_ROUND:
		return killer_speed_base
	return minf(killer_speed_base + killer_speed_per_round * (round_number - SPEED_ROUND + 1), killer_speed_max)

## How far short of the player the killer stops this round.
func killer_follow_distance() -> float:
	# never so close it idles within its own reach (KILLER_KILL_REACH)
	return maxf(follow_distance_start - follow_distance_per_round * (round_number - 1), 9.0)

## Chance a part spawns in the toll booth this round. Round 1 always (the
## hint sends the player there); after that hub_chance_start for round 2,
## dropping by hub_chance_per_round a round, down to hub_chance_min.
func hub_chance() -> float:
	if round_number <= 1:
		return 1.0
	return maxf(hub_chance_start - hub_chance_per_round * (round_number - 2), hub_chance_min)

## ---------------------------------------------------------------------
## Levels
## ---------------------------------------------------------------------

## Where the office elevator goes (the rogue garage during a run).
func garage_scene(story_path: String) -> String:
	return GARAGE if active else story_path

## Where the garage elevator goes (the rogue office during a run).
func office_scene(story_path: String) -> String:
	return OFFICE if active else story_path

## Called by the office when it loads during a run: the round banner.
func setup_office(_office: Node) -> void:
	var text := "Round %d - the car has %s." % [round_number, describe(problems)]
	if round_number == 1:
		text += " Take the elevator down to the garage."
	PlayerManager.Hint(text, 12.0)

## Called by the parking garage when it loads during a run: marks what
## isn't broken as fixed, places the parts that are needed, puts the flat
## tire on the car and tunes the killer.
func setup_garage(garage: Node) -> void:
	PlayerManager.minigameOnePassed = true   # you have the keys - no hot-wire
	if not problems.has(GAS):
		PlayerManager.minigameTwoPassed = true
	if not problems.has(BATTERY):
		PlayerManager.minigameThreePassed = true
	for e in garage.get_tree().get_nodes_in_group("enemy"):
		if "follow_distance" in e:
			e.follow_distance = killer_follow_distance()
	# the navigation map isn't ready on the level's first frame (and on a
	# reload it still holds the last level for a moment) - wait for it
	var region := garage.find_children("*", "NavigationRegion3D", true, false)
	if region.size() > 0:
		var map: RID = region[0].get_navigation_map()
		await HelperManager.nav_map_updated(garage.get_tree(), map)
	if not is_instance_valid(garage):
		return
	var spots := _spawn_spots(garage, problems.size())
	var i := 0
	for p in ALL_PROBLEMS:
		var item := _part_node(garage, p)
		if not problems.has(p):
			if item:
				item.queue_free()
			continue
		if item and i < spots.size():
			var spot: Vector3 = spots[i]
			# in the toll booth, keep a big part (the tire) clear of its walls
			var booth = garage.get_tree().get_first_node_in_group("toll_booth")
			if booth and p == TIRE and booth.is_inside(spot):
				spot = _fit_tire_in_booth(booth, spot, _spare_tire_radius(item) + 0.08)
			item.global_position = spot
			item.rotation.y = randf() * TAU
			i += 1
	if problems.has(TIRE):
		_make_flat_tire(garage)
	# the enemies: who, how fast, and where (far away); the wanderers keep
	# coming back to the car and the parts
	points_of_interest.clear()
	var car_node := _car(garage)
	if car_node:
		points_of_interest.append(car_node.global_position)
	for prob in problems:
		# (asking _part_node for the tire would make another spare tire)
		var part: Node3D = garage.find_child("SpareTire", true, false) if prob == TIRE else _part_node(garage, prob)
		if part:
			points_of_interest.append(part.global_position)
	var the_booth = garage.get_tree().get_first_node_in_group("toll_booth")
	if the_booth:
		points_of_interest.append(the_booth.global_position)
	_setup_enemies(garage)
	PlayerManager.Hint("The car has %s. Find what you need - start with the toll booth on the bottom floor." % describe(problems), 10.0)

## The node to move for each part (made here for the spare tire).
func _part_node(garage: Node, problem: String) -> Node3D:
	match problem:
		GAS: return garage.get_node_or_null("GasCanisterPickUp")
		BATTERY: return garage.get_node_or_null("BatteryPickup")
		TIRE: return _make_spare_tire(garage)
	return null

## n spots: each one in the toll booth (hub_chance) or somewhere random on
## the garage's navigation mesh, away from the car, never the same spot twice.
func _spawn_spots(garage: Node, n: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var booth = garage.get_tree().get_first_node_in_group("toll_booth")
	var hub: Array[Vector3] = booth.hub_points() if booth else []
	hub.shuffle()
	var car := _car(garage)
	var region := garage.find_children("*", "NavigationRegion3D", true, false)
	var map: RID = region[0].get_navigation_map() if region.size() > 0 else RID()
	for k in n:
		if not hub.is_empty() and randf() < hub_chance():
			out.append(hub.pop_back())
			continue
		var spot := Vector3.INF
		for attempt in 40:
			if not map.is_valid():
				break
			var p := NavigationServer3D.map_get_random_point(map, 1, true)
			if p == Vector3.ZERO:
				continue
			if car and p.distance_to(car.global_position) < min_distance_from_car:
				continue
			if booth and booth.is_inside(p):
				continue
			var far_enough := true
			for q in out:
				if q.distance_to(p) < 3.0:
					far_enough = false
			if far_enough:
				spot = p
				break
		if spot == Vector3.INF:
			spot = hub.pop_back() if not hub.is_empty() else (car.global_position + Vector3(4, 0, 0) if car else Vector3.ZERO)
		out.append(spot)
	return out

func _car(garage: Node) -> Node3D:
	return garage.find_child("Car", true, false) as Node3D

## A spare tire to pick up: a copy of one of the car's wheels, lying flat.
func _make_spare_tire(garage: Node) -> Node3D:
	var car := _car(garage)
	var wheel := car.find_child("Tire_1", true, false) as MeshInstance3D if car else null
	if wheel == null:
		return null
	# laid out like every examinable item (see ExaminableItem.gd):
	#   SpareTire (Node3D) > TireMesh (MeshInstance3D) > StaticBody3D (ExaminableItem)
	var root := Node3D.new()
	root.name = "SpareTire"
	var mesh := MeshInstance3D.new()
	mesh.name = "TireMesh"
	mesh.mesh = wheel.mesh
	mesh.material_override = wheel.material_override
	for s in wheel.get_surface_override_material_count():
		mesh.set_surface_override_material(s, wheel.get_surface_override_material(s))
	root.add_child(mesh)
	var item := StaticBody3D.new()
	item.name = "StaticBody3D"
	item.set_script(load("res://Scripts/Interactables/ExaminableItem.gd"))
	item.has_outline = true
	item.examine_dialog = "Awesome a tire"
	item.darken_background = true
	item.pickup_on_close = true
	item.inventory_name = PROBLEM_ITEMS[TIRE]
	item.inventory_weight = 1.0
	item.pickup_sound = AudioManager.ItemPickup
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = wheel.mesh.get_aabb().size
	shape.shape = box
	shape.position = wheel.mesh.get_aabb().get_center()
	item.add_child(shape)
	mesh.add_child(item)
	garage.add_child(root)
	# same size as the car's wheel, turned to lie on its side, resting on the floor
	var scale := wheel.global_basis.get_scale()
	mesh.global_basis = Basis(Vector3.FORWARD, PI / 2.0) * Basis.from_scale(scale)
	var aabb: AABB = mesh.global_transform * mesh.get_aabb()
	mesh.position -= Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z) - root.global_position
	return root

## A spot in the booth the tire fits at without poking through a wall: this
## one nudged clear of the walls, or failing that the roomiest booth spot.
func _fit_tire_in_booth(booth: Node, spot: Vector3, radius: float) -> Vector3:
	var fitted: Vector3 = booth.fit_inside(spot, radius)
	if booth.clearance(fitted) >= radius - 0.02:
		return fitted
	var best := fitted
	var best_room: float = booth.clearance(fitted)
	for h in booth.hub_points():
		var f: Vector3 = booth.fit_inside(h, radius)
		var room: float = booth.clearance(f)
		if room > best_room:
			best = f
			best_room = room
	return best

## How far the spare tire reaches out from its middle (it lies flat).
func _spare_tire_radius(tire: Node3D) -> float:
	var mesh := tire.get_node_or_null("TireMesh") as MeshInstance3D
	if mesh == null:
		return 0.0
	var b: AABB = mesh.global_transform * mesh.get_aabb()
	return maxf(b.size.x, b.size.z) * 0.5

## Squashes one of the car's wheels and puts the tire-change click box on it.
func _make_flat_tire(garage: Node) -> void:
	var car := _car(garage)
	if car == null:
		return
	var wheel := car.find_child("Tire_%d" % (randi() % 4 + 1), true, false) as MeshInstance3D
	if wheel == null:
		return
	var flat := StaticBody3D.new()
	flat.name = "FlatTire"
	flat.set_script(load("res://Scripts/Minigames/FlatTire.gd"))
	flat.wheel = wheel
	flat.car = car
	car.add_child(flat)

## ---------------------------------------------------------------------
## Best run (saved between sessions)
## ---------------------------------------------------------------------

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_rounds = int(cfg.get_value("rogue", "best_rounds", 0))

func _save_best(rounds_survived: int) -> void:
	if rounds_survived <= best_rounds:
		return
	best_rounds = rounds_survived
	var cfg := ConfigFile.new()
	cfg.set_value("rogue", "best_rounds", best_rounds)
	cfg.save(SAVE_PATH)

## ---------------------------------------------------------------------
## Enemies: who hunts the player this round, and when they can kill
## ---------------------------------------------------------------------
## Kinds:
##   "stalker" - the killer as it always was: knows where the player is and
##               trails them (hanging back follow_distance); loses them only
##               when they hide unseen - then it wanders
##   "hunter"  - the killer wandering the garage, drawn to the car and the
##               parts; it only locks on once it SEES the player, and gives
##               up a while after losing sight of them
##   "angel"   - the weeping angel (moves only while unseen; never wanders)
## Each gets its own speed (times normal) - close to normal until the speed
## rounds, then sometimes a very fast angel.

## This round's enemies: [{kind, speed}] (rolled in _begin_round).
var enemy_plan: Array = []

## The rounds bring one new challenge at a time (and each round picks from
## the ones unlocked so far - the newest most often), before anything gets
## fast:
const ANGEL_ROUND := 3        # the weeping angel
const STARER_ROUND := 5       # an angel that sprints if you stare at it too long
const ILLUSION_ROUND := 6     # illusions: a waving decoy at the edge of your view mid-chase
const PACK_ROUND := 7         # a pack of 2-3 angels round the garage
const PAIR_ROUND := 8         # two enemies
const SPEED_ROUND := 9        # speed: faster variants, and they speed up each round
const TRIO_ROUND := 11        # sometimes three

## Illusions can happen this round (see Illusion.gd).
var illusions := false

## The last round's line-up (see plan_round).
var _last_lineup := ""

## This round's enemies - never the same line-up as last round (the same
## kinds, a staring angel or not, illusions or not): it re-rolls until it's
## different. In rounds 1-2 (stalker or hunter only) they alternate.
func plan_round(r: int) -> Array:
	var plan := plan_enemies(r)
	for i in 30:
		if lineup_of(plan) != _last_lineup:
			break
		plan = plan_enemies(r)
	_last_lineup = lineup_of(plan)
	return plan

## What kind of round a plan makes, e.g. "angel*+hunter +illusions".
func lineup_of(plan: Array) -> String:
	var kinds := []
	for e in plan:
		kinds.append(str(e.kind) + ("*" if e.get("starer", false) else ""))
	kinds.sort()
	return "+".join(kinds) + (" +illusions" if illusions else "")

func plan_enemies(r: int) -> Array:
	var themes := ["killer"]
	if r >= ANGEL_ROUND: themes.append("angel")
	if r >= STARER_ROUND: themes.append("starer")
	if r >= ILLUSION_ROUND: themes.append("illusion")
	if r >= PACK_ROUND: themes.append("pack")
	if r >= PAIR_ROUND: themes.append("pair")
	# the newest one most often, the rest evenly
	var theme: String = themes.back() if randf() < 0.45 else themes.pick_random()
	illusions = theme == "illusion" or (r >= ILLUSION_ROUND and randf() < 0.3)
	var fast := r >= SPEED_ROUND
	var out := []
	match theme:
		"killer", "illusion":
			out.append(_killer_entry(fast))
		"angel":
			out.append(_angel_entry(fast, false))
		"starer":
			out.append(_angel_entry(fast, true))
		"pack":
			for i in randi_range(2, 3):
				out.append(_angel_entry(fast, i == 0 and r >= STARER_ROUND and randf() < 0.5))
		"pair":
			out.append(_killer_entry(fast))
			out.append(_angel_entry(fast, randf() < 0.4) if randf() < 0.5 else _killer_entry(fast))
	if r >= TRIO_ROUND and out.size() < 3 and randf() < 0.35:
		out.append(_killer_entry(fast) if randf() < 0.6 else _angel_entry(fast, randf() < 0.5))
	return out

func _killer_entry(fast: bool) -> Dictionary:
	return {"kind": "hunter" if randf() < 0.5 else "stalker",
		"speed": randf_range(1.05, 1.35) if fast else randf_range(0.95, 1.1)}

func _angel_entry(fast: bool, starer: bool) -> Dictionary:
	return {"kind": "angel", "starer": starer,
		"speed": randf_range(0.9, 1.9) if fast else randf_range(0.85, 1.1)}

## Seconds the player has been standing still (see _physics_process).
var still_time := 0.0
var _step_timer := 0.0
var _last_player_pos := Vector3.INF

func _physics_process(delta: float) -> void:
	if not active:
		return
	var p = PlayerManager.player
	if not is_instance_valid(p) or not p.is_inside_tree() or PlayerManager.cutscene:
		still_time = 0.0
		_last_player_pos = Vector3.INF
		return
	var at: Vector3 = p.global_position
	if _last_player_pos != Vector3.INF and Vector2(at.x - _last_player_pos.x, at.z - _last_player_pos.z).length() < 0.02:
		still_time += delta
	else:
		still_time = 0.0
	_last_player_pos = at
	# footsteps enemies can hear: louder sprinting, near silent crouched
	_step_timer -= delta
	if still_time == 0.0 and _step_timer <= 0.0 and not PlayerManager.hiding and not PlayerManager.MinigameMode:
		_step_timer = 0.45
		var loud := EnemyNoise.STEP_WALK
		if "is_sprinting" in p and p.is_sprinting:
			loud = EnemyNoise.STEP_SPRINT
		elif "is_crouching" in p and p.is_crouching:
			loud = EnemyNoise.STEP_CROUCH
		EnemyNoise.make(get_tree(), at, loud, true)

## How long the player may stand still this round before enemies can get them.
func still_limit() -> float:
	return maxf(still_limit_start - (round_number - 1), still_limit_min)

func player_still_long() -> bool:
	return still_time >= still_limit()

func player_trapped() -> bool:
	var p = PlayerManager.player
	return is_instance_valid(p) and "trapped" in p and p.trapped

## Can an enemy kill the player right now? (Always, outside rogue mode.)
func kill_allowed() -> bool:
	if not active:
		return true
	if PlayerManager.MinigameMode and round_number <= minigame_safe_rounds:
		return false
	if round_number <= lenient_rounds:
		# a grab that only hurts is fine any time; one that would finish them
		# off still needs them trapped or standing still too long
		return player_trapped() or player_still_long() or grab_survivable()
	return true

## ---------------------------------------------------------------------
## Setting the enemies up in the garage
## ---------------------------------------------------------------------
## How far (garage units) and how wide (half-angle, degrees) a rogue killer sees.
const KILLER_SIGHT_RANGE := 70.0
const KILLER_SIGHT_FOV := 85.0
## How close (garage units) a rogue killer gets you from, when it may.
const KILLER_KILL_REACH := 5.0
const KILLER_SCRIPT := "Enemies/Killer.gd"
const ANGEL_SCRIPT := "Enemies/weeping_angel.gd"

## Places the wandering enemies keep drifting back to (the car, the parts,
## the toll booth) - filled in by setup_garage.
var points_of_interest: Array[Vector3] = []

func _setup_enemies(garage: Node) -> void:
	var killer: Node3D = null
	var angel: Node3D = null
	var others: Array[Node3D] = []
	for e in garage.get_tree().get_nodes_in_group("enemy"):
		var path: String = e.get_script().resource_path if e.get_script() else ""
		if path.ends_with(KILLER_SCRIPT) and killer == null:
			killer = e
		elif path.ends_with(ANGEL_SCRIPT) and angel == null:
			angel = e
		else:
			others.append(e)
	var plan: Array = enemy_plan if not enemy_plan.is_empty() else plan_enemies(round_number)
	var used: Array[Node3D] = []
	var killers_used := 0
	var angels_used := 0
	for entry in plan:
		var e: Node3D = null
		if entry.kind == "angel":
			if angel:
				e = angel if angels_used == 0 else _another_angel(angel)
				angels_used += 1
				e.walk_speed = e.WALK_SPEED * entry.speed
				e.stare_sprint = entry.get("starer", false)
		elif killer:
			if killers_used == 0:
				e = killer
			else:
				e = _another_killer(killer)
				PlayerManager.Enemy = killer   # the copy claimed it in its _ready
			killers_used += 1
			e.behavior = e.Behavior.HUNT if entry.kind == "hunter" else e.Behavior.STALK
			e.speed_mult = entry.speed
			# rogue killers see much further than the story's (20 units)
			e.sight_range = KILLER_SIGHT_RANGE
			e.sight_fov_degrees = KILLER_SIGHT_FOV
			# catches the player from KILLER_KILL_REACH away (its reach is scaled by its size)
			e.kill_reach = KILLER_KILL_REACH / maxf(e.global_basis.get_scale().y, 0.01)
			e.follow_distance = killer_follow_distance()
		if e:
			used.append(e)
	# everyone else sits this round out
	for e in [killer, angel] + others:
		if is_instance_valid(e) and not used.has(e):
			_bench(e)
	# illusions this round: a waving decoy at the edge of the view mid-chase
	if illusions and killers_used > 0:
		var ill := Node.new()
		ill.name = "Illusions"
		ill.set_script(load("res://Scripts/Enemies/Illusion.gd"))
		garage.add_child(ill)
	# start far from the player, and from each other
	var map: RID = garage.get_viewport().get_world_3d().navigation_map
	var p = PlayerManager.player
	var from: Vector3 = p.global_position if is_instance_valid(p) else Vector3.ZERO
	var taken: Array[Vector3] = []
	for e in used:
		var best := Vector3.INF
		var best_d := -1.0
		for i in 60:
			var q := NavigationServer3D.map_get_random_point(map, 1, true)
			if q == Vector3.ZERO or taken.any(func(t): return t.distance_to(q) < 25.0):
				continue
			var d := q.distance_to(from)
			if d >= enemy_spawn_distance and randf() < 0.5:
				best = q
				break
			if d > best_d:
				best_d = d
				best = q
		if best != Vector3.INF:
			e.global_position = HelperManager.floor_at(e.get_world_3d(), best, [e.get_rid()])
			e.velocity = Vector3.ZERO
			taken.append(best)

## A second (third) killer: a fresh one from the killer's own scene (copying
## a live one trips over the nodes it adds to itself), with the level's
## settings for it carried over (its size, speeds, eye height...).
func _another_killer(killer: Node3D) -> Node3D:
	var e: Node3D
	if killer.scene_file_path != "":
		e = (load(killer.scene_file_path) as PackedScene).instantiate()
		for prop in killer.get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_STORAGE:
				e.set(prop.name, killer.get(prop.name))
	else:
		e = killer.duplicate()
	killer.get_parent().add_child(e)
	e.global_transform = killer.global_transform
	return e

## Another weeping angel (a pack): a copy of the level's one.
func _another_angel(angel: Node3D) -> Node3D:
	var e: Node3D = angel.duplicate()
	angel.get_parent().add_child(e)
	return e

## Takes an enemy out of this round: hidden, still, out of the way and out
## of the "enemy" group (fear, events and the rest ignore it).
func _bench(e: Node3D) -> void:
	e.remove_from_group("enemy")
	e.visible = false
	e.process_mode = Node.PROCESS_MODE_DISABLED
	e.global_position = Vector3(0.0, -500.0, 0.0)
	for c in e.find_children("*", "CollisionShape3D", true, false):
		c.set_deferred("disabled", true)
	for a in e.find_children("*", "AudioStreamPlayer3D", true, false):
		a.stop()

## Somewhere for a wandering enemy to head next: sometimes a hunch - near
## where the player really is (hunch_chance), mostly near a point of
## interest (the car, a part, the toll booth), otherwise anywhere nearby.
func next_wander_point(e: Node3D) -> Vector3:
	var map: RID = e.get_world_3d().navigation_map
	var p = PlayerManager.player
	if is_instance_valid(p) and not PlayerManager.hiding and randf() < hunch_chance():
		var guess: Vector3 = p.global_position + Vector3(randf_range(0.0, hunch_radius), 0.0, 0.0).rotated(Vector3.UP, randf() * TAU)
		return NavigationServer3D.map_get_closest_point(map, guess)
	if not points_of_interest.is_empty() and randf() < 0.6:
		var poi: Vector3 = points_of_interest.pick_random()
		var near := poi + Vector3(randf_range(3.0, 8.0), 0.0, 0.0).rotated(Vector3.UP, randf() * TAU)
		return NavigationServer3D.map_get_closest_point(map, near)
	for i in 20:
		var q := NavigationServer3D.map_get_random_point(map, 1, true)
		if q != Vector3.ZERO and q.distance_to(e.global_position) < 45.0:
			return q
	return NavigationServer3D.map_get_random_point(map, 1, true)
