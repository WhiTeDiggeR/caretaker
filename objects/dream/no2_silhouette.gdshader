shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// The silhouette of №2 (#240): a dark human figure without details, drawn as a distance field
// on a quad that turns to the camera around Y. The edge is eaten by rising noise and slowly
// breathes; the whole figure faintly flickers like interference. Origin at the feet.

uniform vec2 size = vec2(1.0, 2.0);
uniform float edge_soft = 0.035;
uniform float edge_noise = 0.05;
uniform float haze = 0.35;
uniform float haze_reach = 0.07;
uniform float breath = 0.008;
uniform float rise_speed = 0.35;
uniform float flicker = 0.18;
instance uniform vec4 tint : source_color = vec4(0.04, 0.035, 0.05, 1.0);
instance uniform float opacity = 0.92;
instance uniform float seed = 0.0;

varying vec2 body;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float weight = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		total += value_noise(p) * weight;
		p = p * 2.03 + vec2(1.7, 9.2);
		weight *= 0.5;
	}
	return total;
}

float capsule(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

// Isosceles trapezoid centred at the origin: bottom half-width r1, top r2, half-height he.
float trapezoid(vec2 p, float r1, float r2, float he) {
	vec2 k1 = vec2(r2, he);
	vec2 k2 = vec2(r2 - r1, 2.0 * he);
	p.x = abs(p.x);
	vec2 ca = vec2(p.x - min(p.x, (p.y < 0.0) ? r1 : r2), abs(p.y) - he);
	vec2 cb = p - k1 + k2 * clamp(dot(k1 - p, k2) / dot(k2, k2), 0.0, 1.0);
	float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
	return s * sqrt(min(dot(ca, ca), dot(cb, cb)));
}

float smooth_union(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

// Standing figure, metres: head, neck, shoulders, torso, hanging arms, legs.
float figure(vec2 p) {
	vec2 side = vec2(abs(p.x), p.y);
	float head = (length((p - vec2(0.0, 1.63)) / vec2(0.1, 0.12)) - 1.0) * 0.1;
	float neck = capsule(p, vec2(0.0, 1.44), vec2(0.0, 1.53), 0.055);
	float torso = trapezoid(p - vec2(0.0, 1.12), 0.16, 0.18, 0.26) - 0.04;
	float shoulders = capsule(side, vec2(0.0, 1.37), vec2(0.17, 1.35), 0.065);
	float arm = capsule(side, vec2(0.215, 1.32), vec2(0.24, 0.8), 0.05);
	float leg = capsule(side, vec2(0.08, 0.86), vec2(0.095, 0.05), 0.07);
	float d = smooth_union(torso, shoulders, 0.08);
	d = smooth_union(d, neck, 0.05);
	d = smooth_union(d, head, 0.03);
	d = smooth_union(d, arm, 0.04);
	d = smooth_union(d, leg, 0.07);
	return d;
}

void vertex() {
	body = vec2((UV.x - 0.5) * size.x, (1.0 - UV.y) * size.y);
	// Turn to the camera around Y, keeping the node's scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float t = TIME + seed * 17.0;
	vec2 drift = vec2(0.0, -t * rise_speed);
	float n = fbm(body * vec2(9.0, 6.0) + drift + seed);
	// Breathing: the figure swells and shrinks a little, slowly.
	float d = figure(body) - breath * sin(t * 1.1) + (n - 0.5) * 2.0 * edge_noise;
	float core = 1.0 - smoothstep(-edge_soft, edge_soft, d);
	// Smoke around the contour, thinning out away from it and rising.
	float wisp = fbm(body * vec2(5.0, 3.0) + drift * 1.6 + 3.1);
	float halo = exp(-max(d, 0.0) / haze_reach) * haze * smoothstep(0.35, 0.75, wisp);
	// Interference: rare short dips and a faint tremor.
	float tick = hash(vec2(floor(t * 14.0), seed));
	float flick = 1.0 - flicker * (step(0.9, tick) * 0.8 + 0.2 * (0.5 + 0.5 * sin(t * 23.0)));
	ALBEDO = tint.rgb;
	ALPHA = clamp(max(core, halo) * opacity * flick, 0.0, 1.0);
}
