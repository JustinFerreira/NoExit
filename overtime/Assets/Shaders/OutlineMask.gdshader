// No Exit - Outline mask
// Drawn by OutlineManager's offscreen camera only (never seen in game).
// Marks which pixels belong to an outlined object and how far away they are.
//   R = distance from camera / depth_scale
//   G = outline strength (1 = hover outline, 0-1 while flashing)
//   B = 1 wherever the object covers the screen
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled;

uniform float strength = 1.0;
uniform float depth_scale = 200.0;

varying float view_depth;

void vertex() {
	view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	ALBEDO = vec3(view_depth / depth_scale, strength, 1.0);
}
