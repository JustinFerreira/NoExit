## No Exit
## Overtime Studios
## Office Life
## - Runs the rogue office's day (Office.gd adds it, after OfficeWing):
##   puts the run's staff (OfficeQuests.staff) in the office as walking
##   workers (OfficeWorker.gd), sits the vendor at his table in the break
##   room, and keeps everyone busy.
## - Errands (a free worker starts one now and then - ERRAND_CHANCE a
##   tick, picked by their role's weights in ROLE_ERRANDS):
##     deliver  - fetch papers from one desk worker, take them to another
##     copies   - stand at a copier a while, then take the copies to a desk
##     break    - coffee or the fridge in the kitchen, then sit in the
##                break room (couch or a table)
##     bathroom - a stall, then the sink
##   Every MEETING_EVERY seconds a meeting is called: the next MEETING_SIZE
##   workers to come free go and sit round the meeting room table, and
##   once they're all there it runs MEETING_TIME seconds.
## - Messes: errands sometimes leave one behind (MESS_CHANCE - coffee by
##   the kitchen, water at the sinks, papers after a meeting or dropped on
##   the way); the janitor is sent to clean the nearest (DialogNpc.go_clean).
## - Wanted items: tops up the workers' requests and puts found ones back
##   in the inventory (OfficeQuests.refresh / restore_carried).

extends Node

const OfficeQuests := preload("res://Scripts/Office/OfficeQuests.gd")
const OfficeWorker := preload("res://Scripts/Office/OfficeWorker.gd")
const OfficeMess := preload("res://Scripts/Office/OfficeMess.gd")

## Seconds between looks at who's free.
const TICK := 1.5
## Chance a free worker starts an errand each tick.
const ERRAND_CHANCE := 0.12
## Which errands each role goes on (weights).
const ROLE_ERRANDS := {
	"courier": {"deliver": 6, "copies": 1, "break": 2, "bathroom": 1},
	"copier": {"copies": 6, "deliver": 1, "break": 2, "bathroom": 1},
	"snacker": {"break": 6, "bathroom": 2, "deliver": 1, "copies": 1},
	"social": {"break": 3, "deliver": 2, "copies": 1, "bathroom": 2},
}
## A meeting every this many seconds (random in range), MEETING_SIZE people,
## lasting MEETING_TIME seconds once they're all sat down.
const MEETING_EVERY := Vector2(60.0, 100.0)
const MEETING_SIZE := Vector2i(3, 5)
const MEETING_TIME := Vector2(25.0, 40.0)
## Chance an errand leaves a mess, and the most messes about at once.
const MESS_CHANCE := 0.3
const MAX_MESSES := 6
## Workers' standing spots in the office: this far from a desk worker, the
## player's desk and the elevator.
const HOME_CLEARANCE := 3.0

var level: Node3D
var wing: Node
var workers: Array = []
var vendor: Node
## [{pos, face}] - standing beside each desk worker (papers go to/from them)
var desks: Array = []
var _meeting_in := 0.0
var _meeting_on := false
## A meeting being called: who's going (and their seats), how many it wants,
## how long it's been gathering, how many have sat down.
var _gather: Array = []
var _gather_seats: Array = []
var _gather_want := 0
var _gather_time := 0.0
var _arrived := [0]

func _ready() -> void:
	name = "OfficeLife"
	level = get_parent()
	_meeting_in = randf_range(MEETING_EVERY.x * 0.4, MEETING_EVERY.y * 0.6)
	_start.call_deferred()

func _start() -> void:
	wing = get_tree().get_first_node_in_group("office_wing")
	if wing == null:
		return
	var map := level.get_world_3d().navigation_map
	await HelperManager.nav_map_updated(get_tree(), map)
	for i in 3:
		await get_tree().physics_frame
	if not is_inside_tree():
		return
	OfficeQuests.refresh()
	OfficeQuests.restore_carried()
	_find_desks(map)
	for info in OfficeQuests.staff():
		var home := _pick_home(map)
		if home.is_empty():
			continue
		var w := OfficeWorker.make(level, home, info)
		workers.append(w)
	var vs: Dictionary = wing.claim_spot("vendor")
	if not vs.is_empty():
		vendor = OfficeWorker.make(level, vs, {"name": OfficeQuests.VENDOR_NAME, "role": "vendor", "tint": Color(0.86, 0.95, 0.86), "size": 1.02})
	# first errands spread out over the first few seconds
	for w in workers:
		_first_errand(w, randf_range(0.5, 12.0))
	_loop()

