shader_type canvas_item;
render_mode unshaded;

// Cabin-only grade. Warm mids, teal shadows, a little contrast.
// The exterior never draws this rect.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 teal = col * vec3(0.94, 0.98, 1.0);
	vec3 warm = col * vec3(1.03, 1.0, 0.96);
	float mid = smoothstep(0.08, 0.55, luma);
	vec3 graded = mix(teal, warm, mid);
	vec2 uv = SCREEN_UV * 2.0 - 1.0;
	float vig = smoothstep(1.35, 0.45, dot(uv, uv));
	graded *= mix(0.9, 1.0, vig);
	COLOR = vec4(mix(col, clamp(graded, 0.0, 1.0), 0.16), 1.0);
}
