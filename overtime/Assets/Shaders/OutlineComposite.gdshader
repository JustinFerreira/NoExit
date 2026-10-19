// No Exit - Screen-space outline
// Full-screen pass drawn on top of the game camera by OutlineManager.
// Reads the mask from OutlineMask.gdshader and paints a band just outside
// each outlined object's silhouette.
// - Only pixels OUTSIDE the silhouette are painted, so hollow/open models
//   never show the outline on their insides.
// - It's drawn after the scene, so the desk/floor an object sits on can't
//   hide the bottom of the outline.
// - Pixels where something is clearly in front of the object (a wall) are
//   skipped, so outlines don't show through walls.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, ambient_light_disabled;

uniform sampler2D mask_texture : filter_nearest, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

uniform vec4 outline_color : source_color = vec4(0.6, 0.0156863, 0.0156863, 1.0);
// Thickness in pixels of the game's render resolution (max 8).
uniform float outline_width = 3.0;
// Must match OutlineMask.gdshader's depth_scale.
uniform float depth_scale = 200.0;
// How far in front of the object something can be (in meters, plus a
// fraction of the distance) before it counts as blocking the outline.
uniform float occlusion_tolerance = 0.5;
uniform float occlusion_tolerance_ratio = 0.1;

void vertex() {
	// Cover the whole screen no matter where the camera is.
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (texture(mask_texture, uv).b > 0.5) {
		discard;   // inside an object
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
			vec4 s = texture(mask_texture, uv + vec2(float(x), float(y)) * texel);
			if (s.b > 0.5) {
				best_strength = max(best_strength, s.g);
				nearest_depth = min(nearest_depth, s.r * depth_scale);
			}
		}
	}
	if (best_strength <= 0.001) {
		discard;
	}

	// Distance to whatever the game camera actually sees at this pixel.
	float raw_depth = texture(depth_texture, uv).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, raw_depth, 1.0);
	float scene_depth = -view.z / view.w;
	if (scene_depth < nearest_depth - (occlusion_tolerance + nearest_depth * occlusion_tolerance_ratio)) {
		discard;   // a wall or something is in front of the object here
	}

	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a * best_strength;
}
