shader_type spatial;
render_mode cull_back, depth_draw_opaque, shadows_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D metallic_texture : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;

uniform vec2 tiling = vec2(2.0, 2.0);
uniform float metallic = 0.0;
uniform float roughness = 0.85;
uniform float normal_scale = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 sample_triplanar(sampler2D tex, vec3 pos, vec3 blend) {
    vec2 uvx = pos.zy * tiling;
    vec2 uvy = pos.xz * tiling;
    vec2 uvz = pos.xy * tiling;

    vec4 x = texture(tex, uvx);
    vec4 y = texture(tex, uvy);
    vec4 z = texture(tex, uvz);

    return x * blend.x + y * blend.y + z * blend.z;
}

void fragment() {
    vec3 blend = abs(world_normal);
    blend = normalize(max(blend, vec3(0.00001)));
    float sum = blend.x + blend.y + blend.z;
    blend /= vec3(sum);

    vec4 albedo_sample = sample_triplanar(albedo_texture, world_pos, blend);
    vec4 metallic_sample = sample_triplanar(metallic_texture, world_pos, blend);
    vec4 roughness_sample = sample_triplanar(roughness_texture, world_pos, blend);
    vec4 normal_sample = sample_triplanar(normal_texture, world_pos, blend);

    ALBEDO = albedo_sample.rgb;
    METALLIC = metallic * metallic_sample.r;
    ROUGHNESS = clamp(roughness * roughness_sample.r, 0.0, 1.0);
    NORMAL_MAP = normal_sample.rgb;
    NORMAL_MAP_DEPTH = normal_scale;
}
