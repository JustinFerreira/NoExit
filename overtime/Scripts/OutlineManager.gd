## No Exit
## Overtime Studios
## Last updated 10/18/26 by Justin Ferreira
## Outline Manager
## - Draws every Interactable outline as a screen-space effect.
## - Created automatically the first time an Interactable with has_outline
##   is ready. Nothing to set up in any scene.
##
## How it works:
##   1. Each outlined object has an invisible "mask" copy of its mesh on
##      MASK_LAYER (see Interactable). The game camera never draws that layer.
##   2. An offscreen camera that copies the game camera every frame draws
##      ONLY the mask layer, recording which pixels each object covers and
##      how far away they are (OutlineMask.gdshader).
##   3. A full-screen pass on the game camera paints a band just outside
##      those pixels (OutlineComposite.gdshader), skipping spots where a
##      wall is in front.
##
## Change OUTLINE_COLOR / OUTLINE_WIDTH below to restyle every outline.

extends Node
class_name OutlineManager

const OUTLINE_COLOR: Color = Color(0.6, 0.0156863, 0.0156863, 1.0)
## Thickness in pixels of the game's render resolution (1-8).
const OUTLINE_WIDTH: float = 3.0

## Render layer (1-20) only the mask camera sees.
const MASK_LAYER: int = 20
## Render layer (1-20) for the full-screen pass, kept off layer 1 so
## nothing that edits layer-1 materials (like examine darkening) touches it.
const COMPOSITE_LAYER: int = 19

const MASK_BIT: int = 1 << (MASK_LAYER - 1)
const COMPOSITE_BIT: int = 1 << (COMPOSITE_LAYER - 1)
const DEPTH_SCALE: float = 200.0

const MASK_SHADER: Shader = preload("res://Assets/Shaders/OutlineMask.gdshader")
const COMPOSITE_SHADER: Shader = preload("res://Assets/Shaders/OutlineComposite.gdshader")

static var _instance: OutlineManager

var _viewport: SubViewport
var _mask_camera: Camera3D
var _composite: MeshInstance3D
# Mask MeshInstance3Ds currently showing an outline.
var _active: Dictionary = {}


## Returns the manager, creating it under the scene root if needed.
static func get_instance(tree: SceneTree) -> OutlineManager:
	if not is_instance_valid(_instance):
		_instance = OutlineManager.new()
		_instance.name = "OutlineManager"
		tree.root.add_child.call_deferred(_instance)
	return _instance


## Makes a mask copy of `source` (child of it, so it follows it around).
## Interactable calls this once per outlined mesh.
static func create_mask(source: MeshInstance3D, mask_material: ShaderMaterial) -> MeshInstance3D:
	var mask := MeshInstance3D.new()
	mask.name = "OutlineMask"
	mask.mesh = source.mesh
	mask.layers = MASK_BIT
	mask.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mask.material_override = mask_material
	mask.visible = false
	# Deferred: Interactables are usually children of `source`, so it's still
	# busy setting up its children when this runs from their _ready().
	source.add_child.call_deferred(mask)
	return mask


static func make_mask_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = MASK_SHADER
	mat.set_shader_parameter("depth_scale", DEPTH_SCALE)
	mat.set_shader_parameter("strength", 0.0)
	return mat


## Called by Interactable when a mask starts/stops showing.
func set_mask_active(mask: MeshInstance3D, active: bool) -> void:
	if active:
		_active[mask] = true
	else:
		_active.erase(mask)


func _ready() -> void:
	# Run after everything else this frame so the camera has already moved.
	process_priority = 1000000
	process_mode = Node.PROCESS_MODE_ALWAYS

	_viewport = SubViewport.new()
	_viewport.name = "MaskViewport"
	_viewport.use_hdr_2d = true            # float texture, keeps depth precise
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_viewport.positional_shadow_atlas_size = 0
	_viewport.audio_listener_enable_3d = false
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	_mask_camera = Camera3D.new()
	_mask_camera.name = "MaskCamera"
	_mask_camera.cull_mask = MASK_BIT
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_mask_camera.environment = env
	_viewport.add_child(_mask_camera)
	_mask_camera.current = true

	var comp_mat := ShaderMaterial.new()
	comp_mat.shader = COMPOSITE_SHADER
	comp_mat.render_priority = Material.RENDER_PRIORITY_MAX
	comp_mat.set_shader_parameter("mask_texture", _viewport.get_texture())
	comp_mat.set_shader_parameter("outline_color", OUTLINE_COLOR)
	comp_mat.set_shader_parameter("outline_width", OUTLINE_WIDTH)
	comp_mat.set_shader_parameter("depth_scale", DEPTH_SCALE)

	_composite = MeshInstance3D.new()
	_composite.name = "OutlineComposite"
	_composite.mesh = QuadMesh.new()
	_composite.material_override = comp_mat
	_composite.layers = COMPOSITE_BIT
	_composite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader places it over the whole screen itself; never cull it.
	_composite.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	_composite.visible = false
	add_child(_composite)


func _process(_delta: float) -> void:
	# Drop masks whose objects were freed; only draw if one is on screen-able
	# (e.g. a picked-up item's hidden parent hides its mask too).
	var any_visible := false
	for mask in _active.keys():
		if not is_instance_valid(mask) or not mask.is_inside_tree():
			_active.erase(mask)
		elif mask.is_visible_in_tree():
			any_visible = true

	var camera := get_tree().root.get_camera_3d()
	var on := any_visible and camera != null
	_composite.visible = on
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on:
		return

	# The game camera draws the outline pass but never the masks.
	camera.cull_mask = (camera.cull_mask | COMPOSITE_BIT) & ~MASK_BIT

	# Mask camera matches the game camera exactly.
	var size := Vector2i(get_tree().root.get_visible_rect().size)
	if _viewport.size != size:
		_viewport.size = size
	_mask_camera.global_transform = camera.global_transform
	_mask_camera.projection = camera.projection
	_mask_camera.fov = camera.fov
	_mask_camera.size = camera.size
	_mask_camera.keep_aspect = camera.keep_aspect
	_mask_camera.near = camera.near
	_mask_camera.far = camera.far
	_mask_camera.h_offset = camera.h_offset
	_mask_camera.v_offset = camera.v_offset
	_mask_camera.frustum_offset = camera.frustum_offset
