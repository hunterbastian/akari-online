shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

// Cheap shuttle-bay field. A few scrolling bands, no screen copy.
// The world behind it stays visible.

uniform vec4 field_color : source_color = vec4(0.45, 0.9, 1.0, 1.0);
uniform float openness = 1.0;

void fragment() {
	float row = floor(FRAGCOORD.y * 0.5);
	float scan = 0.5 + 0.5 * sin(row * 0.42 - TIME * 3.5);
	float edge = smoothstep(0.14, 0.0, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	float alpha = (0.035 + scan * 0.045 + edge * 0.42) * clamp(openness, 0.0, 1.0);
	ALBEDO = field_color.rgb;
	EMISSION = field_color.rgb * (0.25 + edge * 0.9);
	ALPHA = alpha;
}
