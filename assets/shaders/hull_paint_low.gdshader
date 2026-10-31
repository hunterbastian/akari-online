shader_type spatial;

// Cheap white paint for the mobile / low quality setting. No clearcoat lobe.

uniform vec4 paint_color : source_color = vec4(0.78, 0.77, 0.74, 1.0);
uniform float roughness_base = 0.4;
uniform float metallic_base = 0.04;
uniform float clearcoat_amount = 0.0;
uniform float clearcoat_gloss = 0.08;
uniform float dither_strength = 0.014;
uniform float panel_shift = 0.0;
uniform vec3 bounce_dir = vec3(0.0, -1.0, 0.0);
uniform vec4 bounce_color : source_color = vec4(0.42, 0.64, 0.95, 1.0);
uniform float bounce_strength = 0.16;

const mat4 BAYER = mat4(
	vec4(0.0, 12.0, 3.0, 15.0),
	vec4(8.0, 4.0, 11.0, 7.0),
	vec4(2.0, 14.0, 1.0, 13.0),
	vec4(10.0, 6.0, 9.0, 5.0)
) / 16.0;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float n00 = mix(hash13(cell), hash13(cell + vec3(1.0, 0.0, 0.0)), blend.x);
	float n10 = mix(hash13(cell + vec3(0.0, 1.0, 0.0)), hash13(cell + vec3(1.0, 1.0, 0.0)), blend.x);
	float n01 = mix(hash13(cell + vec3(0.0, 0.0, 1.0)), hash13(cell + vec3(1.0, 0.0,1.0)), blend.x);
	float n11 = mix(hash13(cell + vec3(0.0, 1.0, 1.0)), hash13(cell + vec3(1.0, 1.0, 1.0)), blend.x);
	return mix(mix(n00, n10, blend.y), mix(n01, n11, blend.y), blend.z);
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_normal = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
	float speckle = value_noise(world * 4.0 + vec3(panel_shift, 0.0, 0.0));
	float curve = clamp(length(fwidth(NORMAL)) * 5.0, 0.0, 1.0);

	vec3 albedo = paint_color.rgb * mix(0.97, 1.03, speckle);
	vec3 edge = paint_color.rgb * vec3(0.8, 0.84, 0.9);
	albedo = mix(albedo, edge, curve * 0.35);

	ivec2 pixel = ivec2(floor(FRAGCOORD.xy));
	float bayer = BAYER[pixel.x & 3][pixel.y & 3];
	albedo += (bayer - 0.5) * dither_strength;

	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	albedo += vec3(0.75, 0.84, 1.0) * fresnel * 0.05;
	ALBEDO = max(albedo, vec3(0.0));
	ROUGHNESS = clamp(roughness_base - curve * 0.12, 0.2, 0.75);
	METALLIC = mix(metallic_base, 0.45, curve * 0.7);
	SPECULAR = mix(0.5, 0.7, curve);
	RIM = 0.18 + fresnel * 0.22;

	float under = clamp(dot(world_normal, bounce_dir), 0.0, 1.0);
	EMISSION = bounce_color.rgb * under * under * bounce_strength;
}
