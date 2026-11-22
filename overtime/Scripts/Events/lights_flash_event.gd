## No Exit
## Overtime Studios
## Light Flicker Event (COMMON - comes back after kind_cooldown, see GarageEvent)
## - When the director allows it, the working lights around the player
##   stutter on and off together - a few out of step - with a buzz of
##   sparks - then settle back on. Broken lights stay dark.
## - Every time it's a different length (FLAVOURS): a quick blip of just the
##   lights around you, a short stutter, a long struggle with long dark spells,
##   or now and then a really long one.

extends "res://Scripts/Events/GarageEvent.gd"

const EventSounds = preload("res://Scripts/Events/EventSounds.gd")

## [chance, seconds min, seconds max, radius (m), longest dark spell (s)]
const FLAVOURS := [
	[0.40, 0.5, 1.2, 18.0, 0.3],    # blip - the lights right around you
	[0.35, 1.2, 2.5, 22.0, 0.5],    # short stutter
	[0.20, 3.5, 6.0, 30.0, 1.0],    # long struggle
	[0.05, 7.0, 10.0, 36.0, 1.6],   # really long - almost dies
]

func _init() -> void:
	tier = Tier.COMMON
	kind = "light_flicker"
	kind_cooldown = 70.0
	weight = 1.4
	repeatable = true

func _pick_flavour() -> Array:
	var r := randf()
	for f in FLAVOURS:
		r -= f[0]
		if r <= 0.0:
			return f
	return FLAVOURS[0]

func _fire() -> void:
	var p = PlayerManager.player
	if not is_instance_valid(p):
		return
	var f := _pick_flavour()
	var lights := []
	for light in PlayerManager.ParkingGarageLights:
		if is_instance_valid(light) and not light.has_meta("broken") \
				and light.global_position.distance_to(p.global_position) < f[3]:
			lights.append(light)
	if lights.is_empty():
		return
	var length: float = randf_range(f[1], f[2])
	EventSounds.play_at(get_tree(), AudioManager.ElectricSpark1, lights[0].global_position, -6.0 if length > 1.0 else -10.0, 40.0)
	var end := Time.get_ticks_msec() + int(length * 1000.0)
	# The lights mostly go together (so the whole area really drops dark),
	# with a few out of step each time - all on their own, the area's light
	# averaged out and it hardly looked like a flicker.
	var on := true
	while Time.get_ticks_msec() < end:
		on = not on
		for light in lights:
			if is_instance_valid(light) and not light.has_meta("broken"):
				HelperManager.set_light_panel_lit(light, on if randf() < 0.82 else not on)
		var wait: float
		if on:
			# mostly a split second of light; on the long ones it sometimes
			# seems to recover for a moment before it goes again
			wait = randf_range(0.04, 0.16) if (randf() < 0.85 or f[4] < 0.5) else randf_range(0.3, 0.7)
		else:
			wait = randf_range(0.06, 0.22) if randf() < 0.7 else randf_range(0.25, f[4])
		if randf() < 0.25:
			EventSounds.play_at(get_tree(), AudioManager.GetSpark(), lights.pick_random().global_position, -12.0, 35.0)
		await get_tree().create_timer(wait).timeout
	await get_tree().create_timer(0.15).timeout
	for light in lights:
		if is_instance_valid(light) and not light.has_meta("broken"):
			HelperManager.set_light_panel_lit(light, true)
