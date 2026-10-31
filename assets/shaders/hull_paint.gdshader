shader_type spatial;

// White jumpship paint. Forward+ gets a clearcoat lobe; the low shader omits it.
// Bayer dither is in viewport pixels, which are already the 0.7 render-scale grid.

uniform vec4 paint_color : source_color = vec4(0.78, 0.77, 0.74, 1.0);
uniform float roughness_base = 0.36;
uniform float metallic_base = 0.06;
uniform float clearcoat_amount = 0.82;
uniform float clearcoat_gloss = 0.07;
uniform float dither_strength = 0.016;
uniform float panel_shift = 0.0;
uniform vec3 bounce_dir = vec3(0.0, -1.0, 0.0);
uniform vec4 bounce_color : source_color = vec4(0.42, 0.64, 0.95, 1.0);
uniform float bounce_strength = 0.18;

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
	float n01 = mix(hash13(cell + vec3(0.0, 0.0, 1.0)), hash13(cell + vec3(1.0, 0.0, 1.0)), blend.x);
	float n11 = mix(hash13(cell + vec3(0.0, 1.0, 1.0)), hash13(cell + vec3(1.0, 1.0, 1.0)), blend.x);
	return mix(mix(n00, n10, blend.y), mix(n01, n11, blend.y), blend.z);
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_normal = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
	float speckle = value_noise(world * 5.2 + vec3(panel_shift, 0.0, 0.0));
	float broad = value_noise(world * 1.6 + vec3(panel_shift * 2.0, 3.0, 1.0));
	float curve = clamp(length(fwidth(NORMAL)) * 5.5, 0.0, 1.0);

	vec3 albedo = paint_color.rgb;
	albedo *= mix(0.955, 1.035, broad);
	albedo *= mix(0.985, 1.015, speckle);
	// Worn edges catch a cooler, slightly metallic glint.
	vec3 edge = paint_color.rgb * vec3(0.78, 0.82, 0.9);
	albedo = mix(albedo, edge, curve * 0.45);

	ivec2 pixel = ivec2(floor(FRAGCOORD.xy));
	float bayer = BAYER[pixel.x & 3][pixel.y & 3];
	albedo += (bayer - 0.5) * dither_strength;

	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	albedo += vec3(0.75, 0.84, 1.0) * fresnel * 0.07;
	ALBEDO = max(albedo, vec3(0.0));
	ROUGHNESS = clamp(roughness_base + (speckle - 0.5) * 0.08 - curve * 0.16 + (bayer - 0.5) * 0.02, 0.14, 0.72);
	METALLIC = mix(metallic_base, 0.62, curve * 0.85);
	SPECULAR = mix(0.55, 0.82, curve);
	CLEARCOAT = clearcoat_amount * (1.0 - curve * 0.2);
	CLEARCOAT_ROUGHNESS = clearcoat_gloss + speckle * 0.035;
	RIM = 0.22 + fresnel * 0.35;

	float under = clamp(dot(world_normal, bounce_dir), 0.0, 1.0);
	EMISSION = bounce_color.rgb * under * under * bounce_strength;
}
