shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float u_time = 0.0;

void fragment() {
	float slide = UV.y * 5.0 - u_time * 1.4;
	float streak = smoothstep(0.38, 0.5, abs(fract(slide) - 0.5));
	float side = smoothstep(0.08, 0.0, abs(UV.x - 0.5) - 0.32);
	vec3 hot = vec3(1.0, 0.46, 0.12);
	ALBEDO = hot * (0.35 + streak * 1.1);
	ALPHA = clamp((0.18 + streak * 0.62) * side, 0.0, 0.85);
}
