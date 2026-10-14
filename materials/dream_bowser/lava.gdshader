// Lava of Bowser's dream (DT-04, docs/art/dream-bowser-s.md §2-§3): crust plates over a molten flow.
// Stage presets (calm / alarm / unrest / pre-wake) set glow_color, emission_energy, pulse_hz and level_offset;
// the defaults are the alarm stage. UVs are world-space, so the plane can be resized without stretching.
shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D heat_texture : hint_default_black, filter_linear_mipmap, repeat_enable;

uniform float tile_metres = 8.0;
uniform vec2 crust_drift = vec2(0.012, 0.004); // tiles per second
uniform vec2 flow_speed = vec2(-0.03, 0.018); // second, faster molten layer under the crust
uniform vec4 glow_color : source_color = vec4(1.0, 0.416, 0.102, 1.0); // #ff6a1a
uniform float emission_energy = 2.6;
uniform float pulse_hz = 0.0; // 0.6 at the pre-wake stage
uniform float pulse_amount = 0.25;
uniform float level_offset = 0.0; // metres the surface rises per stage: 0, 0.5, 1.0, 1.5
uniform float swell_height = 0.06;

varying vec2 world_uv;

void vertex() {
	VERTEX.y += level_offset;
	world_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz / tile_metres;
	VERTEX.y += sin(world_uv.x * 9.0 + TIME * 0.7) * cos(world_uv.y * 7.0 + TIME * 0.5) * swell_height;
}

void fragment() {
	vec2 crust_uv = world_uv + crust_drift * TIME;
	vec2 flow_uv = world_uv * 1.7 + flow_speed * TIME;
	vec4 orm = texture(orm_texture, crust_uv);
	float heat = texture(heat_texture, crust_uv).r;
	float flow = texture(heat_texture, flow_uv).r;
	float pulse = 1.0 + sin(TIME * TAU * pulse_hz) * pulse_amount * step(0.001, pulse_hz);
	float glow = clamp(heat * (0.65 + 0.35 * flow) + flow * 0.12, 0.0, 1.0);
	ALBEDO = texture(albedo_texture, crust_uv).rgb * (1.0 - glow * 0.5);
	ROUGHNESS = orm.g;
	METALLIC = 0.0;
	AO = orm.r;
	NORMAL_MAP = texture(normal_texture, crust_uv).rgb;
	EMISSION = glow_color.rgb * glow * emission_energy * pulse;
}
