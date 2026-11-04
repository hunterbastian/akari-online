shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

varying vec3 v_world;
varying vec3 v_nrm;
varying vec3 v_col;

uniform vec3 u_sun_dir = vec3(0.48, 0.79, 0.31);
uniform vec3 u_atmo : source_color = vec3(0.94, 0.71, 0.64);

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = COLOR.rgb;
}

void fragment() {
	vec3 nrm = normalize(v_nrm);
	vec3 light_dir = normalize(u_sun_dir);
	float ndl = dot(nrm, light_dir);
	float day = smoothstep(-0.02, 0.2, ndl);
	float lambert = clamp(ndl * 0.7 + 0.34, 0.2, 1.0);
	vec3 lit = v_col * (0.2 + 0.85 * lambert);
	vec3 night = v_col * vec3(0.08, 0.12, 0.18);
	vec3 color = mix(night, lit, day);
	float dist = distance(CAMERA_POSITION_WORLD, v_world);
	float fog = smoothstep(16.0, 70.0, dist);
	color = mix(color, u_atmo * mix(0.3, 0.75, day), fog * 0.6);
	ALBEDO = color;
}
