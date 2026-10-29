shader_type sky;

uniform vec3 sun_dir = vec3(0.48, 0.79, 0.31);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 2.4);
		a *= 0.5;
	}
	return s;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 base = vec3(0.004, 0.006, 0.016);

	float far_n = fbm(dir * 1.35 + vec3(2.2, 0.4, 1.1));
	float mid_n = fbm(dir * 2.8 + far_n * 0.55 + vec3(7.0, 1.4, 3.2));
	float near_n = fbm(dir * 5.4 + mid_n * 0.35 + vec3(0.6, 4.8, 8.1));

	vec3 indigo = vec3(0.05, 0.06, 0.13);
	vec3 teal = vec3(0.03, 0.11, 0.15);
	vec3 violet = vec3(0.08, 0.05, 0.12);
	float far_mask = smoothstep(0.46, 0.76, far_n);
	float mid_mask = smoothstep(0.52, 0.82, mid_n);
	float near_mask = smoothstep(0.58, 0.86, near_n);
	vec3 col = base;
	col = mix(col, indigo, far_mask * 0.36);
	col = mix(col, teal, mid_mask * 0.26);
	col = mix(col, violet, near_mask * 0.16);
	float filament = smoothstep(0.66, 0.84, fbm(dir * 8.0 + vec3(4.0, 2.0, 9.0)));
	col += vec3(0.12, 0.08, 0.05) * filament * 0.05;

	vec3 cell_a = floor(dir * 720.0);
	vec3 cell_b = floor(dir * 340.0 + 17.0);
	float h1 = hash13(cell_a);
	float h2 = hash13(cell_b);
	float dim = step(0.9988, h1) * (0.22 + 0.4 * hash13(cell_a + 3.1));
	float bright = step(0.9982, h2) * (1.05 + 0.55 * hash13(cell_b + 1.7));
	col += vec3(0.72, 0.8, 0.95) * dim;
	col += vec3(0.92, 0.94, 1.0) * bright;

	vec3 sun = normalize(sun_dir);
	float mu = max(dot(dir, sun), 0.0);
	float corona = pow(mu, 64.0);
	float wide = pow(mu, 18.0);
	col += vec3(0.42, 0.58, 0.82) * corona * 0.22;
	col += vec3(0.05, 0.08, 0.14) * wide * 0.04;

	COLOR = col;
}
