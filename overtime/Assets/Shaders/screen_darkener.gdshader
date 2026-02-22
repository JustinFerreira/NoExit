shader_type spatial;
render_mode blend_mix, unshaded, cull_back;

uniform float darkness : hint_range(0, 1) = 0.7;

void fragment() {
    ALBEDO = vec3(0.0);
    ALPHA = darkness;
}