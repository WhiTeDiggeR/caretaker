shader_type sky;

// Sky of Bowser's dream (ПР-11, Д-6; docs/art/dream-bowser-s.md §2, §4.4): gradient of the
// sleep stage, two drifting layers of smoke clouds, a far volcano on the horizon and the glow of
// the lava from below. `stage` 0–3 (calm / alarm / unrest / pre-wake) blends the four palettes;
// DreamStageMood fills the palettes (linear colours) and moves `stage` smoothly.
// No white here: white light belongs to the seal, the gate, the chain and the operator's trace.

uniform vec3 top_colors[4];
uniform vec3 horizon_colors[4];
uniform vec3 lava_colors[4];
uniform float stage : hint_range(0.0, 3.0) = 1.0;
uniform vec3 smoke_color = vec3(0.035, 0.018, 0.022);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.55;
uniform vec2 cloud_drift = vec2(0.006, 0.002); // per second, upper layer; the lower one is faster
uniform float volcano_azimuth = 2.4; // radians around +Y, where the far volcano stands
uniform float volcano_width = 0.35; // radians at the foot
uniform float volcano_height = 0.11; // sine of the elevation of the summit
uniform float lava_glow = 0.6;

vec3 palette(vec3 colors[4], float s) {
	float a = clamp(floor(s), 0.0, 3.0);
	float b = min(a + 1.0, 3.0);
	return mix(colors[int(a)], colors[int(b)], s - a);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += noise(p) * amp;
		p = p * 2.03 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return sum;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;
	vec3 top = palette(top_colors, stage);
	vec3 horizon = palette(horizon_colors, stage);
	vec3 lava = palette(lava_colors, stage);

	float t = pow(clamp(up, 0.0, 1.0), 0.45);
	vec3 color = mix(horizon, top, t);
	// Below the horizon: the lava sea glows into the haze.
	float below = clamp(-up * 4.0, 0.0, 1.0);
	color = mix(color, horizon * 0.35 + lava * 0.08, below);
	color += lava * lava_glow * exp(-abs(up) * 18.0) * 0.12;

	// Smoke clouds: projected on a dome, two layers; thicker as the sleep gets restless.
	if (up > -0.02) {
		vec2 dome = dir.xz / (up + 0.18);
		float cover = cloud_cover + stage * 0.08;
		float upper = fbm(dome * 0.9 + cloud_drift * TIME);
		float lower = fbm(dome * 1.7 - cloud_drift.yx * TIME * 2.3 + vec2(4.0, 1.0));
		float smoke = smoothstep(1.0 - cover, 1.15 - cover * 0.6, upper * 0.6 + lower * 0.5);
		float fade = smoothstep(-0.02, 0.12, up);
		// Undersides catch the lava light near the horizon.
		vec3 cloud = mix(smoke_color, horizon * 0.6 + lava * 0.05, exp(-up * 6.0) * 0.6);
		color = mix(color, cloud, smoke * fade * 0.85);
	}

	// Far volcano: a dark cone on the horizon with a glowing crater and a column of smoke.
	float azimuth = atan(dir.x, dir.z);
	float off = abs(mod(azimuth - volcano_azimuth + PI, TAU) - PI);
	float slope = volcano_height * (1.0 - off / volcano_width);
	float ridge = slope + (noise(vec2(azimuth * 40.0, 0.0)) - 0.5) * 0.006;
	if (off < volcano_width && up > -0.02 && up < ridge) {
		color = mix(horizon * 0.18, smoke_color, 0.5);
		float crater = smoothstep(0.012, 0.0, ridge - up) * smoothstep(volcano_width * 0.18, 0.0, off);
		color += lava * crater * 0.6;
	}
	float plume_off = off + (fbm(vec2(up * 6.0, TIME * 0.05)) - 0.5) * up * 0.6;
	float plume = smoothstep(0.08 + up * 0.4, 0.0, plume_off) * smoothstep(volcano_height * 0.9, volcano_height * 1.6, up) * smoothstep(0.75, 0.2, up);
	color = mix(color, smoke_color * 1.4 + lava * 0.02 * (1.0 - up), plume * 0.8);

	COLOR = color;
}
