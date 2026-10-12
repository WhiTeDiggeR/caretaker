shader_type canvas_item;

// Edges of the frame in a dream (issue #149): the sleeper's colour closes in as the sleep
// grows unstable; an anomalous dream (Herobrine) also splits the colours of the picture.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec4 tint : source_color = vec4(0.16, 0.05, 0.02, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.3;
uniform float split : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;
	if (split > 0.0) {
		float offset = split * 0.006 * (0.6 + 0.4 * sin(TIME * 1.7));
		col.r = texture(screen_texture, SCREEN_UV + vec2(offset, 0.0)).r;
		col.b = texture(screen_texture, SCREEN_UV - vec2(offset, 0.0)).b;
	}
	vec2 centred = (SCREEN_UV - 0.5) * vec2(1.6, 1.0);
	float edge = smoothstep(0.35, 0.95, length(centred)) * strength;
	COLOR = vec4(mix(col, tint.rgb, edge), 1.0);
}
