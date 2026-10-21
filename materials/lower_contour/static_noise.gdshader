shader_type spatial;
render_mode unshaded, cull_back;

// Interference of the early dream lab (#229): the screens and the opaque capsule glass of post 2
// show only coarse static with a slow rolling band; nothing behind it can be made out.

uniform vec4 tint : source_color = vec4(0.62, 0.72, 0.66, 1.0);
uniform float brightness = 0.7;
uniform vec2 grain = vec2(160.0, 96.0);
uniform float frame_rate = 18.0;
uniform float roll_speed = 0.12;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float frame = floor(TIME * frame_rate);
	float n = hash(floor(UV * grain) + frame * 1.618);
	float band = smoothstep(0.0, 0.12, abs(fract(UV.y + TIME * roll_speed) - 0.5) - 0.04);
	ALBEDO = tint.rgb * mix(n * 1.4, n * 0.55, band) * brightness;
}
