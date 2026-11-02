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
	limb = length(limb) > 1e-4 ? normalize(limb) : n;
	vec3 sun = normalize(u_sun_dir);
	float ndl = dot(normalize(mix(limb, n, 0.25)), sun);
	// Wide terminator: the night limb stays faint instead of cutting off.
	float day = smoothstep(-0.42, 0.55, ndl);
	float term = exp(-ndl * ndl * 6.0);
	vec3 rayleigh = mix(u_color, vec3(0.42, 0.66, 1.0), 0.72);
	vec3 warm = vec3(1.0, 0.74, 0.48);
	vec3 col = mix(rayleigh, warm, clamp(term * 0.7, 0.0, 1.0));
	col *= mix(0.22, 1.0, day);
	float back = pow(max(dot(-view_dir, sun), 0.0), 6.0);
	col += warm * term * rim * 0.55;
	col += vec3(0.62, 0.8, 1.0) * back * rim * 0.8;
	float alpha = rim * scatter * mix(0.1, 0.72, max(day, back * 0.7)) * u_strength;
	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
