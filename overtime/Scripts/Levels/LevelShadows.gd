## No Exit
## Overtime Studios
## Last updated 10/22/26 by Justin Ferreira
## Level Shadows
## - Brightness / ambient light can be tested live from the dev pause
##   menu's Dev Tools page.
## - Drop this node into any level to turn on shadows for its lights,
##   without editing every light by hand. Tweak the settings in the
##   inspector while the game runs to see the effect.
## - Only lights near the camera draw shadows (distance fade), which keeps
##   the cost down in rooms with lots of lights - like the office's 30
##   ceiling lights, where shadows on all of them at once was ~12x slower.
## - See the Shadow Lab level (Loop Select) for what each setting does.

extends Node

## Turn shadows on for these kinds of light.
@export var omni_lights: bool = true
@export var spot_lights: bool = true
@export var directional_lights: bool = true
## Skip dim lights (energy below this) - they barely show a shadow anyway.
@export var min_energy: float = 0.5

@export_group("Distance")
## Shadows start fading out this far from the camera (in game units; the
## player is 3.3 tall)...
@export var shadow_fade_begin: float = 18.0
## ...and are gone this much farther on.
@export var shadow_fade_length: float = 8.0

@export_group("Look")
## 0 = sharp edges, higher = softer, wider edges (costs a little more).
@export_range(0.0, 2.0) var softness: float = 0.15
## How dark shadows are: 1 = fully dark, lower lets some light through.
@export_range(0.0, 1.0) var shadow_opacity: float = 1.0
## Pushes shadows slightly away from surfaces to stop striped "shadow acne".
@export var bias: float = 0.04
@export var normal_bias: float = 1.2
## Shrinks how far bulbs and spots reach. Lights that cover the whole room
## all shine into each other's shadows (faint shadows) and every shadow map
## has to cover the whole room (slow) - shorter range fixes both. Raise
## energy_scale to make up the lost brightness.
@export var range_scale: float = 1.0
## Optional: scale every light's brightness (overlapping lights fill shadows
## in - lowering this makes shadows read stronger).
@export var energy_scale: float = 1.0

var _lights: Array[Light3D] = []

## --- Live test controls (Dev Tools page in the dev pause menu) ---
## Multiplies every light's brightness on top of energy_scale.
var brightness: float = 1.0
## Flat fill light everywhere - lifts every shadow (dark desks, corners).
var ambient_on: bool = false
var ambient_energy: float = 0.3
var ambient_color: Color = Color(0.9, 0.9, 0.85)

var _all_lights: Array[Light3D] = []
var _base_energy: Dictionary = {}   # Light3D -> energy after apply()
var _env: Environment
var _env_orig: Dictionary = {}


func _enter_tree() -> void:
	# Lets the dev pause menu find this node.
	add_to_group("level_shadows")


func _ready() -> void:
	# After the level's own _ready (lights get set up / swapped there).
	apply.call_deferred()


## Finds the level's lights and applies the settings above.
func apply() -> void:
	var level := owner if owner else get_parent()
	_lights.clear()
	for l in level.find_children("*", "Light3D", true, false):
		var light := l as Light3D
		if light.light_energy < min_energy:
			continue
		if (light is OmniLight3D and omni_lights) or (light is SpotLight3D and spot_lights) \
				or (light is DirectionalLight3D and directional_lights):
			_lights.append(light)
	for light in _lights:
		light.shadow_enabled = true
		light.shadow_bias = bias
		light.shadow_normal_bias = normal_bias
		light.shadow_opacity = shadow_opacity
		light.light_energy *= energy_scale
		if light is OmniLight3D:
			light.omni_range *= range_scale
		elif light is SpotLight3D:
			light.spot_range *= range_scale
		if light is DirectionalLight3D:
			light.light_angular_distance = softness * 2.0
		else:
			light.light_size = softness
			# Built-in distance fade: far lights stop drawing shadows.
			light.distance_fade_enabled = true
			light.distance_fade_shadow = shadow_fade_begin
			light.distance_fade_begin = shadow_fade_begin + shadow_fade_length + 200.0   # the light itself never fades
			light.distance_fade_length = shadow_fade_length
	print("LevelShadows: shadows on for %d lights" % _lights.size())
	_all_lights.clear()
	_base_energy.clear()
	for l in level.find_children("*", "Light3D", true, false):
		_all_lights.append(l)
		_base_energy[l] = (l as Light3D).light_energy
	_setup_environment(level)
	_apply_brightness()
	_apply_ambient()


## Grabs the level's environment (a private copy, so changes don't stick to
## the saved scene) and remembers its original ambient settings.
func _setup_environment(level: Node) -> void:
	var envs := level.find_children("*", "WorldEnvironment", true, false)
	var we: WorldEnvironment
	if envs.is_empty():
		we = WorldEnvironment.new()
		level.add_child(we)
	else:
		we = envs[0]
	if we.environment == null:
		we.environment = Environment.new()
	else:
		we.environment = we.environment.duplicate()
	_env = we.environment
	_env_orig = {
		"source": _env.ambient_light_source,
		"color": _env.ambient_light_color,
		"energy": _env.ambient_light_energy,
	}


func set_brightness(value: float) -> void:
	brightness = clampf(value, 0.0, 10.0)
	_apply_brightness()
	_print_values()


func set_ambient(on: bool, energy: float = ambient_energy) -> void:
	ambient_on = on
	ambient_energy = clampf(energy, 0.0, 3.0)
	_apply_ambient()
	_print_values()


func _apply_brightness() -> void:
	for light in _all_lights:
		if is_instance_valid(light):
			light.light_energy = _base_energy[light] * brightness


func _apply_ambient() -> void:
	if _env == null:
		return
	if ambient_on:
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.ambient_light_color = ambient_color
		_env.ambient_light_energy = ambient_energy
	else:
		_env.ambient_light_source = _env_orig.source
		_env.ambient_light_color = _env_orig.color
		_env.ambient_light_energy = _env_orig.energy


## Printed so good values can be copied into the inspector afterwards.
func _print_values() -> void:
	print("LevelShadows: brightness x%.2f (energy_scale to bake in: %.2f) | ambient %s %.2f" % [
		brightness, energy_scale * brightness, "ON" if ambient_on else "off", ambient_energy])
