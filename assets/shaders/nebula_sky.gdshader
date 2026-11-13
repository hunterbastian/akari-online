shader_type sky;

uniform vec3 sun_dir = vec3(0.48, 0.79, 0.31);
uniform vec3 up_dir = vec3(0.0, 1.0, 0.0);
uniform float ground_mix = 0.0;
uniform float cheap = 0.0;

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

vec3 air_sky(vec3 dir, vec3 sun) {
	vec3 up = normalize(up_dir);
	float zenith = clamp(dot(dir, up) * 0.5 + 0.5, 0.0, 1.0);
	float horizon = pow(1.0 - zenith, 1.6);
	vec3 top = vec3(0.1, 0.18, 0.32);
	vec3 haze = vec3(0.28, 0.26, 0.22);
	vec3 sky = mix(top, haze, horizon);
	float mu = max(dot(dir, sun), 0.0);
	sky += vec3(0.85, 0.55, 0.28) * pow(mu, 4.0) * 0.16;
	sky += vec3(1.0, 0.86, 0.62) * pow(mu, 36.0) * 0.42;
	return sky;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sun = normalize(sun_dir);
	vec3 base = vec3(0.0015, 0.0025, 0.008);
	vec3 col = base;
	if (cheap < 0.5) {
	float far_n = fbm(dir * 1.35 + vec3(2.2, 0.4, 1.1));
	float mid_n = fbm(dir * 2.8 + far_n * 0.55 + vec3(7.0, 1.4, 3.2));
	float near_n = fbm(dir * 5.4 + mid_n * 0.35 + vec3(0.6, 4.8, 8.1));

	vec3 indigo = vec3(0.05, 0.06, 0.13);
	vec3 teal = vec3(0.03, 0.11, 0.15);
	vec3 violet = vec3(0.08, 0.05, 0.12);
	float far_mask = smoothstep(0.46, 0.76, far_n);
	float mid_mask = smoothstep(0.52, 0.82, mid_n);
	float near_mask = smoothstep(0.58, 0.86, near_n);
	col = mix(col, indigo, far_mask * 0.2);
	col = mix(col, teal, mid_mask * 0.13);
	col = mix(col, violet, near_mask * 0.08);
	float filament = smoothstep(0.66, 0.84, fbm(dir * 8.0 + vec3(4.0, 2.0, 9.0)));
	col += vec3(0.12, 0.08, 0.05) * filament * 0.05;

	vec3 cell_a = floor(dir * 720.0);
	vec3 cell_b = floor(dir * 340.0 + 17.0);
	float h1 = hash13(cell_a);
	float h2 = hash13(cell_b);
	float dim = step(0.9993, h1) * (0.1 + 0.22 * hash13(cell_a + 3.1));
	float bright = step(0.9991, h2) * (0.45 + 0.4 * hash13(cell_b + 1.7));
	col += vec3(0.72, 0.8, 0.95) * dim;
	col += vec3(0.92, 0.94, 1.0) * bright;

	float mu = max(dot(dir, sun), 0.0);
	float corona = pow(mu, 64.0);
	float wide = pow(mu, 18.0);
	col += vec3(1.0, 0.52, 0.18) * corona * 0.55;
	col += vec3(0.55, 0.24, 0.08) * wide * 0.1;
	}
	col = mix(col, air_sky(dir, sun), clamp(ground_mix, 0.0, 1.0));

	COLOR = col;
}
