shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, fog_disabled;

varying vec3 v_obj;
varying vec3 v_world;

uniform vec3 u_color : source_color = vec3(0.78, 0.84, 0.9);
uniform vec3 u_center = vec3(0.0);
uniform vec3 u_sun_dir = vec3(0.5, 0.8, 0.3);
uniform float u_planet_radius = 24.0;
uniform float u_inner = 30.0;
uniform float u_outer = 40.0;
uniform float u_alpha = 0.45;

void vertex() {
	v_obj = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void fragment() {
	float radial = length(v_obj.xy);
	float span = max(u_outer - u_inner, 0.001);
	float t = (radial - u_inner) / span;
	float inner_edge = smoothstep(0.0, 0.08, t);
	float outer_edge = 1.0 - smoothstep(0.9, 1.0, t);
	// Many thin ringlets with dark gaps, so the rings read as structure up close, not a sheet.
	float lane = floor(t * 46.0);
	float ringlet = mix(0.25, 1.0, hash11(lane + u_inner));
	float gap = step(0.18, hash11(lane * 1.7 + 3.0 + u_inner));
	float fine = 0.7 + 0.3 * sin(radial * 9.0);
	float bands = 0.55 + 0.45 * sin(radial * 0.85 + u_inner);
	float density = ringlet * mix(0.12, 1.0, gap) * fine * bands;

	vec3 sun = normalize(u_sun_dir);
	vec3 oc = u_center - v_world;
	float tca = dot(oc, sun);
	float d2 = dot(oc, oc) - tca * tca;
	float r2 = u_planet_radius * u_planet_radius;
	float in_front = step(0.0, tca);
	float shadow = 1.0 - in_front * smoothstep(r2 * 1.02, r2 * 0.94, d2);

	// Lit face vs unlit face: seen from the side the sun does not reach, the rings go dark,
	// with a little forward-scattered light when looking toward the sun.
	vec3 ring_n = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world);
	float sun_side = sign(dot(ring_n, sun));
	float view_side = sign(dot(ring_n, view_dir));
	float lit_face = step(0.0, sun_side * view_side);
	float forward = pow(max(dot(-view_dir, sun), 0.0), 6.0);
	float light = mix(0.1 + 0.5 * forward, 1.0, lit_face) * mix(0.04, 1.0, shadow);
	vec3 col = u_color * light * mix(0.85, 1.1, ringlet);

	// Fade rings that are very close to the camera so a pass through them stays readable.
	float cam_dist = length(CAMERA_POSITION_WORLD - v_world);
	float near_fade = smoothstep(2.0, u_planet_radius * 0.9, cam_dist);
	ALBEDO = col;
	ALPHA = clamp(inner_edge * outer_edge * density * u_alpha * near_fade, 0.0, 1.0);
}
