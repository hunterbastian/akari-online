shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// Green phosphor CRT. The albedo comes from a SubViewport so the terminal can go interactive later.

uniform sampler2D screen_tex : filter_nearest, repeat_disable;
uniform vec4 phosphor : source_color = vec4(0.62, 1.0, 0.68, 1.0);
uniform float curvature = 0.028;
uniform float scanline_strength = 0.22;
uniform float flicker_strength = 0.03;
uniform float glow_spread = 0.004;
uniform float brightness = 1.35;

const mat4 BAYER = mat4(
	vec4(0.0, 12.0, 3.0, 15.0),
	vec4(8.0, 4.0, 11.0, 7.0),
	vec4(2.0, 14.0, 1.0, 13.0),
	vec4(10.0, 6.0, 9.0, 5.0)
) / 16.0;

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv * 2.0 - 1.0;
	float r2 = dot(centered, centered);
	uv += centered * r2 * curvature;
	float vignette = mix(0.72, 1.0, smoothstep(1.35, 0.15, r2));
	vec3 col = vec3(0.01, 0.02, 0.012);
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		vec3 texel = texture(screen_tex, uv).rgb;
		if (glow_spread > 0.0) {
			vec3 bleed = texture(screen_tex, uv + vec2(glow_spread, 0.0)).rgb;
			bleed += texture(screen_tex, uv - vec2(glow_spread, 0.0)).rgb;
			bleed += texture(screen_tex, uv + vec2(0.0, glow_spread)).rgb;
			bleed += texture(screen_tex, uv - vec2(0.0, glow_spread)).rgb;
			texel = mix(texel, bleed * 0.25, 0.35);
		}
		float scan = sin(uv.y * 210.0 + TIME * 1.5) * 0.5 + 0.5;
		texel *= mix(1.0, 0.55 + scan, scanline_strength);
		float flick = 1.0 + sin(TIME * 47.0) * flicker_strength + sin(TIME * 12.7) * flicker_strength * 0.45;
		ivec2 pixel = ivec2(floor(FRAGCOORD.xy));
		float bayer = BAYER[pixel.x & 3][pixel.y & 3];
		texel += (bayer - 0.5) * 0.012;
		col = max(texel, vec3(0.0)) * phosphor.rgb * vignette * flick * brightness;
		col = max(col, vec3(0.02, 0.12, 0.045) * vignette);
	}
	// Unshaded albedo carries the phosphor. Emission adds the soft glow on Forward+.
	ALBEDO = col;
	EMISSION = col * 0.8;
}
