shader_type spatial;
render_mode specular_disabled;

// Shared by every slab. Windows and the red section mark live in one texture.
// Distance fades toward a warm haze so the towers read as huge.

uniform vec4 base_color : source_color = vec4(0.78, 0.76, 0.72, 1.0);
uniform sampler2D face_tex : filter_nearest, repeat_enable;
uniform vec3 haze_color = vec3(0.72, 0.58, 0.46);
uniform float haze_near = 18.0;
uniform float haze_far = 90.0;

void fragment() {
	vec3 tex = texture(face_tex, UV * vec2(3.0, 4.0)).rgb;
	vec3 col = base_color.rgb * tex;
	float mark = step(0.55, tex.r) * step(tex.g, 0.28) * step(tex.b, 0.28);
	col = mix(col, vec3(0.62, 0.11, 0.09), mark);
	float window = step(0.72, tex.r) * step(0.45, tex.g) * step(tex.b, 0.45);
	float dist = length(VERTEX);
	float haze = smoothstep(haze_near, haze_far, dist);
	ALBEDO = mix(col, haze_color, haze);
	ROUGHNESS = 0.78;
	METALLIC = 0.04;
	EMISSION = vec3(1.0, 0.72, 0.38) * window * (1.0 - haze) * 0.9;
}
