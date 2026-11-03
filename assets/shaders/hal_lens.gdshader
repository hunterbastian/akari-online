shader_type spatial;
render_mode unshaded, shadows_disabled, cull_back;

// Mid red on purpose. A bright red turns peach once the film grade rolls the highlights.
uniform float glow = 1.0;

void fragment() {
	float pulse = clamp(glow, 0.45, 1.0);
	vec3 col = vec3(0.58, 0.035, 0.025) * pulse;
	ALBEDO = col;
	EMISSION = col * 0.2;
}
