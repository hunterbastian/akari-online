shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.843, 0.827, 0.796, 1.0);
uniform float roughness_base = 0.78;
uniform float metallic_base = 0.14;

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
	float speckle = value_noise(world * 9.5);
	float broad = value_noise(world * 2.4 + vec3(4.0, 1.0, 7.0));
	float curve = clamp(length(fwidth(NORMAL)) * 5.5, 0.0, 1.0);
	float chip = max(smoothstep(0.78, 0.96, speckle) * 0.42, curve * 0.55);
	vec3 worn = base_color.rgb * vec3(0.62, 0.64, 0.68);
	ALBEDO = mix(base_color.rgb, worn, chip);
	ALBEDO *= mix(0.96, 1.04, broad);
	ROUGHNESS = clamp(roughness_base + (speckle - 0.5) * 0.14 - chip * 0.2, 0.46, 0.92);
	METALLIC = mix(metallic_base, 0.34, chip);
}
