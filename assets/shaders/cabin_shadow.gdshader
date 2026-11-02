shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never, blend_mix;

// Blocky contact shadow. The edge is Bayer-dithered so it sits in the pixel grid.

const mat4 BAYER = mat4(
	vec4(0.0, 12.0, 3.0, 15.0),
	vec4(8.0, 4.0, 11.0, 7.0),
	vec4(2.0, 14.0, 1.0, 13.0),
	vec4(10.0, 6.0, 9.0, 5.0)
) / 16.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float box = max(abs(p.x), abs(p.y));
	float cover = 1.0 - smoothstep(0.2, 1.0, box);
	ivec2 pixel = ivec2(floor(FRAGCOORD.xy));
	float bayer = BAYER[pixel.x & 3][pixel.y & 3];
	if (cover < bayer) {
		discard;
	}
	ALBEDO = vec3(0.03, 0.028, 0.025);
	ALPHA = 0.84;
}
