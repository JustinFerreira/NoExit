## No Exit
## Overtime Studios
## NPC Avoid
## - Keeps walking NPCs (the office workers, the janitor) out of each other
##   and out of the janitor's bucket. Static helpers - the walkers call
##   them every step:
##     dir = NpcAvoid.steer(me, pos, dir)  - bends the way they're heading
##         round anyone close ahead (everybody passes on their right, so
##         two coming face to face both step aside the same way)
##     pos = NpcAvoid.separate(me, pos)    - pushes them back out if they
##         still end up overlapping someone
## - Who counts: nodes in group "npc_body" (each NPC's root - RADIUS round
##   it) and "npc_obstacle" (things like the bucket - radius from their
##   "avoid_radius" meta, else 0.9). An obstacle with an "avoid_owner" meta
##   is left out for that owner (the janitor handles his own bucket).
## - Level units (the office is about 1.8x real size).

## Half an NPC's width.
const RADIUS := 0.6
## Start steering round someone this many radii (both added) away.
const LOOK := 2.2
## How hard to steer (relative to the walking direction).
const STEER := 1.6

## The obstacles near `pos`: [[position, radius], ...] (not `me`).
static func _around(me: Node3D, pos: Vector3, reach: float) -> Array:
	var out: Array = []
	if not me.is_inside_tree():
		return out
	var tree := me.get_tree()
	for n in tree.get_nodes_in_group("npc_body"):
		if n == me or not (n is Node3D) or not n.is_inside_tree():
			continue
		if _flat(n.global_position - pos).length() < reach:
			out.append([n.global_position, RADIUS])
	for n in tree.get_nodes_in_group("npc_obstacle"):
		if not (n is Node3D) or not n.is_inside_tree() or n.get_meta("avoid_owner", null) == me:
			continue
		if _flat(n.global_position - pos).length() < reach:
			out.append([n.global_position, float(n.get_meta("avoid_radius", 0.9))])
	return out

static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

## The direction to walk instead of `dir` (flat, normalised) to get round
## whoever's close ahead.
static func steer(me: Node3D, pos: Vector3, dir: Vector3) -> Vector3:
	dir = _flat(dir)
	if dir.length() < 0.0001:
		return dir
	dir = dir.normalized()
	var push := Vector3.ZERO
	for o in _around(me, pos, (RADIUS + 1.0) * LOOK + 1.0):
		var away := _flat(pos - o[0])
		var d := away.length()
		var reach: float = (RADIUS + o[1]) * LOOK
		if d >= reach or d < 0.0001:
			continue
		var close := 1.0 - d / reach
		away /= d
		push += away * close
		# in the way ahead: go round it on the right
		if dir.dot(-away) > 0.2:
			push += dir.cross(Vector3.UP).normalized() * close * 1.2
	if push == Vector3.ZERO:
		return dir
	var out := dir + push * STEER
	# never turn right round (they'd walk back the way they came)
	if out.dot(dir) < -0.2:
		out = (out - dir * out.dot(dir)).normalized() * 0.9 + dir * -0.2
	return out.normalized() if out.length() > 0.0001 else dir

## `pos` pushed back out of anyone it overlaps.
static func separate(me: Node3D, pos: Vector3) -> Vector3:
	for o in _around(me, pos, RADIUS * 2.0 + 2.0):
		var away := _flat(pos - o[0])
		var d := away.length()
		var need: float = RADIUS + o[1]
		if d < need:
			if d < 0.0001:
				away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
				d = maxf(away.length(), 0.0001)
			pos += away / d * (need - d)
	return pos
