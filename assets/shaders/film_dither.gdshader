shader_type canvas_item;

// Film pass on the low-res world view. The Bayer grid is one step per rendered
// pixel, then the view is nearest-upscaled, so the dither stays on the pixel grid.
// UI and the wordmark sit outside this viewport and stay full resolution.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float dither_strength : hint_range(0.0, 0.04) = 0.01;
uniform float grain_strength : hint_range(0.0, 0.06) = 0.014;
uniform float quantize_steps : hint_range(8.0, 128.0) = 36.0;
uniform float vignette : hint_range(0.0, 0.6) = 0.14;
uniform float ca_strength : hint_range(0.0, 0.02) = 0.0;

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
	vec2 uv = SCREEN_UV;
	vec3 col;
	if (ca_strength > 0.00001) {
		vec2 shift = (uv - 0.5) * ca_strength;
		col.r = texture(screen_tex, uv + shift).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - shift).b;
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	ivec2 pixel = ivec2(floor(FRAGCOORD.xy));
	float bayer = BAYER[pixel.x & 3][pixel.y & 3];
	float steps = max(quantize_steps, 2.0);
	col += (bayer - 0.5) / steps;
	col = floor(clamp(col, 0.0, 1.0) * steps) / steps;
	col += (bayer - 0.5) * dither_strength;
	float tick = floor(TIME * 12.0);
	float grain = hash12(vec2(pixel) + vec2(tick, tick * 0.37)) - 0.5;
	col += grain * grain_strength;
	vec2 p = uv * 2.0 - 1.0;
	float vig = smoothstep(1.2, 0.25, dot(p, p));
	col *= mix(1.0 - vignette, 1.0, vig);
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
