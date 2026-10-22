// No Exit - Screen-space outline
// Full-screen pass drawn on top of the game camera by OutlineManager.
// Reads the mask from OutlineMask.gdshader and paints a band just outside
// each outlined object's silhouette.
// - Only the parts of the object the camera can actually SEE count: every
//   mask pixel is checked against the scene's depth, so the bits hidden
//   behind a wall, a monitor or another prop make no outline at all.
// - Only pixels OUTSIDE the visible silhouette are painted, so hollow/open
//   models never show the outline on their insides.
// - It's drawn after the scene, so the desk/floor an object sits on can't
//   hide the bottom of the outline.
// - Band pixels where something is clearly in front of the object are
//   skipped too, so the outline never paints over things in front of it.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, ambient_light_disabled;

uniform sampler2D mask_texture : filter_nearest, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

uniform vec4 outline_color : source_color = vec4(0.6, 0.0156863, 0.0156863, 1.0);
// Thickness in pixels of the game's render resolution (max 8).
uniform float outline_width = 3.0;
// Must match OutlineMask.gdshader's depth_scale.
uniform float depth_scale = 200.0;
// How far in front of the object something can be (in units, plus a
// fraction of the distance) before it counts as blocking the outline band.
// Loose on purpose so the desk an item sits on doesn't eat its bottom edge.
uniform float occlusion_tolerance = 0.5;
uniform float occlusion_tolerance_ratio = 0.1;
// How closely a mask pixel must match what the camera sees to count as a
// visible part of the object (same surface, so this can be tight - it
// only has to cover depth precision).
uniform float visible_tolerance = 0.05;
uniform float visible_tolerance_ratio = 0.01;

// Distance from the camera to whatever the game camera sees at this pixel.
float scene_depth_at(vec2 uv, mat4 inv_projection) {
	float raw_depth = texture(depth_texture, uv).r;
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, raw_depth, 1.0);
	return -view.z / view.w;
}

// Is the outlined object's surface at this pixel actually visible, or is
// something in front of it?
bool is_visible(float object_depth, float scene_depth) {
	return scene_depth >= object_depth - (visible_tolerance + object_depth * visible_tolerance_ratio);
}

void vertex() {
	// Cover the whole screen no matter where the camera is.
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float here_scene = scene_depth_at(uv, INV_PROJECTION_MATRIX);
	vec4 here = texture(mask_texture, uv);
	if (here.b > 0.5 && is_visible(here.r * depth_scale, here_scene)) {
		discard;   // on the visible part of an object
	}

	vec2 texel = 1.0 / vec2(textureSize(mask_texture, 0));
	float width = clamp(outline_width, 1.0, 8.0);
	int reach = int(ceil(width));
	float best_strength = 0.0;
	float nearest_depth = 1e9;
	for (int x = -reach; x <= reach; x++) {
		for (int y = -reach; y <= reach; y++) {
			if (float(x * x + y * y) > width * width) {
				continue;
			}
			vec2 suv = uv + vec2(float(x), float(y)) * texel;
			vec4 s = texture(mask_texture, suv);
			if (s.b > 0.5) {
				float d = s.r * depth_scale;
				// Hidden behind something: that part of the object doesn't
				// get an outline.
				if (!is_visible(d, scene_depth_at(suv, INV_PROJECTION_MATRIX))) {
					continue;
				}
				best_strength = max(best_strength, s.g);
				nearest_depth = min(nearest_depth, d);
			}
		}
	}
	if (best_strength <= 0.001) {
		discard;
	}

	// Don't paint the band over something that's in front of the object.
	if (here_scene < nearest_depth - (occlusion_tolerance + nearest_depth * occlusion_tolerance_ratio)) {
		discard;
	}

	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a * best_strength;
}
