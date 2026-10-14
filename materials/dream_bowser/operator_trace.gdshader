// Н-05, the trace of the operator's death past the wake line (Д-5): a glass crack in the stone
// that flickers dimly white. Vertex colour red marks the crack lines (full glow) and the chips.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 glass_color : source_color = vec3(0.05, 0.06, 0.07);
uniform vec3 glow_color : source_color = vec3(0.93, 0.96, 1.0);
uniform float glow_energy = 0.45;
uniform float flicker_speed = 0.7;

void fragment() {
	float t = TIME * flicker_speed * 6.2831853;
	float flicker = 0.55 + 0.25 * sin(t) + 0.2 * sin(t * 2.7 + 1.3);
	ALBEDO = glass_color;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	EMISSION = glow_color * glow_energy * flicker * COLOR.r;
}
