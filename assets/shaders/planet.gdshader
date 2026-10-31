shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

varying vec3 v_obj;
varying vec3 v_world;

uniform vec3 u_center;
uniform vec3 u_sun_dir = vec3(0.48, 0.79, 0.31);
uniform vec3 u_c0 : source_color = vec3(0.5);
uniform vec3 u_c1 : source_color = vec3(0.7);
uniform vec3 u_c2 : source_color = vec3(0.85);
uniform vec3 u_c3 : source_color = vec3(0.95);
uniform vec3 u_atmo : source_color = vec3(0.9, 0.7, 0.6);
uniform float u_seed = 0.5;
uniform float u_time = 0.0;
uniform float u_biome = 3.0;

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
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

void vertex() {
	v_obj = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 nrm = normalize(v_obj);
	float freq = 1.22 + fract(u_seed * 0.37) * 0.28;
	vec3 p = nrm * freq + vec3(u_seed * 0.21, u_seed * 0.13, -u_seed * 0.17);
	vec3 p2 = p * 2.05 + vec3(4.2, 1.3, 2.7);
	float n1 = vnoise(p);
	float n2 = vnoise(p2);
	float n3 = vnoise(p * 4.09 + 9.1);
	float n4 = vnoise(p * 8.21 + 2.4);
	float shape = n1;
	float paint = n2 * 0.58 + n3 * 0.42;
	float detail = n3 * 0.62 + n4 * 0.38;
	float lat = abs(nrm.y);

	vec3 world_n = normalize(v_world - u_center);
	float eps = 0.09;
	float bx = vnoise(p2 + vec3(eps, 0.0, 0.0)) - n2;
	float by = vnoise(p2 + vec3(0.0, eps, 0.0)) - n2;
	float bz = vnoise(p2 + vec3(0.0, 0.0, eps)) - n2;
	float fine_x = vnoise(p * 7.0 + vec3(eps, 0.0, 0.0)) - vnoise(p * 7.0);
	float fine_y = vnoise(p * 7.0 + vec3(0.0, eps, 0.0)) - vnoise(p * 7.0);
	float fine_z = vnoise(p * 7.0 + vec3(0.0, 0.0, eps)) - vnoise(p * 7.0);
	vec3 bump = vec3(bx, by, bz) * 5.2 + vec3(fine_x, fine_y, fine_z) * 1.6;
	vec3 local_n = normalize(nrm - bump);
	world_n = normalize((MODEL_MATRIX * vec4(local_n, 0.0)).xyz);

	vec3 albedo = u_c1;
	float spec_mask = 0.0;
	float shine = 24.0;
	float sheen_amt = 0.0;
	float cloud_amt = 0.45;
	float crack = 0.0;

	if (u_biome < 0.5) {
		float sea = smoothstep(0.4, 0.28, shape);
		vec3 water = mix(u_c0 * 0.72, u_c0, paint);
		vec3 canopy = mix(u_c0, u_c1, smoothstep(0.18, 0.78, paint));
		vec3 clearing = mix(u_c1, u_c2, smoothstep(0.22, 0.82, detail));
		albedo = mix(canopy, clearing, smoothstep(0.48, 0.76, shape) * 0.72);
		albedo = mix(albedo, u_c3, smoothstep(0.72, 0.93, lat));
		albedo = mix(albedo, water, sea);
		spec_mask = sea;
		shine = 34.0;
		sheen_amt = 0.08;
		cloud_amt = 0.64;
	} else if (u_biome < 1.5) {
		float sea = smoothstep(0.62, 0.5, shape);
		vec3 water = mix(u_c0 * 0.78, u_c1, 0.18 + paint * 0.5);
		water = mix(water, u_c0 * 0.7, smoothstep(0.4, 0.16, shape) * 0.55);
		vec3 land = mix(u_c1, mix(u_c2, u_c3, paint * 0.65), 0.8);
		albedo = mix(land, water, sea);
		albedo = mix(albedo, u_c3, smoothstep(0.74, 0.94, lat) * (1.0 - sea));
		spec_mask = sea;
		shine = 26.0;
		sheen_amt = 0.15;
		cloud_amt = 0.72;
	} else if (u_biome < 2.5) {
		float basin = smoothstep(0.46, 0.24, shape);
		float dune = 0.5 + 0.5 * sin(nrm.y * 7.0 + shape * 4.0);
		vec3 sand = mix(u_c1, u_c2, dune * 0.55 + paint * 0.25);
		vec3 rust = mix(u_c0, u_c1, paint * 0.28);
		albedo = mix(sand, rust, basin);
		albedo = mix(albedo, mix(u_c1, u_c2, dune), (1.0 - basin) * 0.22);
		albedo = mix(albedo, u_c3, smoothstep(0.82, 0.97, lat) * 0.28);
		cloud_amt = 0.12;
	} else if (u_biome < 3.5) {
		vec3 blue = mix(u_c0, u_c1, 0.22 + paint * 0.5);
		vec3 pale = mix(u_c1, u_c2, 0.4);
		float high = smoothstep(0.7, 0.88, shape);
		albedo = mix(blue, pale, high * 0.72);
		albedo = mix(albedo, u_c2, smoothstep(0.74, 0.95, lat) * 0.72);
		float crev = smoothstep(0.42, 0.1, detail);
		albedo = mix(albedo, u_c0 * 0.42, crev * 0.62);
		spec_mask = 0.5;
		shine = 30.0;
		sheen_amt = 0.04;
		cloud_amt = 0.2;
	} else if (u_biome < 4.5) {
		vec3 rock = mix(u_c0, u_c1, 0.18 + smoothstep(0.25, 0.8, shape) * 0.35);
		float vein = 1.0 - smoothstep(0.0, 0.08, abs(shape - 0.5));
		float fine = 1.0 - smoothstep(0.015, 0.08, abs(paint - 0.46));
		crack = clamp(vein * 0.9 + fine * 0.28, 0.0, 1.0);
		albedo = mix(rock, u_c2, crack * 0.92);
		cloud_amt = 0.18;
	} else {
		float sea = smoothstep(0.44, 0.32, shape);
		vec3 low = mix(u_c0, u_c1, paint);
		vec3 high = mix(u_c1, u_c2, smoothstep(0.2, 0.86, detail));
		albedo = mix(low, high, smoothstep(0.34, 0.7, shape));
		albedo = mix(albedo, u_c3, smoothstep(0.7, 0.93, lat));
		albedo = mix(albedo, u_c0, sea * 0.72);
		spec_mask = sea * 0.45;
		shine = 22.0;
		sheen_amt = 0.06;
		cloud_amt = 0.46;
	}

	vec3 light_dir = normalize(u_sun_dir);
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world);
	float ndl = dot(world_n, light_dir);
	// Geometric normal for the terminator so bump noise does not smear it.
	float ndl_geo = dot(normalize(v_world - u_center), light_dir);
	// Hard sun: a narrow terminator, lit side Lambert-ish, night side near black.
	float day = smoothstep(-0.03, 0.09, ndl_geo);
	float lambert = clamp(ndl * 0.85 + 0.15, 0.0, 1.0);
	vec3 lit = albedo * (0.05 + 0.6 * lambert);
	vec3 night = albedo * vec3(0.012, 0.02, 0.04);
	vec3 color = mix(night, lit, day);
	float term = exp(-ndl_geo * ndl_geo * 160.0);
	color += vec3(1.0, 0.72, 0.42) * term * 0.08 * (0.3 + albedo);
	color += vec3(1.0, 0.42, 0.16) * crack * 0.16 * day;

	vec3 half_dir = normalize(light_dir + view_dir);
	float ndh = max(dot(world_n, half_dir), 0.0);
	float glint = pow(ndh, shine) * 0.55 + pow(ndh, 5.0) * sheen_amt;
	color += vec3(1.0, 0.97, 0.92) * glint * spec_mask * smoothstep(-0.02, 0.22, ndl);

	float band = sin(nrm.y * 2.4 + u_seed * 1.4 + shape * 1.6 + u_time * 0.012);
	float cn = vnoise(nrm * 1.8 + vec3(u_time * 0.01, u_seed, 0.4));
	float cloud = smoothstep(0.18, 0.88, band * 0.5 + 0.5);
	cloud = clamp(cloud * 0.7 + smoothstep(0.42, 0.8, cn) * 0.55, 0.0, 1.0);
	vec3 cloud_col = mix(vec3(0.78, 0.86, 0.92), vec3(0.9, 0.94, 0.97), 0.55) * 0.68;
	float cloud_vis = mix(0.03, 1.0, smoothstep(-0.03, 0.3, ndl_geo));
	color = mix(color, cloud_col * mix(0.02, 1.0, day) * mix(0.7, 1.0, lambert), clamp(cloud * cloud_amt, 0.0, 0.42) * cloud_vis);

	float fres = pow(1.0 - clamp(dot(world_n, view_dir), 0.0, 1.0), 2.4);
	vec3 rim_col = mix(vec3(0.35, 0.6, 0.95), vec3(0.75, 0.88, 1.0), smoothstep(0.0, 0.35, ndl_geo));
	// Thin cool rim on the night limb, brighter haze on the day limb.
	float thin = pow(1.0 - clamp(dot(world_n, view_dir), 0.0, 1.0), 6.0);
	color += rim_col * (fres * 0.32 * day + thin * 0.22 * (1.0 - day));

	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	// AgX and the grade both pull saturation; push it back so Mina stays ice-blue, not grey.
	color = max(mix(vec3(luma), color, 1.7), vec3(0.0));
	color = mix(color * vec3(0.8, 0.92, 1.08), color * vec3(0.98, 0.99, 1.0), smoothstep(0.25, 0.85, luma));
	ALBEDO = color;
}
