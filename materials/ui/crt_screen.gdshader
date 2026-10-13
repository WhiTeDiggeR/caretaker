shader_type canvas_item;

// Picture of a world screen (issue #145, docs/ui/style-guide.md): phosphor bloom,
// scanlines, vignette, a rolling band, an LCD pixel grid, jitter, flicker on emergency
// power and the colour split of Herobrine's interference (#149). Drawn as an overlay over
// the screen panel; reads what is already on screen.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float scanlines : hint_range(0.0, 1.0) = 0.3;
uniform float scanline_count = 300.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.5;
uniform float bloom : hint_range(0.0, 2.0) = 0.5;
uniform float roll : hint_range(0.0, 1.0) = 0.0;
uniform float pixel_grid : hint_range(0.0, 1.0) = 0.0;
uniform float grid_cells = 420.0;
uniform float jitter : hint_range(0.0, 1.0) = 0.0;
uniform float flicker : hint_range(0.0, 1.0) = 0.0;
uniform float split : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 suv = SCREEN_UV;
	// Rare horizontal jitter of the whole picture (interference).
	float slot = floor(TIME * 7.0);
	float shake = step(0.92, hash(slot)) * jitter;
	suv.x += (hash(slot + 3.1) - 0.5) * 0.006 * shake;

	vec3 col = texture(screen_texture, suv).rgb;
	if (split > 0.0) {
		float offset = split * 0.004 * (0.6 + 0.4 * sin(TIME * 2.3));
		col.r = texture(screen_texture, suv + vec2(offset, 0.0)).r;
		col.b = texture(screen_texture, suv - vec2(offset, 0.0)).b;
	}
	vec3 halo = textureLod(screen_texture, suv, 3.0).rgb;
	col += halo * bloom;

	float lines = 0.5 + 0.5 * sin(UV.y * scanline_count * 6.2831853);
	col *= 1.0 - scanlines * (1.0 - lines);

	vec2 cell = fract(UV * vec2(grid_cells, grid_cells * 0.5625));
	float grid = step(0.82, cell.x) + step(0.82, cell.y);
	col *= 1.0 - pixel_grid * 0.35 * clamp(grid, 0.0, 1.0);

	float band = fract(TIME * 0.09);
	float band_light = smoothstep(0.09, 0.0, abs(UV.y - band));
	col += tint.rgb * roll * band_light * 0.07;

	vec2 centred = UV - 0.5;
	col *= 1.0 - vignette * dot(centred, centred) * 2.2;

	float pulse = 0.5 + 0.5 * sin(TIME * 47.0) * sin(TIME * 3.3);
	col *= 1.0 - flicker * 0.18 * pulse;

	COLOR = vec4(col, 1.0);
}
