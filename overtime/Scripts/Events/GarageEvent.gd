## No Exit
## Overtime Studios
## Garage Event (base for every random parking-garage event)
## - Every event in the garage is placed and armed all the time. When the
##   player walks into one's trigger area it ASKS the EventDirector whether
##   it may happen right now - the director keeps them sparse and spread out
##   (a random gap after each event, a bit more likely the longer it's been
##   quiet, never right next to the last one), and enforces the tiers:
##     COMMON     - can happen again (after `kind_cooldown`, anywhere)
##     RARE       - at most once per run
##     LEGENDARY  - once per playthrough, ever (remembered between sessions)
## - To make an event: a scene whose root has a script that
##     extends "res://Scripts/Events/GarageEvent.gd"
##   with an Area3D child whose area_entered signal is connected to
##   _on_area_3d_area_entered (already the case for every existing event).
##   Set tier / kind / weight in _init(), put the scare in _fire(), and
##   optionally a check in can_fire() (e.g. "is there still a working light").

extends Node3D

const EventDirector = preload("res://Scripts/Events/EventDirector.gd")

enum Tier { COMMON, RARE, LEGENDARY }

## How rare it is (see above).
@export var tier: Tier = Tier.COMMON
## Events of the same kind share their "once" / cooldown (all the car alarms
## are one kind). Empty = the script's file name.
@export var kind: String = ""
## How likely, relative to others of its tier, it is to go off when allowed.
@export_range(0.0, 3.0) var weight: float = 1.0
## COMMON only: seconds before this kind can happen again anywhere.
@export var kind_cooldown: float = 150.0
## Can go off in Loop 0 (the scripted first night). Most can't.
@export var allow_in_loop0: bool = false
## This trigger can go off again later in the same visit (once allowed).
@export var repeatable: bool = false
## The killer has to be at least this far from the player (metres) for it to
## happen - for scares that only work when you think you're alone (the
## payphone). If he's off in the fog where the player can't really see him
## (FOG_HIDE_DISTANCE) he slips away to make room; closer, it waits.
## 0 = doesn't matter (a light breaking is fine with him close).
@export var min_killer_distance: float = 0.0

## Already went off this visit.
var fired: bool = false

func _enter_tree() -> void:
	EventDirector.level_started(self)

## The player walked into the trigger: ask the director, then go off.
func _on_area_3d_area_entered(area: Area3D) -> void:
	if fired and not repeatable:
		return
	if not HelperManager.is_player_area(area):
		return
	if PlayerManager.Loop0 and not allow_in_loop0:
		return
	if not killer_far_enough():
		return
	if not can_fire():
		return
	if not EventDirector.request(self):
		return
	fired = true
	_send_killers_away()
	_fire()

## Whether it makes sense right now (override: e.g. a light that's still on).
func can_fire() -> bool:
	return true

## The event itself (override).
func _fire() -> void:
	pass

func get_kind() -> String:
	return kind if kind != "" else get_script().resource_path.get_file().get_basename()

## Killers closer than this can't just vanish - the player could see it
## happen. Further out they're shapes in the fog, and can slip away.
const FOG_HIDE_DISTANCE := 22.0
## ...unless they're right there on screen with a clear view: then they have
## to be this far before they can go.
const FOG_HIDE_ON_SCREEN := 32.0

## The killers (every enemy in the level that's switched on) closer to the
## player than min_killer_distance.
func _killers_too_close() -> Array:
	var out := []
	if min_killer_distance <= 0.0 or PlayerManager.no_enemy:
		return out
	var p = PlayerManager.player
	if not is_instance_valid(p):
		return out
	for k in get_tree().get_nodes_in_group("enemy"):
		if k is Node3D and k.is_inside_tree() and k.is_visible_in_tree() \
				and k.global_position.distance_to(p.global_position) < min_killer_distance:
			out.append(k)
	return out

## Whether it can happen with the killers where they are: none too close, or
## the close ones are far enough off in the fog to slip away unseen (then
## _send_killers_away moves them when it goes off).
func killer_far_enough() -> bool:
	var close := _killers_too_close()
	if close.is_empty():
		return true
	if PlayerManager.dying or PlayerManager.hiding:
		return false
	var p = PlayerManager.player
	for k in close:
		var d: float = k.global_position.distance_to(p.global_position)
		if d < FOG_HIDE_DISTANCE:
			return false
		if d < FOG_HIDE_ON_SCREEN and k.has_method("on_player_screen") and k.on_player_screen(k.body_points()):
			return false
	return true

## The close killers fade off into the fog: each is moved, unseen, to a spot
## on the nav mesh well past min_killer_distance (and out of view). They walk
## back from there as usual - the event gets its moment alone.
func _send_killers_away() -> void:
	var p = PlayerManager.player
	for k in _killers_too_close():
		var spot := _far_spot(k, p.global_position)
		if spot == Vector3.INF:
			continue
		k.global_position = HelperManager.floor_at(k.get_world_3d(), spot, [k.get_rid()])
		if "velocity" in k:
			k.velocity = Vector3.ZERO

## A random nav-mesh point min_killer_distance + 8..35 m from the player that
## the player can't see (falls back to the furthest one found).
func _far_spot(k: Node3D, from: Vector3) -> Vector3:
	var map_rid: RID = k.get_world_3d().navigation_map
	var space := k.get_world_3d().direct_space_state
	var cam = PlayerManager.player.CAMERA if "CAMERA" in PlayerManager.player else null
	var best := Vector3.INF
	var best_d := 0.0
	for i in 40:
		var at: Vector3 = NavigationServer3D.map_get_random_point(map_rid, 1, true)
		var d := at.distance_to(from)
		if d < min_killer_distance + 8.0:
			if d > best_d:
				best_d = d
				best = at
			continue
		if d > min_killer_distance + 35.0:
			continue
		if cam:
			var head := at + Vector3.UP * 1.6
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(cam.global_position, head, 0xFFFFFFFF, [PlayerManager.player.get_rid()]))
			if hit.is_empty() and not cam.is_position_behind(head):
				continue   # in plain view
		return at
	return best if best_d >= min_killer_distance else Vector3.INF
