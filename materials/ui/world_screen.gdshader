shader_type spatial;

// Screen of the complex on a model (issue #146, docs/ui/style-guide.md): the SubViewport
// picture glows through scanlines (CRT eras) or a pixel grid (late screens) under a
// vignette; switched off it is dark reflective glass.

uniform sampler2D picture : source_color, filter_linear;
uniform bool powered = true;
uniform float emission_energy = 1.6;
uniform vec4 glass : source_color = vec4(0.03, 0.035, 0.04, 1.0);
uniform float scanlines : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_count = 270.0;
uniform float pixel_grid : hint_range(0.0, 1.0) = 0.0;
uniform vec2 grid_cells = vec2(480.0, 270.0);
uniform float vignette : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	ALBEDO = glass.rgb * 0.25;
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	if (powered) {
		vec3 col = texture(picture, UV).rgb;
		// Lines and cells finer than a pixel would alias into moire: fade them out by distance.
		float line_px = fwidth(UV.y * scanline_count);
		float lines = 0.5 + 0.5 * sin(UV.y * scanline_count * 6.2831853);
		col *= 1.0 - scanlines * (1.0 - lines) * (1.0 - smoothstep(0.25, 0.5, line_px));
		vec2 cell = fract(UV * grid_cells);
		float cell_px = max(fwidth(UV.x * grid_cells.x), fwidth(UV.y * grid_cells.y));
		float grid = clamp(step(0.8, cell.x) + step(0.8, cell.y), 0.0, 1.0);
		col *= 1.0 - pixel_grid * 0.4 * grid * (1.0 - smoothstep(0.25, 0.5, cell_px));
		vec2 centred = UV - 0.5;
		col *= 1.0 - vignette * dot(centred, centred) * 2.2;
		ALBEDO = col * 0.15;
		EMISSION = col * emission_energy;
	}
}
