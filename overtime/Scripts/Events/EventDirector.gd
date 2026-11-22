## No Exit
## Overtime Studios
## Event Director
## - Decides whether a garage event (GarageEvent) may go off when the player
##   walks into it. Every event stays armed; this keeps them sparse but steady:
##     - nothing for a while after arriving (FIRST_DELAY)
##     - after each event a random quiet gap (GAP / LEGENDARY_GAP)
##     - once the gap is over, each trigger walked into has a chance to fire -
##       a chance that grows the longer it's been quiet (DROUGHT_BOOST), so
##       quiet stretches don't drag on
##     - never close to where the last event happened (MIN_SPACING)
##     - COMMON kinds wait their kind_cooldown, RARE ones happen once per run,
##       LEGENDARY ones once per playthrough (saved in SAVE_PATH)
## - Also hangs events on things already in the garage when a level loads -
##   lights, payphones, elevators, the gate arms, parked cars (_arm_world).
## - Static only (no autoload needed): events preload it.

## GarageEvent.Tier values (not preloaded - the two scripts refer to each other)
const COMMON := 0
const RARE := 1
const LEGENDARY := 2
const LIGHT_BREAK_PATH := "res://Scripts/Events/LightBreakEvent.gd"
const AMBIENT_PATH := "res://Scripts/Events/AmbientSoundEvent.gd"
const PAYPHONE_PATH := "res://Scripts/Events/PayphoneRingEvent.gd"
const ELEVATOR_PATH := "res://Scripts/Events/ElevatorGhostEvent.gd"
const GATE_ARM_PATH := "res://Scripts/Events/GateArmEvent.gd"
const PARKED_CAR_PATH := "res://Scripts/Events/ParkedCarEvent.gd"
const PIPE_FALL_PATH := "res://Scripts/Events/PipeFallEvent.gd"
const KILLER_BEHIND_PATH := "res://Scripts/Events/KillerBehindEvent.gd"
const CREEPY_NOISE_PATH := "res://Scripts/Events/creepy_noise_emitter.gd"
## Pipes that can fall: at most this many, at least this far apart (m).
const PIPE_FALL_MAX := 18
const PIPE_FALL_SPACING := 16.0

const SAVE_PATH := "user://garage_events.cfg"
## Seconds after arriving before anything can happen.
const FIRST_DELAY := Vector2(25.0, 50.0)
## Quiet seconds after an event (random in this range).
const GAP := Vector2(40.0, 110.0)
## ... and after a legendary one.
const LEGENDARY_GAP := Vector2(90.0, 160.0)
## Chance a trigger walked into goes off, once the gap is over, by tier.
const CHANCE := [0.45, 0.3, 0.12]   # COMMON, RARE, LEGENDARY
## Extra chance per minute of quiet past the gap (1.0 = doubles each minute).
const DROUGHT_BOOST := 1.0
## Metres an event must be from the last one (while that one is recent).
const MIN_SPACING := 25.0
const SPACING_MEMORY := 180.0
## Radius of each ceiling light's break trigger (metres).
const LIGHT_TRIGGER_RADIUS := 3.0

static var _level_id: int = 0
static var _next_allowed_ms: int = 0
static var _last_pos: Vector3 = Vector3.INF
static var _last_ms: int = 0
## kind -> time (ms) it may happen again (COMMON)
static var _kind_ready_ms: Dictionary = {}
## RARE kinds used this run
static var _used_this_run: Dictionary = {}
## LEGENDARY kinds ever seen (loaded from / saved to SAVE_PATH)
static var _seen_ever: Dictionary = {}
static var _loaded: bool = false
## For the dev menu: events that went off (kind -> count) this run / since launch,
## and the last one.
static var fired_this_run: Dictionary = {}
static var fired_total: Dictionary = {}
static var last_kind: String = ""
static var last_ms: int = 0

## Called by every event as it enters the tree: the first one in a new level
## starts the clock and arms the lights.
static func level_started(ev: Node) -> void:
	var tree := ev.get_tree()
	if tree == null:
		return
	var level: Node = tree.current_scene if tree.current_scene else ev.owner
	if level == null or level.get_instance_id() == _level_id:
		return
	_level_id = level.get_instance_id()
	_load()
	_next_allowed_ms = Time.get_ticks_msec() + int(randf_range(FIRST_DELAY.x, FIRST_DELAY.y) * 1000.0)
	_last_pos = Vector3.INF
	tree.process_frame.connect(func(): _arm_world(level), CONNECT_ONE_SHOT)

