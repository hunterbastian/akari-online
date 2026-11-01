shader_type canvas_item;
render_mode unshaded;

// Cabin-only grade. Warm mids, teal shadows, a little contrast.
// The exterior never draws this rect.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 teal = col * vec3(0.55, 0.78, 0.82);
	vec3 warm = col * vec3(1.08, 0.94, 0.78);
	float mid = smoothstep(0.015, 0.42, luma);
	vec3 graded = mix(teal, warm, mid);
	graded = (graded - 0.5) * 1.06 + 0.5;
	COLOR = vec4(mix(col, clamp(graded, 0.0, 1.0), 0.42), 1.0);
}
