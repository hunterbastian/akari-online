shader_type sky;

uniform vec3 top_color : source_color = vec3(0.102, 0.063, 0.157);
uniform vec3 mid_color : source_color = vec3(0.878, 0.416, 0.361);
uniform vec3 bottom_color : source_color = vec3(0.949, 0.765, 0.580);
uniform vec3 star_color : source_color = vec3(0.965, 0.945, 0.910);
uniform vec3 sun_dir = vec3(0.48, 0.79, 0.31);
uniform float yaw = 0.6;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec3 rotate_y(vec3 d, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(d.x * c - d.z * s, d.y, d.x * s + d.z * c);
}

void sky() {
	vec3 dir = normalize(rotate_y(EYEDIR, yaw));
	// Canvas gradient: top stop at the zenith, mid at 0.46, bottom at the nadir.
	float t = clamp((1.0 - dir.y) * 0.5, 0.0, 1.0);
	vec3 col = mix(top_color, mid_color, smoothstep(0.0, 0.46, t));
	col = mix(col, bottom_color, smoothstep(0.34, 1.0, t));

	vec3 lobe_a = normalize(vec3(0.55, 0.42, 0.72));
	vec3 lobe_b = normalize(vec3(-0.72, -0.15, 0.35));
	float lobe_a_amt = pow(max(dot(dir, lobe_a), 0.0), 4.0);
	float lobe_b_amt = pow(max(dot(dir, lobe_b), 0.0), 3.0);
	vec3 glow = mid_color * lobe_a_amt * 0.55 + bottom_color * lobe_b_amt * 0.40;
	col = vec3(1.0) - (vec3(1.0) - col) * (vec3(1.0) - glow);

	float cell = hash13(floor(dir * 260.0));
	float star = step(0.996, cell) * smoothstep(-0.05, 0.55, dir.y);
	col += star_color * star * 0.9;

	vec3 sun = normalize(sun_dir);
	float wide = pow(max(dot(dir, sun), 0.0), 8.0);
	col += star_color * wide * 0.22;

	COLOR = col;
}
