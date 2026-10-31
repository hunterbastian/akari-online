shader_type spatial;

// Grated cabin floor. The normal map is a tiny generated grate; Bayer stays on
// the 0.7-scale viewport pixels, same as the hull paint.

uniform vec4 paint_color : source_color = vec4(0.22, 0.23, 0.25, 1.0);
uniform sampler2D normal_tex : repeat_enable, filter_linear;
uniform float roughness_base = 0.62;
uniform float metallic_base = 0.55;
uniform float dither_strength = 0.012;
uniform vec3 bounce_dir = vec3(0.0, -1.0, 0.0);
uniform float bounce_strength = 0.12;
uniform vec4 bounce_color : source_color = vec4(0.42, 0.64, 0.95, 1.0);

const mat4 BAYER = mat4(
	vec4(0.0, 12.0, 3.0, 15.0),
	vec4(8.0, 4.0, 11.0, 7.0),
	vec4(2.0, 14.0, 1.0, 13.0),
	vec4(10.0, 6.0, 9.0, 5.0)
) / 16.0;

void fragment() {
	NORMAL_MAP = texture(normal_tex, UV * vec2(10.0, 16.0)).rgb;
	NORMAL_MAP_DEPTH = 0.45;
	vec3 albedo = paint_color.rgb;
	float seam = smoothstep(0.42, 0.5, abs(fract(UV.x * 10.0) - 0.5));
	seam = max(seam, smoothstep(0.42, 0.5, abs(fract(UV.y * 16.0) - 0.5)));
	albedo *= mix(0.55, 1.0, seam);
	ivec2 pixel = ivec2(floor(FRAGCOORD.xy));
	float bayer = BAYER[pixel.x & 3][pixel.y & 3];
	albedo += (bayer - 0.5) * dither_strength;
	ALBEDO = max(albedo, vec3(0.0));
	ROUGHNESS = roughness_base;
	METALLIC = metallic_base;
	vec3 world_normal = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
	float under = clamp(dot(world_normal, bounce_dir), 0.0, 1.0);
	EMISSION = bounce_color.rgb * under * under * bounce_strength;
}
