shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float dither_strength : hint_range(0.0, 0.02) = 0.00392;
uniform float grain_strength : hint_range(0.0, 0.04) = 0.0065;

// Bayer 4x4 stored by columns so BAYER[x][y] is the threshold.
const mat4 BAYER = mat4(
	vec4(0.0, 12.0, 3.0, 15.0),
	vec4(8.0, 4.0, 11.0, 7.0),
	vec4(2.0, 14.0, 1.0, 13.0),
	vec4(10.0, 6.0, 9.0, 5.0)
) / 16.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	ivec2 pixel = ivec2(floor(FRAGCOORD.xy));
	float bayer = BAYER[pixel.x & 3][pixel.y & 3];
	float grain = hash12(vec2(pixel) * 0.5) - 0.5;
	col += (bayer - 0.5) * dither_strength;
	col += grain * grain_strength;
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
