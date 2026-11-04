shader_type spatial;
render_mode blend_mix, unshaded, cull_back, depth_draw_never, fog_disabled;

varying vec3 v_dir;
varying vec3 v_world;
varying vec3 v_nrm;

uniform sampler2D u_cloud : filter_nearest, repeat_enable;
uniform vec3 u_sun_dir = vec3(0.48, 0.79, 0.31);
uniform vec3 u_city_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 u_color : source_color = vec3(0.86, 0.93, 0.97);
uniform float u_time = 0.0;

vec2 equirect(vec3 dir) {
	float u = atan(dir.z, dir.x) * (0.5 / PI) + 0.5;
	float v = acos(clamp(dir.y, -1.0, 1.0)) / PI;
	return vec2(u, v);
}

void vertex() {
	v_dir = normalize(VERTEX);
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = equirect(normalize(v_dir)) + vec2(u_time * 0.012, u_time * 0.0016);
	float cover = smoothstep(0.5, 0.78, texture(u_cloud, uv).r);
	float city = smoothstep(0.74, 0.92, dot(normalize(v_dir), normalize(u_city_dir)));
	cover *= 1.0 - city;
	if (cover < 0.04) {
		discard;
	}
	float ndl = dot(normalize(v_nrm), normalize(u_sun_dir));
	float day = smoothstep(-0.18, 0.42, ndl);
	vec3 col = u_color * mix(0.16, 1.0, day);
	ALBEDO = col;
	ALPHA = cover * mix(0.12, 0.86, day);
}
