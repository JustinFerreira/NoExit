// No Exit - Overtime Studios
// Damage overlay (Scripts/UI/DamageOverlay.gd drives it)
// - hurt:   0 = full health, 1 = none left. Tints the picture red, edges
//           first, the whole screen as it runs out (with a heartbeat pulse
//           when it's low).
// - impacts: one cracked-glass star per hit - spokes out from where it hit,
//           broken rings between them, the shards bending the picture a
//           little. Their reach (z) grows as health falls.
// - flash:  the red jolt of a hit.
// - dead:   0-1, fades the whole screen to solid red.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float hurt : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// how strongly the cracks show (fades them out as health comes back)
uniform float crack_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float dead : hint_range(0.0, 1.0) = 0.0;
// the solid red of death (DamageOverlay.DEAD_RED)
uniform vec3 dead_color = vec3(0.62, 0.0, 0.0);
uniform float aspect = 1.7778;
uniform int impact_count = 0;
// xy = where it hit (0-1 screen), z = reach (screen heights), w = random seed
uniform vec4 impacts[8];

const float SPOKES = 9.0;

float hash(float n) { return fract(sin(n * 12.9898 + 4.1414) * 43758.5453); }

// x = distance (screen heights) to the nearest crack of one impact,
// y = which shard this pixel is in (0 = outside it)
vec2 crack(vec2 uv, vec4 im) {
	vec2 d = uv - im.xy;
	d.x *= aspect;
	float r = length(d);
	float reach = im.z;
	if (r > reach || reach <= 0.0) return vec2(1.0, 0.0);
	float seed = im.w;
	float a = atan(d.y, d.x) / TAU + 0.5;   // 0-1 round the hit
	float t = a * SPOKES;
	float i = floor(t);
	float best = 1.0;
	// spokes: this sector's and its neighbours' - each at a random angle in
	// its sector, wiggling, with its own length
	for (int k = -1; k <= 1; k++) {
		float j = i + float(k);
		float jj = mod(j, SPOKES);
		float at = j + 0.2 + 0.6 * hash(jj + seed);
		// jagged: straight bits with a random kink every so often
		float seg = r / reach * 7.0;
		float s0 = floor(seg);
		float kink = mix(hash(s0 + jj * 31.0 + seed), hash(s0 + 1.0 + jj * 31.0 + seed), fract(seg)) - 0.5;
		at += kink * 0.05 / max(r / reach, 0.15);
		float len = reach * (0.45 + 0.55 * hash(jj * 3.7 + seed));
		if (r < len) {
			best = min(best, abs(t - at) / SPOKES * TAU * r);
		}
	}
	// straight cross-cracks joining neighbouring spokes (only some sectors -
	// a broken web, not rings)
	float half_w = 0.5 / SPOKES * TAU;
	float across = r * cos((fract(t) - 0.5) * 2.0 * half_w);
	for (int k = 1; k <= 3; k++) {
		float fk = float(k);
		float rk = reach * (0.14 + 0.22 * fk) * (0.8 + 0.4 * hash(fk + i * 3.1 + seed * 1.3));
		// only where this sector's spoke reaches (no loose bits out past it)
		float spoke_len = reach * (0.45 + 0.55 * hash(mod(i, SPOKES) * 3.7 + seed));
		if (rk < spoke_len * 0.9 && hash(i + fk * 17.0 + seed) > 0.55) {
			best = min(best, abs(across - rk));
		}
	}
	float band = floor(r / (reach * 0.25));
	return vec2(best, 0.05 + 0.95 * hash(i * 7.0 + band * 13.0 + seed));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float line = 0.0;
	float shard = 0.0;
	float core = 0.0;
	for (int n = 0; n < 8; n++) {
		if (n >= impact_count) break;
		vec2 c = crack(uv, impacts[n]);
		line = max(line, 1.0 - smoothstep(0.0009, 0.0032, c.x));
		if (c.y > 0.0) shard = c.y;
		vec2 d = (uv - impacts[n].xy) * vec2(aspect, 1.0);
		core = max(core, (1.0 - smoothstep(0.0, 0.035, length(d))) * step(0.001, impacts[n].z));
	}
	// each shard sits at a slightly different angle: the picture is bent
	line *= crack_alpha;
	core *= crack_alpha;
	vec2 off = (vec2(shard, fract(shard * 7.31)) - 0.5) * 0.007 * step(0.001, shard) * crack_alpha;
	vec3 col = textureLod(screen_tex, uv + off, 0.0).rgb;
	// shards a touch lighter / darker, cracks bright with the smash point white
	col *= 1.0 + (shard - 0.5) * 0.12 * step(0.001, shard) * crack_alpha;
	col = mix(col, vec3(0.92, 0.88, 0.88), line * 0.75);
	col = mix(col, vec3(1.0), core * 0.55);

	// red: in from the edges, over the whole picture as health runs out
	vec2 v = (uv - 0.5) * vec2(aspect, 1.0);
	float far = length(v) / (0.5 * sqrt(aspect * aspect + 1.0));   // 1 = a corner
	float beat = pow(0.5 + 0.5 * sin(TIME * 7.0), 6.0) * smoothstep(0.5, 0.9, hurt);
	float edge = smoothstep(mix(1.05, 0.15, hurt), 1.1, far + beat * 0.08);
	vec3 tinted = col * vec3(1.0, 0.45, 0.45) + vec3(0.12, 0.0, 0.0);
	col = mix(col, tinted, clamp(hurt * 0.6 + flash * 0.5, 0.0, 1.0));
	col = mix(col, vec3(0.45, 0.0, 0.0), clamp(edge * (0.3 + 0.4 * hurt) + beat * 0.1, 0.0, 1.0));

	col = mix(col, dead_color, dead);
	COLOR = vec4(col, 1.0);
}
