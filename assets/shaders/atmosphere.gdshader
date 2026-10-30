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
	// Light the haze by the limb point under this pixel, not the shell's near face,
	// so the night side stays dark instead of getting a blue veil.
	vec3 limb = n - view_dir * dot(n, view_dir);
	limb = length(limb) > 1e-4 ? normalize(limb) : n;
	float ndl = dot(normalize(mix(limb, n, 0.25)), normalize(u_sun_dir));
	float day = smoothstep(-0.12, 0.35, ndl);
	float term = exp(-ndl * ndl * 24.0);
	vec3 cool = mix(u_color, vec3(0.4, 0.68, 0.95), 0.8);
	vec3 col = cool * mix(0.05, 1.1, day);
	col += vec3(1.0, 0.78, 0.5) * term * rim * 0.35;
	// Forward scatter: the limb lights up when the sun sits behind Mina.
	float back = pow(max(dot(-view_dir, normalize(u_sun_dir)), 0.0), 8.0);
	col += vec3(0.55, 0.78, 1.0) * back * rim * 1.4;
	float alpha = rim * scatter * mix(0.1, 1.0, max(day, back)) * u_strength;
	ALBEDO = col;
	ALPHA = alpha;
}
