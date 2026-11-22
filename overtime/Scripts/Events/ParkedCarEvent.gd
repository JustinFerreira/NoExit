## No Exit
## Overtime Studios
## Parked Car Event (see GarageEvent) - one of the garage's parked cars, as
## the player walks by:
##   CHIRP      (COMMON)    its locks chirp, like someone just locked it
##   CRANK      (RARE)      its engine tries to start, and fails - it's empty
##   HEADLIGHTS (LEGENDARY) its headlights and tail lights snap on,
##                          the engine idles, then they go dark again
## - Put on every parked car at load (EventDirector), mode picked at random.

extends "res://Scripts/Events/GarageEvent.gd"

const EventSounds = preload("res://Scripts/Events/EventSounds.gd")
const CHIRP := preload("res://Assets/Audio/SFX/old-maruti-car-unlock-sound-keyless-entry-beep-327691.mp3")
const CRANK := preload("res://Assets/Audio/SFX/car-engine-fail.mp3")
const IDLE := preload("res://Assets/Audio/SFX/car-engine-hum.mp3")

enum Mode { CHIRP, CRANK, HEADLIGHTS }
var mode: Mode = Mode.CHIRP

## Picks the mode (tier, kind) - call before it's used.
func setup(m: Mode) -> void:
	mode = m
	match m:
		Mode.CHIRP:
			tier = Tier.COMMON
			kind = "car_chirp"
			kind_cooldown = 160.0
			weight = 0.5
		Mode.CRANK:
			tier = Tier.RARE
			kind = "car_crank"
			min_killer_distance = 20.0
		Mode.HEADLIGHTS:
			tier = Tier.LEGENDARY
			kind = "headlights"
			min_killer_distance = 30.0

func _fire() -> void:
	var car: Node3D = get_parent()
	match mode:
		Mode.CHIRP:
			EventSounds.play_at(get_tree(), CHIRP, car.global_position + Vector3.UP, -2.0, 45.0)
		Mode.CRANK:
			EventSounds.play_at(get_tree(), CRANK, car.global_position + Vector3.UP, 2.0, 55.0)
		Mode.HEADLIGHTS:
			await _headlights(car)

## World box around the car's meshes.
func _car_box(car: Node3D) -> AABB:
	var box := AABB(car.global_position, Vector3.ZERO)
	var first := true
	for m in car.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null:
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## Its headlights (at its real front) and tail lights, on for a few seconds.
func _headlights(car: Node3D) -> void:
	var p = PlayerManager.player
	if not is_instance_valid(p):
		return
	# lights at the car's real front (from its model - see _front)
	var box := _car_box(car)
	var center := box.get_center()
	var along := _front(car, p.global_position, box)
	var half_len: float = (absf(along.x) * box.size.x + absf(along.z) * box.size.z) * 0.5
	var side := along.cross(Vector3.UP).normalized()
	var lamps: Array[SpotLight3D] = []
	for s in [-1.0, 1.0]:
		var l := SpotLight3D.new()
		l.light_color = Color(1.0, 0.95, 0.8)
		l.light_energy = 0.0
		l.spot_range = 35.0
		l.spot_angle = 30.0
		l.shadow_enabled = false   # it sits at the bumper - the car would shadow it
		car.get_parent().add_child(l)
		l.global_position = Vector3(center.x, box.position.y + box.size.y * 0.35, center.z) + along * (half_len + 0.5) + side * s * 0.75
		l.look_at(l.global_position + along * 10.0 + Vector3.DOWN * 0.6)
		lamps.append(l)
		# and the lamp itself glowing
		var glow := OmniLight3D.new()
		glow.light_color = l.light_color
		glow.omni_range = 1.4
		glow.light_energy = 0.0
		l.add_child(glow)
		glow.position = Vector3(0, 0, 0.3)
	# and red tail lights at the back
	var tails: Array[OmniLight3D] = []
	for s in [-1.0, 1.0]:
		var t := OmniLight3D.new()
		t.light_color = Color(1.0, 0.08, 0.05)
		t.omni_range = 2.4
		t.light_energy = 0.0
		car.get_parent().add_child(t)
		t.global_position = Vector3(center.x, box.position.y + box.size.y * 0.4, center.z) - along * (half_len + 0.3) + side * s * 0.75
		tails.append(t)
	EventSounds.play_at(get_tree(), AudioManager.CarDoorLocked, car.global_position, -6.0, 30.0)
	var hum := EventSounds.play_at(get_tree(), IDLE, car.global_position + Vector3.UP, -4.0, 40.0)
	for l in lamps:
		l.light_energy = 14.0
		l.get_child(0).light_energy = 4.0
	for t in tails:
		t.light_energy = 3.0
	await get_tree().create_timer(4.5).timeout
	var tw := create_tween()
	for l in lamps:
		tw.parallel().tween_property(l, "light_energy", 0.0, 0.25)
	for t in tails:
		tw.parallel().tween_property(t, "light_energy", 0.0, 0.25)
	await tw.finished
	for l in lamps:
		l.queue_free()
	for t in tails:
		t.queue_free()
	if is_instance_valid(hum):
		hum.stop()
		hum.queue_free()

## Which way the car's front points (world, flat). The parked cars are three
## models, each facing its own way in its file: the sedan and SUV forward is
## their +Z, the pickup truck's is -X. Unknown models: the end facing the
## player (the old guess).
const MODEL_FRONT := {
	"M_NPCar_Unwrapped": Vector3(0, 0, 1),
	"M_SUV_Unwrapped": Vector3(0, 0, 1),
	"M_Truck_Unwrapped": Vector3(-1, 0, 0),
}

func _front(car: Node3D, player_pos: Vector3, box: AABB) -> Vector3:
	for m in car.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null:
			continue
		var model: String = m.mesh.resource_path.get_file().get_basename()
		if MODEL_FRONT.has(model):
			var f: Vector3 = m.global_basis * MODEL_FRONT[model]
			f.y = 0.0
			if f.length() > 0.001:
				return f.normalized()
	var along := Vector3.RIGHT if box.size.x >= box.size.z else Vector3.BACK
	return along if along.dot(player_pos - box.get_center()) >= 0.0 else -along
