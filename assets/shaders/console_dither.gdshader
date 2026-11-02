shader_type canvas_item;

// Slight Bayer dither on the console panel, in screen pixels.

const mat4 BAYER = mat4(
	vec4(0.0, 12.0, 3.0, 15.0),
	vec4(8.0, 4.0, 11.0, 7.0),
	vec4(2.0, 14.0, 1.0, 13.0),
	vec4(10.0, 6.0, 9.0, 5.0)
) / 16.0;

void fragment() {
	vec3 col = COLOR.rgb;
	ivec2 pixel = ivec2(floor(FRAGCOORD.xy));
	float bayer = BAYER[pixel.x & 3][pixel.y & 3] - 0.5;
	col += bayer * 0.018;
	COLOR = vec4(max(col, vec3(0.0)), COLOR.a);
}
