shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, fog_disabled;

varying vec3 v_normal;
varying vec3 v_world;

uniform vec3 u_color : source_color = vec3(0.55, 0.75, 0.88);
uniform vec3 u_sun_dir = vec3(0.48, 0.79, 0.31);
uniform float u_power = 2.2;
uniform float u_falloff = 1.8;
uniform float u_strength = 1.0;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world);
	vec3 n = normalize(v_normal);
	float ndotv = clamp(dot(n, view_dir), 0.0, 1.0);
	float rim = pow(1.0 - ndotv, u_power);
	float scatter = exp(-ndotv * u_falloff);
	vec3 limb = n - view_dir * dot(n, view_dir);
	float limb_len = length(limb);
	limb = limb_len > 1e-4 ? limb / limb_len : n;
	vec3 sun = normalize(u_sun_dir);
	float ndl = dot(normalize(mix(limb, n, 0.22)), sun);
	// The bright limb lives on the sunward side and dies across the terminator.
	float day = smoothstep(-0.12, 0.4, ndl);
	float sunward = smoothstep(0.02, 0.7, ndl);
	vec3 haze = mix(u_color, vec3(0.5, 0.74, 1.0), 0.28);
	vec3 warm = vec3(1.05, 0.78, 0.52);
	vec3 col = mix(haze, warm, sunward * 0.72);
	col *= mix(0.16, 1.0, day);
	float glow = rim * sunward * day;
	col += warm * glow * 1.45;
	// Above 1 so the world glow blooms the limb. The film pass still dithers it.
	col *= mix(1.0, 2.2, glow);
	float alpha = rim * scatter * mix(0.04, 0.88, max(day, sunward * 0.35)) * u_strength;
	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 0.92);
}
