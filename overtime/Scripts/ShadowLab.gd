## No Exit
## Overtime Studios
## Last updated 10/22/26 by Justin Ferreira
## Shadow Lab
## - A test room for learning how shadows behave in Godot. Walk around and
##   use the number keys to change one thing at a time; the panel shows what
##   each setting is and what it costs.
## - Everything here is built in code so it's easy to read: look at
##   _build_room() for the props and _build_lights() for the lights.
##
## How shadows work (the short version):
##   * A light only casts shadows if its "Shadow > Enabled" box is ticked.
##     (Every light in the game currently has it off.)
##   * A shadow is just "this light can't reach here". Any OTHER light, or the
##     environment's ambient light, still lights that spot - so lots of
##     overlapping lights or strong ambient make shadows faint.
##   * Directional light (sun/moon) = one shadow map, cheapest, all shadows
##     point the same way. Spot = one shadow map in a cone. Omni (bulb) =
##     six shadow maps (a cube), the most expensive.
##   * light_size / shadow_blur make edges soft; bias stops "shadow acne"
##     (stripes) and normal_bias stops shadows detaching from feet.

extends Node3D

enum LightType { OMNI, SPOT, DIRECTIONAL }

var light_type: LightType = LightType.OMNI
var shadows_on := true
var fill_lights_on := false
var ambient_levels := [0.0, 0.2, 0.5]
var ambient_index := 0
var softness_levels := [["Sharp", 0.0, 0.0], ["Soft", 0.3, 1.5], ["Very soft", 0.8, 3.0]]
var softness_index := 0
var brightness_levels := [1.0, 2.5, 5.0]
var brightness_index := 1
var follow_player := false

var _main_light: Light3D
var _fill_lights: Array[OmniLight3D] = []
var _env: Environment
var _hud: Label
var _hud_visible := true
var _frame_ms := 0.0

const LIGHT_HOME := Vector3(0, 6.5, 0)


func _ready() -> void:
	_build_environment()
	_build_room()
	_build_lights()
	_build_hud()
	_apply()


## ---------------------------------------------------------------------
## Keys
## ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_1: shadows_on = not shadows_on
		KEY_2: light_type = ((int(light_type) + 1) % 3) as LightType
		KEY_3: fill_lights_on = not fill_lights_on
		KEY_4: ambient_index = (ambient_index + 1) % ambient_levels.size()
		KEY_5: softness_index = (softness_index + 1) % softness_levels.size()
		KEY_6: brightness_index = (brightness_index + 1) % brightness_levels.size()
		KEY_7: follow_player = not follow_player
		KEY_H:
			_hud_visible = not _hud_visible
			_hud.get_parent().visible = _hud_visible
			return
		_: return
	_apply()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_frame_ms = lerpf(_frame_ms, delta * 1000.0, 0.05)
	if follow_player and is_instance_valid(PlayerManager.player) and light_type != LightType.DIRECTIONAL:
		# Hover above and a little in front of the player, so their own
		# shadow and the props' shadows swing around as they walk.
		var p: Node3D = PlayerManager.player
		var ahead: Vector3 = -p.head.global_basis.z
		ahead.y = 0.0
		_main_light.global_position = p.global_position + Vector3(0, 5.5, 0) + ahead.normalized() * 1.5
		if _main_light is SpotLight3D:
			_main_light.look_at(_main_light.global_position + Vector3(0, -1, 0) + ahead * 0.01, Vector3.FORWARD)
	_update_hud()


## ---------------------------------------------------------------------
## Applying the settings
## ---------------------------------------------------------------------

func _apply() -> void:
	if _main_light:
		_main_light.queue_free()
	match light_type:
		LightType.OMNI:
			var l := OmniLight3D.new()
			l.omni_range = 24.0
			l.omni_attenuation = 0.5
			_main_light = l
		LightType.SPOT:
			var l := SpotLight3D.new()
			l.spot_range = 24.0
			l.spot_angle = 60.0
			l.spot_attenuation = 0.4
			_main_light = l
		LightType.DIRECTIONAL:
			var l := DirectionalLight3D.new()
			l.rotation_degrees = Vector3(-55, 35, 0)
			l.directional_shadow_max_distance = 60.0
			_main_light = l
	_main_light.name = "MainLight"
	add_child(_main_light)
	if light_type != LightType.DIRECTIONAL:
		_main_light.position = LIGHT_HOME
		if _main_light is SpotLight3D:
			_main_light.rotation_degrees = Vector3(-90, 0, 0)

	var soft: Array = softness_levels[softness_index]
	# Bulbs/spots fade with distance, so they need more energy than the sun.
	_main_light.light_energy = brightness_levels[brightness_index] * (0.6 if light_type == LightType.DIRECTIONAL else 2.0)
	_main_light.shadow_enabled = shadows_on
	_main_light.light_size = soft[1] if light_type != LightType.DIRECTIONAL else 0.0
	_main_light.light_angular_distance = soft[1] * 3.0 if light_type == LightType.DIRECTIONAL else 0.0
	_main_light.shadow_blur = maxf(soft[2], 1.0)
	_main_light.shadow_bias = 0.03
	_main_light.shadow_normal_bias = 1.0

	for l in _fill_lights:
		l.visible = fill_lights_on
	_env.ambient_light_energy = ambient_levels[ambient_index]


