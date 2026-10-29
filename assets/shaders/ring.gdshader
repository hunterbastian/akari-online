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

void fragment() {
	float radial = length(v_obj.xy);
	float span = max(u_outer - u_inner, 0.001);
	float inner_edge = smoothstep(u_inner, u_inner + span * 0.18, radial);
	float outer_edge = 1.0 - smoothstep(u_outer - span * 0.22, u_outer, radial);
	float bands = 0.62 + 0.38 * sin(radial * 0.85 + u_inner);
	float dust = 0.75 + 0.25 * sin(radial * 3.4);

	vec3 sun = normalize(u_sun_dir);
	vec3 oc = u_center - v_world;
	float tca = dot(oc, sun);
	float d2 = dot(oc, oc) - tca * tca;
	float r2 = u_planet_radius * u_planet_radius;
	float in_front = step(0.0, tca);
	float shadow = 1.0 - in_front * smoothstep(r2 * 1.08, r2 * 0.86, d2);

	vec3 col = u_color * mix(vec3(0.55, 0.62, 0.72), vec3(1.0), shadow);
	ALBEDO = col;
	ALPHA = clamp(inner_edge * outer_edge * bands * dust * u_alpha * mix(0.35, 1.0, shadow), 0.0, 1.0);
}