func _first_errand(w: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(w) and not w.busy:
		_errand(w)

func _loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(TICK).timeout
		if not is_inside_tree():
			return
		_meeting_in -= TICK
		if _meeting_in <= 0.0 and not _meeting_on and _gather_want == 0:
			_gather_want = randi_range(MEETING_SIZE.x, MEETING_SIZE.y)
			_gather_time = 0.0
		if _gather_want > 0:
			_gather_meeting()
		for w in workers:
			if is_instance_valid(w) and not w.busy and randf() < ERRAND_CHANCE:
				_errand(w)
		_send_janitor()

## ---------------------------------------------------------------------
## Places
## ---------------------------------------------------------------------

## Beside each seated desk worker (the level's Npc* nodes).
func _find_desks(map: RID) -> void:
	for n in level.get_children():
		if n is Node3D and String(n.name).begins_with("Npc"):
			var at := NavigationServer3D.map_get_closest_point(map, n.global_position)
			if at.distance_to(n.global_position) < 4.0:
				desks.append({"pos": at, "face": n.global_position - at, "npc": n})

## A free standing spot in the main office (on its nav mesh, not in the
## new rooms), away from the desk workers, the player's desk and the lift.
func _pick_home(map: RID) -> Dictionary:
	var avoid: Array[Vector3] = [Vector3(-1.15, 0, 16.5), Vector3(-41.6, 0, 8.1)]
	for d in desks:
		avoid.append(d.npc.global_position)
	for w in workers:
		avoid.append(w.home.pos)
	for i in 200:
		var p := NavigationServer3D.map_get_random_point(map, 1, true)
		if p.z < -22.5 or p.x < -37.0 or wing.room_at(p) != "":
			continue
		var ok := true
		for a in avoid:
			if Vector2(p.x - a.x, p.z - a.z).length() < HOME_CLEARANCE:
				ok = false
				break
		if ok:
			var yaw := randf() * TAU
			return {"pos": Vector3(p.x, 0.02, p.z), "face": Vector3(sin(yaw), 0, cos(yaw))}
	return {}

## ---------------------------------------------------------------------
## Errands
## ---------------------------------------------------------------------

func _errand(w: Node) -> void:
	var weights: Dictionary = ROLE_ERRANDS.get(w.role, ROLE_ERRANDS.social)
	var total := 0
	for k in weights:
		total += weights[k]
	var r := randi() % total
	var pick := ""
	for k in weights:
		r -= weights[k]
		if r < 0:
			pick = k
			break
	w.busy = true
	match pick:
		"deliver": await _deliver(w)
		"copies": await _copies(w)
		"break": await _break(w)
		"bathroom": await _bathroom(w)
	if not is_instance_valid(w):
		return
	w.hold("")
	await w.walk_to(w.home)
	if is_instance_valid(w):
		w.busy = false

func _deliver(w: Node) -> void:
	if desks.size() < 2:
		return
	var pair := desks.duplicate()
	pair.shuffle()
	if not await w.walk_to(pair[0]):
		return
	await w.wait(randf_range(1.5, 3.0), "idle")
	w.hold("folder")
	if randf() < MESS_CHANCE * 0.3:
		_mess("papers", w)
	if not await w.walk_to(pair[1]):
		return
	await w.wait(randf_range(1.5, 3.0), "idle")
	w.hold("")

func _copies(w: Node) -> void:
	var s: Dictionary = wing.claim_spot("copier")
	if s.is_empty():
		return
	var ok: bool = await w.walk_to(s)
	if ok:
		var light := _copier_light(s.pos)
		var t := randf_range(6.0, 12.0)
		_blink(light, t)
		await w.wait(t, "idle")
		w.hold("papers")
	wing.free_spot(s)
	if ok and randf() < 0.6 and not desks.is_empty():
		if await w.walk_to(desks.pick_random()):
			await w.wait(2.0, "idle")
			w.hold("")

func _break(w: Node) -> void:
	var s: Dictionary = wing.claim_spot(["coffee", "fridge", "counter"].pick_random())
	if s.is_empty():
		s = wing.claim_spot("counter")
	if not s.is_empty():
		var ok: bool = await w.walk_to(s)
		if ok:
			await w.wait(randf_range(3.0, 6.0), "idle")
			w.hold("mug")
			if randf() < MESS_CHANCE:
				_mess("coffee", w)
		wing.free_spot(s)
	var seat: Dictionary = wing.claim_spot(["couch", "break_seat"].pick_random())
	if seat.is_empty():
		seat = wing.claim_spot("break_seat")
	if seat.is_empty():
		return
	if await w.walk_to(seat):
		await w.wait(randf_range(15.0, 30.0))
		if randf() < MESS_CHANCE * 0.5:
			_mess("trash", w)
	wing.free_spot(seat)

func _bathroom(w: Node) -> void:
	var s: Dictionary = wing.claim_spot("stall")
	if s.is_empty():
		return
	if await w.walk_to(s):
		await w.wait(randf_range(8.0, 14.0), "idle")
	wing.free_spot(s)
	var sink: Dictionary = wing.claim_spot("sink")
	if sink.is_empty():
		return
	if await w.walk_to(sink):
		await w.wait(randf_range(2.5, 4.0), "idle")
		if randf() < MESS_CHANCE:
			_mess("water", w)
	wing.free_spot(sink)

## A meeting's been called: free workers join (and walk to a seat) until
## there are enough - or after 40 s, at least 2 - and once they're all sat
## down it starts. Under 2 people after 150 s: called off.
func _gather_meeting() -> void:
	_gather_time += TICK
	for w in workers:
		if _gather.size() >= _gather_want:
			break
		if is_instance_valid(w) and not w.busy:
			var seat: Dictionary = wing.claim_spot("meeting")
			if seat.is_empty():
				break
			w.busy = true
			_gather.append(w)
			_gather_seats.append(seat)
			_go_to_meeting(w, seat)
	var enough := _gather.size() >= _gather_want or (_gather_time > 40.0 and _gather.size() >= 2)
	if enough and _arrived[0] >= _gather.size():
		_gather_want = 0
		_run_meeting()
	elif _gather_time > 150.0 and _gather.size() < 2:
		_gather_want = 0
		_end_meeting()

func _go_to_meeting(w: Node, seat: Dictionary) -> void:
	var counter := _arrived
	await w.walk_to(seat)
	counter[0] += 1

func _run_meeting() -> void:
	_meeting_on = true
	await get_tree().create_timer(randf_range(MEETING_TIME.x, MEETING_TIME.y)).timeout
	if not is_inside_tree():
		return
	if randf() < MESS_CHANCE * 1.5 and not _gather.is_empty() and is_instance_valid(_gather[0]):
		_mess("papers", _gather[0])
	_end_meeting()

## Everyone back to their spots; the next one in MEETING_EVERY.
func _end_meeting() -> void:
	for s in _gather_seats:
		wing.free_spot(s)
	for w in _gather:
		if is_instance_valid(w):
			_leave_meeting(w)
	_gather = []
	_gather_seats = []
	_arrived = [0]
	_meeting_on = false
	_meeting_in = randf_range(MEETING_EVERY.x, MEETING_EVERY.y)

func _leave_meeting(w: Node) -> void:
	w.hold("")
	await w.walk_to(w.home)
	if is_instance_valid(w):
		w.busy = false

## ---------------------------------------------------------------------
## Copiers
## ---------------------------------------------------------------------

func _copier_light(at: Vector3) -> MeshInstance3D:
	var best: MeshInstance3D = null
	for l in wing.copier_lights:
		if best == null or l.global_position.distance_to(at) < best.global_position.distance_to(at):
			best = l
	return best

func _blink(light: MeshInstance3D, seconds: float) -> void:
	if light == null:
		return
	var t := 0.0
	while t < seconds and is_instance_valid(light):
		light.visible = not light.visible
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	if is_instance_valid(light):
		light.visible = true

## ---------------------------------------------------------------------
## Messes and the janitor
## ---------------------------------------------------------------------

func _mess(kind: String, near: Node) -> void:
	if get_tree().get_nodes_in_group("office_mess").size() >= MAX_MESSES or not is_instance_valid(near):
		return
	var m := Node3D.new()
	m.set_script(OfficeMess)
	m.kind = kind
	m.scale = Vector3.ONE * 1.8   # (real-size mess, level is ~1.8x real)
	level.add_child(m)
	var at: Vector3 = near.root.global_position
	var map := level.get_world_3d().navigation_map
	at = NavigationServer3D.map_get_closest_point(map, at + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)))
	m.global_position = Vector3(at.x, 0.02, at.z)

## Sends the janitor to the nearest mess nobody's cleaning yet (if he's
## free - just wandering about).
func _send_janitor() -> void:
	var j = PlayerManager.janitor
	if not is_instance_valid(j) or not j.has_method("go_clean") or not j.can_clean():
		return
	var best: Node3D = null
	var best_d := INF
	for m in get_tree().get_nodes_in_group("office_mess"):
		if m.claimed:
			continue
		var d: float = m.global_position.distance_to(j.root.global_position)
		if d < best_d:
			best_d = d
			best = m
	if best and j.go_clean(best):
		best.claimed = true
