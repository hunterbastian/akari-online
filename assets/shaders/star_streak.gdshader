shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, shadows_disabled, fog_disabled;

// Boost streaks. A few hash taps along the travel axis, quantized so they stay on the pixel grid.
// Idle stays invisible. The environment sky is left alone so the radiance map is not rebuilt.

uniform float streak = 0.0;
uniform vec3 travel_dir = vec3(0.0, 0.0, -1.0);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec3 dir = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 0.0)).xyz);
	vec3 axis = normalize(travel_dir);
	float reach = streak * 8.0;
	float hop = 0.02 + streak * 0.11;
	float acc = 0.0;
	float fade = 1.0;
	vec3 p = dir;
	for (int i = 0; i < 8; i++) {
		float live = step(float(i), reach);
		vec3 cell = floor(normalize(p) * 180.0);
		float star = step(0.988, hash13(cell));
		float grain = hash13(cell + vec3(float(i) + 3.0, 1.7, 9.0));
		star *= step(0.12, grain);
		acc = max(acc, star * fade * live);
		p = normalize(mix(p, axis, hop));
		fade *= 0.78;
	}
	float on = step(0.02, streak);
	ALBEDO = vec3(0.82, 0.9, 1.0) * acc;
	ALPHA = acc * min(streak * 1.6, 1.0) * on;
}
