shader_type canvas_item;

// Backdrop of variant B «Кристалл» (issue #144): the crystal of the immersion device breathes
// in the dark. Used by the splash before the menu and by the loading screen.

uniform vec4 glow : source_color = vec4(0.88, 0.96, 1.0, 1.0);
uniform vec4 deep : source_color = vec4(0.02, 0.027, 0.04, 1.0);
uniform vec2 centre = vec2(0.5, 0.4);
uniform float aspect = 1.777;
uniform float breath_seconds = 6.0;

void fragment() {
	vec2 p = (UV - centre) * vec2(aspect, 1.0);
	float d = length(p);
	float breath = 0.5 + 0.5 * sin(TIME * 6.2831853 / breath_seconds);
	float scale = mix(0.94, 1.06, breath);
	float core = exp(-pow(d / (0.05 * scale), 2.0));
	float halo = exp(-pow(d / (0.28 * scale), 2.0)) * mix(0.18, 0.3, breath);
	float haze = exp(-pow(d / (0.7 * scale), 2.0)) * 0.08;
	vec3 col = deep.rgb + glow.rgb * (core * 0.55 + halo + haze);
	vec2 v = UV - 0.5;
	col *= 1.0 - dot(v, v) * 1.4;
	COLOR = vec4(col, 1.0);
}
