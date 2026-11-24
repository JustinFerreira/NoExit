## No Exit
## Overtime Studios
## Sound Reach
## - How sound carries between the parking garage's floors. On the same floor
##   a sound carries normally. To another floor only what gets through the
##   openings does - the ramps, the gaps around the barriers between floors:
##   a few rays from the sound toward the listener, spread a little (so thin
##   bars let some through), and the share that make it decide how much is
##   heard - only near the opening (it fades out a few metres past it). None
##   make it = not heard at all through the concrete.
## - floor_offset_db() is added to a sound's own volume (see CarKeyNoise,
##   Killer3DAudio). Static helper, nothing to place.

## Floors within this height of each other are the same floor (m) - the
## floor under the sound against the floor the listener stands on.
const SAME_FLOOR := 1.2
## The garage is split-level: decks ~2.6 m apart, side by side with barriers
## and ramps between them. On another deck it's heard near the opening the
## sound comes through, fading out OPENING_FADE metres past it.
const OPENING_NEAR := 8.0
const OPENING_FADE := 22.0
## On a ramp up / down to the sound's deck it's heard (ramps are open), at
## least this loud even if the rays clip the ramp's edges.
const RAMP_DB := -9.0
## A slope narrower than this (wall to wall, metres) isn't a garage ramp -
## it's the stairs (~7 m; the ramps are 15-24 m).
const RAMP_MIN_WIDTH := 10.0
## dB added when only a sliver / all of the rays get through.
const THROUGH_FEW_DB := -16.0
const THROUGH_ALL_DB := -5.0
## dB when nothing gets through (effectively silent).
const BLOCKED_DB := -60.0
## Same floor, but every ray blocked by cars / pillars (out on the deck).
const SAME_FLOOR_MUFFLED_DB := -6.0
## "Walled in": at most this many of 8 directions round the listener are
## open for WALL_CHECK metres (a stairwell, a corridor).
const WALLED_IN_OPEN := 5
const WALL_CHECK := 6.0

## dB to add to a sound at `from` heard at `to` (the listener's ears).
## `feet_y`: the floor the listener stands on (default: the player's).
static func floor_offset_db(world: World3D, from: Vector3, to: Vector3, exclude: Array[RID] = [], feet_y: float = NAN) -> float:
	var space := world.direct_space_state
	if is_nan(feet_y):
		var p = PlayerManager.player
		feet_y = p.global_position.y if is_instance_valid(p) else to.y - 3.0
	var src_floor := floor_under(space, from, exclude)
	if absf(src_floor - feet_y) < SAME_FLOOR:
		# the same height - but maybe not the same floor: a stairwell beside
		# the deck is walled off from it. Silent only when no ray gets through
		# (from the sound, or from above it over the parked cars) AND the
		# listener is walled in close round them; out on the deck, cars and
		# pillars in the way just muffle it a little.
		if _clear_rays(space, from, to, exclude, [0.8, 2.6]) > 0:
			return 0.0
		return BLOCKED_DB if _walled_in(space, to, exclude) else SAME_FLOOR_MUFFLED_DB
	var on_ramp := _on_ramp(space, to, feet_y, exclude) and absf(src_floor - feet_y) < 3.4
	var start := from + Vector3.UP * 0.8
	var total := RAYS_PER_START
	var clear := _clear_rays(space, from, to, exclude, [0.8])
	if clear == 0:
		return RAMP_DB if on_ramp else BLOCKED_DB
	var through := lerpf(THROUGH_FEW_DB, THROUGH_ALL_DB, float(clear - 1) / float(maxi(total - 1, 1)))
	# how far past the opening the listener is: where the sound's line crosses
	# the upper deck's edge height, to the listener (sideways)
	var edge_y := maxf(src_floor, feet_y) + 0.5
	var t := clampf((edge_y - start.y) / (to.y - start.y), 0.0, 1.0) if absf(to.y - start.y) > 0.01 else 1.0
	var crossing := start.lerp(to, t)
	var depth := Vector2(to.x - crossing.x, to.z - crossing.z).length()
	if on_ramp:
		return maxf(through, RAMP_DB)
	if depth >= OPENING_FADE:
		return BLOCKED_DB
	var fade := clampf((depth - OPENING_NEAR) / (OPENING_FADE - OPENING_NEAR), 0.0, 1.0)
	return lerpf(through, BLOCKED_DB, fade * fade)

## Spread from x to y across the listener (so a row of bars lets some through).
const RAY_SPREAD_X := [-1.2, -0.6, 0.0, 0.6, 1.2]
const RAY_SPREAD_Y := [-0.6, 0.0, 0.5]
const RAYS_PER_START := 15

