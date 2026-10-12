shader_type canvas_item;

// Full-screen state effects (#134): blur, darkening, colour tint, vignette and flash.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur : hint_range(0.0, 1.0) = 0.0;
uniform float darken : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(0.4, 0.9, 0.5, 1.0);
uniform float tint : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

const float MAX_LOD = 5.0;

void fragment() {
	vec3 color = textureLod(screen_texture, SCREEN_UV, blur * MAX_LOD).rgb;
	color = mix(color, color * tint_color.rgb + tint_color.rgb * 0.15, tint);
	float edge = smoothstep(0.25, 0.85, distance(SCREEN_UV, vec2(0.5)) * 1.3);
	color = mix(color, vignette_color.rgb, edge * vignette);
	color *= 1.0 - darken;
	color = mix(color, vec3(1.0), flash);
	COLOR = vec4(color, 1.0);
}
