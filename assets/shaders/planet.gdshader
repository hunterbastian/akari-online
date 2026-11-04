shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

// Vertex colors are baked. Lighting stays flat and unshaded: a hard terminator,
// no specular. Close-up grain and cloud shadows are texture lookups.

varying vec3 v_dir;
varying vec3 v_world;
varying vec3 v_nrm;
varying vec3 v_col;

uniform vec3 u_sun_dir = vec3(0.48, 0.79, 0.31);
uniform vec3 u_city_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 u_atmo : source_color = vec3(0.94, 0.71, 0.64);
uniform float u_time = 0.0;
uniform float u_detail_near = 6.0;
uniform float u_detail_far = 38.0;
uniform float u_cloud_bias = 0.1;
uniform sampler2D u_detail : filter_nearest, repeat_enable;
uniform sampler2D u_cloud : filter_nearest, repeat_enable;

vec2 equirect(vec3 dir) {
	float u = atan(dir.z, dir.x) * (0.5 / PI) + 0.5;
	float v = acos(clamp(dir.y, -1.0, 1.0)) / PI;
	return vec2(u, v);
}

float cloud_cover(vec2 uv) {
	return smoothstep(0.5, 0.78, texture(u_cloud, uv).r);
}

void vertex() {
	v_dir = normalize(VERTEX);
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = COLOR.rgb;
}

void fragment() {
	vec3 light_dir = normalize(u_sun_dir);
	vec3 geo = normalize(v_nrm);
	float ndl_geo = dot(geo, light_dir);
	float day = smoothstep(-0.04, 0.16, ndl_geo);

	float dist = distance(CAMERA_POSITION_WORLD, v_world);
	float detail = 1.0 - smoothstep(u_detail_near, u_detail_far, dist);
	vec2 duv = vec2(v_dir.x + v_dir.z * 0.35, v_dir.y + v_dir.x * 0.2) * 14.0;
	float grain = texture(u_detail, duv).r;
	float gx = texture(u_detail, duv + vec2(0.04, 0.0)).r - grain;
	float gy = texture(u_detail, duv + vec2(0.0, 0.04)).r - grain;
	vec3 axis = abs(geo.y) > 0.96 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 tangent = normalize(cross(axis, geo));
	vec3 bitangent = cross(geo, tangent);
	vec3 nrm = normalize(geo + (tangent * gx + bitangent * gy) * detail * 2.2);

	vec3 flat_n = cross(dFdx(v_world), dFdy(v_world));
	float flat_len = length(flat_n);
	if (flat_len > 1e-5) {
		flat_n /= flat_len;
		if (dot(flat_n, geo) < 0.0) {
			flat_n = -flat_n;
		}
		nrm = normalize(mix(nrm, flat_n, 0.62));
	}

	float lambert = clamp(dot(nrm, light_dir) * 0.72 + 0.2, 0.0, 1.0);
	vec3 albedo = v_col * mix(1.0, mix(0.8, 1.14, grain), detail * 0.65);
	vec3 lit = albedo * (0.08 + 0.9 * lambert);
	vec3 night = albedo * vec3(0.018, 0.032, 0.06);
	vec3 color = mix(night, lit, day);

	// Shadows sit down-sun of the cloud shell. The same scroll keeps them stuck to the clouds.
	vec3 shadow_dir = normalize(v_dir + light_dir * u_cloud_bias);
	vec2 cuv = equirect(shadow_dir) + vec2(u_time * 0.012, u_time * 0.0016);
	float cover = cloud_cover(cuv);
	cover += cloud_cover(cuv + vec2(0.018, 0.006));
	cover += cloud_cover(cuv + vec2(-0.014, 0.01));
	cover += cloud_cover(cuv + vec2(0.004, -0.016));
	cover *= 0.25;
	float city = smoothstep(0.74, 0.92, dot(normalize(v_dir), normalize(u_city_dir)));
	cover *= 1.0 - city;
	color *= mix(1.0, 0.38, cover * day);

	float fog = smoothstep(32.0, 110.0, dist);
	vec3 haze = u_atmo * mix(0.32, 0.78, day);
	color = mix(color, haze, fog * 0.5);
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luma), color, 1.4);
	ALBEDO = color;
}