## ---------------------------------------------------------------------
## Building the room
## ---------------------------------------------------------------------

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.02, 0.02, 0.025)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.8, 0.85, 1.0)
	we.environment = _env
	add_child(we)

func _build_lights() -> void:
	# Extra lights WITHOUT shadows, like the office's many ceiling lights -
	# turn them on (key 3) to see them fill the shadows back in.
	for pos in [Vector3(-9, 6, -9), Vector3(9, 6, -9), Vector3(-9, 6, 9), Vector3(9, 6, 9)]:
		var l := OmniLight3D.new()
		l.position = pos
		l.omni_range = 16.0
		l.light_energy = 1.5
		l.shadow_enabled = false
		add_child(l)
		_fill_lights.append(l)

func _build_room() -> void:
	var grey := Color(0.55, 0.55, 0.58)
	_solid(Vector3(30, 0.2, 30), Vector3(0, -0.1, 0), grey)          # floor
	_solid(Vector3(30, 8, 0.3), Vector3(0, 4, -15), grey)            # walls
	_solid(Vector3(30, 8, 0.3), Vector3(0, 4, 15), grey)
	_solid(Vector3(0.3, 8, 30), Vector3(-15, 4, 0), grey)
	_solid(Vector3(0.3, 8, 30), Vector3(15, 4, 0), grey)

	# A table (top + legs) - shows shadows falling under things.
	var table := Vector3(-5, 0, -3)
	_solid(Vector3(4, 0.2, 2.4), table + Vector3(0, 2.0, 0), Color(0.6, 0.45, 0.3))
	for x in [-1.8, 1.8]:
		for z in [-1.0, 1.0]:
			_solid(Vector3(0.2, 2.0, 0.2), table + Vector3(x, 1.0, z), Color(0.4, 0.3, 0.2))
	_solid(Vector3(0.8, 0.8, 0.8), table + Vector3(-0.8, 2.5, 0), Color(0.8, 0.3, 0.3))   # box on the table

	# A tall pillar - long shadow across the floor.
	_solid(Vector3(0.7, 6.0, 0.7), Vector3(4, 3.0, -4), Color(0.3, 0.5, 0.85))
	# A ball and a floating cube - round shadows, and a shadow that's
	# separated from the object.
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	ball.mesh = sphere
	ball.material_override = _mat(Color(0.85, 0.75, 0.3))
	ball.position = Vector3(5, 1.0, 3)
	add_child(ball)
	_solid(Vector3(1, 1, 1), Vector3(-4, 2.5, 5), Color(0.4, 0.8, 0.5), false)
	# Steps - shadows over uneven ground.
	for i in 4:
		_solid(Vector3(3, 0.4 * (i + 1), 1), Vector3(9, 0.2 * (i + 1), -8 + i), Color(0.5, 0.5, 0.5))
	# A thin railing - thin objects make thin shadows (and show bias issues).
	for i in 6:
		_solid(Vector3(0.08, 2.4, 0.08), Vector3(-10 + i * 0.8, 1.2, -10), Color(0.8, 0.8, 0.8))
	_solid(Vector3(4.2, 0.1, 0.1), Vector3(-8, 2.4, -10), Color(0.8, 0.8, 0.8))

func _solid(size: Vector3, pos: Vector3, color: Color, collide: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _mat(color)
	mi.position = pos
	add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


## ---------------------------------------------------------------------
## Panel
## ---------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = UiManager.LAYER_HUD
	add_child(layer)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "FramePanel"
	panel.position = Vector2(12, 40)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	_hud = Label.new()
	_hud.add_theme_font_size_override("font_size", 12)
	panel.add_child(_hud)

func _update_hud() -> void:
	if not _hud_visible:
		return
	var type_names := ["Omni (bulb, 6 shadow maps)", "Spot (cone, 1 shadow map)", "Directional (sun, 1 shadow map)"]
	var on_off := func(b): return "ON" if b else "off"
	_hud.text = "SHADOW LAB\n" + \
		"1  Shadows ............ %s\n" % on_off.call(shadows_on) + \
		"2  Light type ......... %s\n" % type_names[light_type] + \
		"3  Extra lights ....... %s  (no shadows - fill them in)\n" % on_off.call(fill_lights_on) + \
		"4  Ambient light ...... %.1f  (lifts every shadow)\n" % ambient_levels[ambient_index] + \
		"5  Softness ........... %s\n" % softness_levels[softness_index][0] + \
		"6  Brightness ......... %.1f\n" % brightness_levels[brightness_index] + \
		"7  Light follows you .. %s\n" % on_off.call(follow_player) + \
		"H  Hide this panel\n" + \
		"Frame: %.1f ms" % _frame_ms