## A new run (rogue mode): rare events can happen again.
static func new_run() -> void:
	_used_this_run.clear()
	_kind_ready_ms.clear()
	fired_this_run.clear()

## May this event go off right now? (Records it if so.)
static func request(ev) -> bool:
	_load()
	var now := Time.get_ticks_msec()
	var kind: String = ev.get_kind()
	match ev.tier:
		LEGENDARY:
			if _seen_ever.has(kind):
				return false
		RARE:
			if _used_this_run.has(kind):
				return false
		_:
			if now < int(_kind_ready_ms.get(kind, 0)):
				return false
	if now < _next_allowed_ms:
		return false
	if _last_pos != Vector3.INF and now - _last_ms < int(SPACING_MEMORY * 1000.0) \
			and ev.global_position.distance_to(_last_pos) < MIN_SPACING:
		return false
	var quiet_min := float(now - _next_allowed_ms) / 60000.0
	var chance: float = CHANCE[ev.tier] * ev.weight * (1.0 + quiet_min * DROUGHT_BOOST)
	if randf() >= minf(chance, 1.0):
		return false
	# it happens
	_last_pos = ev.global_position
	_last_ms = now
	_count(kind)
	var gap: Vector2 = LEGENDARY_GAP if ev.tier == LEGENDARY else GAP
	_next_allowed_ms = now + int(randf_range(gap.x, gap.y) * 1000.0)
	match ev.tier:
		LEGENDARY:
			_seen_ever[kind] = true
			_save()
		RARE:
			_used_this_run[kind] = true
		_:
			_kind_ready_ms[kind] = now + int(ev.kind_cooldown * 1000.0)
	return true

## Hangs events on things already in the garage (so every one of them can
## happen, and the director decides when):
##   every ceiling light  - its own break, plus far-off footsteps / a door slam
##                          (every third: an enemy turns up behind the player)
##                          (and a creepy noise somewhere near - anywhere)
##   every payphone       - it rings
##   every elevator       - it opens on its own
##   the gate arms        - one lifts by itself
##   every parked car     - its locks chirp / it cranks / its headlights come on
##   some ceiling pipes   - one gives way and sprays steam
static func _arm_world(level: Node) -> void:
	if not is_instance_valid(level) or not level.is_inside_tree():
		return
	var space: PhysicsDirectSpaceState3D = level.get_viewport().get_world_3d().direct_space_state
	var i := 0
	for light in level.get_tree().get_nodes_in_group("Lights"):
		if not (light is Node3D) or light.has_node("BreakTrigger"):
			continue
		var top: Vector3 = light.global_position
		var floor_y := _floor_under(space, top + Vector3.DOWN * 0.3, top.y - 4.0)
		var mid := Vector3(top.x, (top.y + floor_y) * 0.5, top.z)
		var h := maxf(top.y - floor_y, 1.0)
		var brk := _add_trigger(light, "BreakTrigger", LIGHT_BREAK_PATH, mid, LIGHT_TRIGGER_RADIUS, h)
		brk.light = light
		var amb := _add_trigger(light, "AmbientTrigger", AMBIENT_PATH, mid, LIGHT_TRIGGER_RADIUS + 1.0, h)
		amb.setup(i % 2)   # FOOTSTEPS / DOOR_SLAM, alternating light to light
		_add_trigger(light, "CreepyTrigger", CREEPY_NOISE_PATH, mid, LIGHT_TRIGGER_RADIUS + 1.5, h)
		if i % 3 == 0:   # every third light: an enemy turns up behind the player
			_add_trigger(light, "BehindTrigger", KILLER_BEHIND_PATH, mid, LIGHT_TRIGGER_RADIUS + 2.0, h)
		i += 1
	for holder in level.find_children("Payphones", "", true, false):
		for phone in holder.get_children():
			if phone is Node3D:
				var at: Vector3 = phone.global_position
				_add_trigger(phone, "RingTrigger", PAYPHONE_PATH, Vector3(at.x, _floor_under(space, at + Vector3.UP, at.y) + 1.5, at.z), 12.0, 3.0)
	for el in level.find_children("*", "", true, false):
		if el.get_script() and el.get_script().resource_path.ends_with("ParkingGarageElevator.gd"):
			var door: Node3D = el.get_node_or_null("ElevatorCollisions/DoorCollision")
			if door == null:
				continue
			# out in front of the doors
			var out: Vector3 = door.global_position - el.global_position
			out.y = 0.0
			var front: Vector3 = Vector3(door.global_position.x, el.global_position.y + 1.5, door.global_position.z) + out.normalized() * 6.0
			_add_trigger(el, "GhostTrigger", ELEVATOR_PATH, front, 7.0, 3.0)
	for arm in level.find_children("BoomArm*", "", true, false):
		if arm is Node3D:
			_add_trigger(arm, "LiftTrigger", GATE_ARM_PATH, arm.global_position + Vector3.UP * 1.0, 10.0, 3.0)
	for cars in level.find_children("Cars", "", true, false):
		for deck in cars.get_children():
			for car in deck.get_children():
				if not (car is Node3D):
					continue
				var roll := randf()
				var m: int = 2 if roll < 0.10 else (1 if roll < 0.35 else 0)   # HEADLIGHTS / CRANK / CHIRP
				var c := _add_trigger(car, "CarTrigger", PARKED_CAR_PATH, car.global_position + Vector3.UP * 1.0, 6.0, 3.0)
				c.setup(m)
	_arm_pipes(level, space)