## How many rays get from the sound (raised by each of `heights`) to the
## listener without hitting anything.
static func _clear_rays(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID], heights: Array) -> int:
	var side := (to - from).cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.001 else Vector3.RIGHT
	var clear := 0
	for h in heights:
		var start: Vector3 = from + Vector3.UP * h
		for sx in RAY_SPREAD_X:
			for sy in RAY_SPREAD_Y:
				var end: Vector3 = to + side * sx + Vector3.UP * sy
				var q := PhysicsRayQueryParameters3D.create(start, end)
				q.exclude = exclude
				q.collide_with_areas = false
				if space.intersect_ray(q).is_empty():
					clear += 1
	return clear

## Is the listener boxed in by walls close round them (a stairwell)?
static func _walled_in(space: PhysicsDirectSpaceState3D, ears: Vector3, exclude: Array[RID]) -> bool:
	var open := 0
	for k in 8:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 8.0)
		var q := PhysicsRayQueryParameters3D.create(ears, ears + dir * WALL_CHECK)
		q.exclude = exclude
		q.collide_with_areas = false
		if space.intersect_ray(q).is_empty():
			open += 1
	return open <= WALLED_IN_OPEN

## Is the listener standing on a garage ramp (a wide sloped floor)?
static func _on_ramp(space: PhysicsDirectSpaceState3D, ears: Vector3, feet_y: float, exclude: Array[RID]) -> bool:
	var from := Vector3(ears.x, feet_y + 0.5, ears.z)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.5)
	q.exclude = exclude
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if not hit or (hit.normal as Vector3).y >= 0.985:
		return false
	# a garage ramp is wide open; a stairwell's slope (the stairs by the
	# elevators, ~7 m across) is walled in and doesn't count
	var n: Vector3 = hit.normal
	var across := Vector3(n.x, 0.0, n.z).normalized().cross(Vector3.UP).normalized()
	if across == Vector3.ZERO:
		return true
	var at: Vector3 = hit.position + Vector3.UP * 1.0
	var width := 0.0
	for s in [-1.0, 1.0]:
		var wq := PhysicsRayQueryParameters3D.create(at, at + across * s * RAMP_MIN_WIDTH)
		wq.exclude = exclude
		wq.collide_with_areas = false
		var w := space.intersect_ray(wq)
		width += at.distance_to(w.position) if w else RAMP_MIN_WIDTH
	return width >= RAMP_MIN_WIDTH

## Height of the floor under a point (the point's own height if none close).
static func floor_under(space: PhysicsDirectSpaceState3D, p: Vector3, exclude: Array[RID] = []) -> float:
	var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 5.0)
	q.exclude = exclude
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	return hit.position.y if hit else p.y

## Where the player hears from (their camera), or INF if there's no player.
static func listener() -> Vector3:
	var p = PlayerManager.player
	if is_instance_valid(p) and p.is_inside_tree() and p.CAMERA:
		return p.CAMERA.global_position
	return Vector3.INF

## ---------------------------------------------------------------------
## How a sound reaches the listener (used by the key fob): {distance, db}.
##   A direct line (any of the rays from the sound - from it and from above
##   it - gets through: open floor, through the bars, a gap) - the straight
##   distance, a little quieter the more of the rays something's in the way
##   of (THROUGH_BARS_DB at worst).
##   Otherwise the sound goes round, along the walking route (up a ramp,
##   round a wall): that route's length, AROUND_DB quieter - and WALLED_IN_DB
##   more if the listener is walled in (the stairs).
##   No route either: blocked (db = BLOCKED_DB).
## ---------------------------------------------------------------------
const THROUGH_BARS_DB := -8.0
const AROUND_DB := -10.0
const WALLED_IN_DB := -12.0
const ROUTE_MAX := 140.0

static func reach(world: World3D, from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var space := world.direct_space_state
	var total := RAYS_PER_START * 2
	var clear := _clear_rays(space, from, to, exclude, [0.8, 2.6])
	if clear > 0:
		var blocked_share := 1.0 - float(clear) / float(total)
		return {"distance": from.distance_to(to), "db": THROUGH_BARS_DB * blocked_share}
	var map := world.navigation_map
	var a := NavigationServer3D.map_get_closest_point(map, from)
	var b := NavigationServer3D.map_get_closest_point(map, to)
	var path := NavigationServer3D.map_get_path(map, a, b, true)
	if path.size() < 2 or path[path.size() - 1].distance_to(b) > 3.0:
		return {"distance": INF, "db": BLOCKED_DB}
	var length := from.distance_to(a) + to.distance_to(b)
	for i in range(path.size() - 1):
		length += path[i].distance_to(path[i + 1])
	if length > ROUTE_MAX:
		return {"distance": INF, "db": BLOCKED_DB}
	var db := AROUND_DB
	if _walled_in(space, to, exclude):
		db += WALLED_IN_DB
	return {"distance": length, "db": db}
