// DT-12, the shadow guard of Bowser's dream (docs/art/dream-bowser-s.md §3, Д-2): an almost black
// body (#120d10) whose rim smokes: a fresnel glow of lilac smoke drifting up and a noisy edge
// that thins into the air.
shader_type spatial;
render_mode depth_prepass_alpha, cull_back;

uniform vec3 body_color : source_color = vec3(0.071, 0.051, 0.063);
uniform vec3 smoke_color : source_color = vec3(0.34, 0.22, 0.4);
uniform float smoke_energy = 1.4;
uniform float rim_power = 2.2;
uniform float smoke_scale = 2.6;
uniform float smoke_speed = 0.5;
uniform float edge_fade = 0.75;

varying vec3 world_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	vec3 p = world_pos * smoke_scale + vec3(0.0, -TIME * smoke_speed, 0.0);
	float smoke = noise(p) * 0.65 + noise(p * 2.3) * 0.35;
	ALBEDO = body_color;
	ROUGHNESS = 0.92;
	EMISSION = smoke_color * smoke_energy * rim * (0.35 + 0.65 * smoke);
	ALPHA = 1.0 - rim * edge_fade * smoothstep(0.35, 0.75, smoke);
}
