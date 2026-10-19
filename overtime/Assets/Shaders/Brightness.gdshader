// No Exit - Brightness setting
// Full-screen gamma adjust used by SettingsManager. brightness > 1 lifts
// the dark parts of the picture (so players can see in dark rooms without
// washing out the lights); < 1 darkens.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float brightness = 1.0;

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	COLOR = vec4(pow(color, vec3(1.0 / max(brightness, 0.01))), 1.0);
}