## Long ceiling pipes (not the ones carrying lights), spread out, each with a
## PipeFallEvent: the trigger is a wide circle round it, so it comes down a
## little ahead of the player.
static func _arm_pipes(level: Node, space: PhysicsDirectSpaceState3D) -> void:
	var picks: Array[Vector3] = []
	var pipes := level.find_children("PipeBigLong*", "Node3D", true, false)
	pipes.shuffle()
	for pipe in pipes:
		if picks.size() >= PIPE_FALL_MAX:
			break
		if pipe.has_node("../PipeFallTrigger") or String(pipe.get_parent().name).begins_with("LightPipes") \
				or String(pipe.get_parent().get_parent().name).begins_with("LightPipes"):
			continue
		var at: Vector3 = pipe.global_position
		if picks.any(func(q): return q.distance_to(at) < PIPE_FALL_SPACING):
			continue
		var floor_y := _floor_under(space, at + Vector3.DOWN * 0.4, at.y - 4.0)
		if at.y - floor_y < 2.0:
			continue   # not overhead
		picks.append(at)
		var ev := _add_trigger(pipe.get_parent(), "PipeFallTrigger", PIPE_FALL_PATH, Vector3(at.x, floor_y + 1.5, at.z), 9.0, 3.0)
		ev.pipe = pipe

## A trigger (a vertical cylinder) running an event script, under `host`.
static func _add_trigger(host: Node, trigger_name: String, script_path: String, at: Vector3, radius: float, height: float) -> Node3D:
	var ev := Node3D.new()
	ev.set_script(load(script_path))
	ev.name = trigger_name
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 32
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	area.add_child(shape)
	ev.add_child(area)
	area.area_entered.connect(ev._on_area_3d_area_entered)
	host.add_child(ev)
	ev.global_position = at
	ev.global_basis = Basis()
	return ev

static func _floor_under(space: PhysicsDirectSpaceState3D, from: Vector3, fallback: float) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.0))
	return hit.position.y if hit else fallback

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for k in cfg.get_value("seen", "legendary", []):
			_seen_ever[k] = true

static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("seen", "legendary", _seen_ever.keys())
	cfg.save(SAVE_PATH)

static func _count(kind: String) -> void:
	fired_this_run[kind] = int(fired_this_run.get(kind, 0)) + 1
	fired_total[kind] = int(fired_total.get(kind, 0)) + 1
	last_kind = kind
	last_ms = Time.get_ticks_msec()

## Dev menu: sets an event off now, skipping every rule (and not counting a
## legendary as seen, so it can still happen for real).
static func debug_fire(ev) -> void:
	if not is_instance_valid(ev):
		return
	ev.fired = true
	_count(ev.get_kind())
	if ev.has_method("_send_killers_away"):
		ev._send_killers_away()
	ev._fire()

## Dev menu: seconds until an event may happen (negative = it may now, and
## has been quiet that long).
static func seconds_to_next() -> float:
	return float(_next_allowed_ms - Time.get_ticks_msec()) / 1000.0

## Dev menu: let the next trigger walked into go off straight away.
static func ready_now() -> void:
	_next_allowed_ms = Time.get_ticks_msec()
	_last_pos = Vector3.INF

## Legendary kinds seen in this playthrough.
static func seen_legendaries() -> Array:
	_load()
	return _seen_ever.keys()

## For testing: forget every legendary event seen.
static func reset_seen() -> void:
	_seen_ever.clear()
	_save()
