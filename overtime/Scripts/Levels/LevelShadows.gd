## No Exit
## Overtime Studios
## Last updated 10/22/26 by Justin Ferreira
## Level Shadows
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
