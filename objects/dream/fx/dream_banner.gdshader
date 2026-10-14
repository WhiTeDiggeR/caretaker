// Д-01, a banner of Bowser's dream (ПР-12; docs/art/dream-bowser-s.md §4): DT-09 dark cloth
// with a spiked hem band and the emblem by Д-7 б — a direct nod to the recognisable horned
// face emblem, drawn here in signed distances (no downloaded logos). The hem is cut to a point
// and the cloth sways in the wind, more towards the bottom. No white (Б-5): the eyes are amber.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec2 size = vec2(2.0, 6.0); // metres, the QuadMesh size
uniform vec3 cloth_color : source_color = vec3(0.36, 0.07, 0.07);
uniform vec3 band_color : source_color = vec3(0.06, 0.05, 0.05);
uniform vec3 disc_color : source_color = vec3(0.12, 0.24, 0.10);
uniform vec3 emblem_color : source_color = vec3(0.92, 0.48, 0.10);
uniform vec3 horn_color : source_color = vec3(0.88, 0.80, 0.62);
uniform vec3 eye_color : source_color = vec3(1.0, 0.72, 0.18);
uniform float emblem_y = 1.7; // centre of the emblem below the top edge, metres
uniform float emblem_radius = 0.82;
uniform float eye_glow = 0.6;
uniform float wind_amplitude = 0.12;
uniform float wind_speed = 1.3;
uniform float hem_depth = 0.6;

float sd_circle(vec2 p, float r) { return length(p) - r; }

float sd_ellipse(vec2 p, vec2 r) { return (length(p / r) - 1.0) * min(r.x, r.y); }

float sd_triangle(vec2 p, vec2 a, vec2 b, vec2 c) {
	vec2 e0 = b - a, e1 = c - b, e2 = a - c;
	vec2 v0 = p - a, v1 = p - b, v2 = p - c;
	vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float s = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
			vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
			vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
	return -sqrt(d.x) * sign(d.y);
}

float fill(float d) { return 1.0 - smoothstep(-0.006, 0.006, d); }

void vertex() {
	float down = UV.y; // 0 at the pole, 1 at the hem
	float sway = sin(TIME * wind_speed + down * 3.0 + NODE_POSITION_WORLD.x * 0.7)
			+ 0.4 * sin(TIME * wind_speed * 2.3 + UV.x * 4.0);
	VERTEX.z += sway * wind_amplitude * pow(down, 1.5);
	VERTEX.x += sin(TIME * wind_speed * 0.6 + down * 2.0) * wind_amplitude * 0.3 * down;
}

void fragment() {
	// p: metres from the emblem centre, x to the right, y downwards.
	vec2 m = vec2((UV.x - 0.5) * size.x, UV.y * size.y);
	// Hem cut to a point.
	if (m.y > size.y - hem_depth * abs(UV.x - 0.5) * 2.0) {
		discard;
	}
	vec3 color = cloth_color;
	// Dark bands: the top band with a row of spikes and the side edges.
	float top_band = step(m.y, 0.35);
	float spikes = fill(sd_triangle(vec2(mod(m.x + 1.0, 0.25) - 0.125, m.y - 0.35),
			vec2(-0.1, 0.0), vec2(0.1, 0.0), vec2(0.0, 0.22)));
	float sides = step(size.x * 0.5 - 0.1, abs(m.x));
	color = mix(color, band_color, max(max(top_band, spikes), sides));
	float bottom_band = step(size.y - hem_depth - 0.45, m.y) * step(m.y, size.y - hem_depth - 0.25);
	color = mix(color, band_color, bottom_band);

	vec2 p = m - vec2(0.0, emblem_y);
	float r = emblem_radius;
	vec3 emission = vec3(0.0);
	// Disc and its orange ring.
	color = mix(color, disc_color, fill(sd_circle(p, r)));
	color = mix(color, emblem_color, fill(abs(sd_circle(p, r)) - 0.05));
	// Spikes on the ring.
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7853982 + 0.3926991;
		vec2 dir = vec2(cos(a), sin(a));
		vec2 side = vec2(-dir.y, dir.x);
		color = mix(color, emblem_color, fill(sd_triangle(p,
				dir * (r + 0.02) + side * 0.09, dir * (r + 0.02) - side * 0.09, dir * (r + 0.22))));
	}
	// Horns: two curved blades rising from the temples.
	float horns = min(
			sd_triangle(vec2(abs(p.x), p.y), vec2(0.18, -0.30), vec2(0.40, -0.18), vec2(0.52, -0.72)),
			sd_triangle(vec2(abs(p.x), p.y), vec2(0.40, -0.18), vec2(0.52, -0.72), vec2(0.58, -0.35)));
	color = mix(color, horn_color, fill(horns));
	// Head and the wide jaw, the flame of the mane on top.
	float head = min(sd_ellipse(p - vec2(0.0, 0.0), vec2(0.42, 0.38)), sd_ellipse(p - vec2(0.0, 0.24), vec2(0.5, 0.26)));
	float mane = 1e3;
	for (int i = 0; i < 3; i++) {
		float x = (float(i) - 1.0) * 0.16;
		mane = min(mane, sd_triangle(p, vec2(x - 0.12, -0.26), vec2(x + 0.12, -0.26), vec2(x * 1.3, -0.58 - 0.06 * float(1 - abs(i - 1)))));
	}
	color = mix(color, emblem_color * vec3(1.0, 0.55, 0.4), fill(mane));
	color = mix(color, emblem_color, fill(head));
	// Angry brows, glaring eyes, the snout and the fanged grin.
	float brows = sd_triangle(vec2(abs(p.x), p.y), vec2(0.05, -0.08), vec2(0.36, -0.20), vec2(0.34, -0.08));
	color = mix(color, band_color, fill(brows));
	float eyes = sd_ellipse(vec2(abs(p.x), p.y) - vec2(0.19, -0.02), vec2(0.075, 0.05));
	color = mix(color, eye_color, fill(eyes));
	emission += eye_color * eye_glow * fill(eyes);
	float pupils = sd_ellipse(vec2(abs(p.x), p.y) - vec2(0.17, -0.02), vec2(0.02, 0.045));
	color = mix(color, band_color, fill(pupils));
	float nostrils = sd_circle(vec2(abs(p.x), p.y) - vec2(0.07, 0.12), 0.025);
	color = mix(color, band_color, fill(nostrils));
	float mouth = sd_ellipse(p - vec2(0.0, 0.3), vec2(0.36, 0.09));
	color = mix(color, band_color, fill(mouth));
	float fangs = min(
			sd_triangle(vec2(abs(p.x), p.y), vec2(0.12, 0.22), vec2(0.22, 0.22), vec2(0.17, 0.33)),
			sd_triangle(vec2(abs(p.x), p.y), vec2(0.0, 0.38), vec2(0.08, 0.38), vec2(0.04, 0.28)));
	color = mix(color, horn_color, fill(fangs));

	ALBEDO = color;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
	EMISSION = emission;
}
