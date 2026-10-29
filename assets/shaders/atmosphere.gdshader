shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, fog_disabled;

varying vec3 v_normal;
varying vec3 v_world;

uniform vec3 u_color : source_color = vec3(0.94, 0.71, 0.64);
uniform vec3 u_sun_dir = vec3(0.48, 0.79, 0.31);

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world);
	vec3 n = normalize(v_normal);
	float ndotv = clamp(dot(n, view_dir), 0.0, 1.0);
	float rim = pow(1.0 - ndotv, 1.55);
	float halo = pow(1.0 - ndotv, 1.05);
	float ndl = dot(n, normalize(u_sun_dir));
	float day = smoothstep(-0.4, 0.62, ndl);
	float term = exp(-ndl * ndl * 5.5);
	vec3 col = u_color * mix(0.42, 1.05, day);
	col += vec3(1.0, 0.8, 0.5) * term * halo * 0.65;
	float alpha = (halo * 0.32 + rim * 0.58) * mix(0.28, 0.82, day);
	ALBEDO = col;
	ALPHA = alpha;
}
