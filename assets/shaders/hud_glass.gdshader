shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled, fog_disabled, ensure_correct_normals;

// Combiner glass. The SubViewport is black everywhere there is no symbol, so additive
// blending leaves the sky alone. Bayer and scanlines run in the world view's pixels,
// which is already the 0.7 render-scale grid.

uniform sampler2D screen_tex : filter_nearest, repeat_disable;
uniform vec4 phosphor : source_color = vec4(0.62, 1.0, 0.72, 1.0);
uniform vec4 glass_tint : source_color = vec4(0.55, 0.95, 0.72, 1.0);
uniform float glass_alpha = 0.07;
uniform float fresnel_strength = 0.22;
uniform float fresnel_power = 2.4;
uniform float scanline_strength = 0.14;
uniform float dither_strength = 0.012;
uniform float edge_glow = 0.42;
uniform float brightness = 1.45;
uniform float glow_spread = 0.0;

const mat4 BAYER = mat4(
	vec4(0.0, 12.0, 3.0, 15.0),
	vec4(8.0, 4.0, 11.0, 7.0),
	vec4(2.0, 14.0, 1.0, 13.0),
	vec4(10.0, 6.0, 9.0, 5.0)
) / 16.0;

void fragment() {
	vec2 uv = UV;
	vec3 texel = texture(screen_tex, uv).rgb;
	if (glow_spread > 0.0) {
		vec3 bleed = texture(screen_tex, uv + vec2(glow_spread, 0.0)).rgb;
		bleed += texture(screen_tex, uv - vec2(glow_spread, 0.0)).rgb;
		bleed += texture(screen_tex, uv + vec2(0.0, glow_spread)).rgb;
		bleed += texture(screen_tex, uv - vec2(0.0, glow_spread)).rgb;
		texel = max(texel, bleed * 0.22);
	}

	float glyph = smoothstep(0.045, 0.16, max(texel.r, max(texel.g, texel.b)));
	vec3 ink = texel.rgb * phosphor.rgb * brightness;
	// Every other row of the low-res view, so the lines sit on the same pixels as the film dither.
	float scan_row = mod(floor(FRAGCOORD.y), 2.0);
	ink *= 1.0 - scan_row * scanline_strength * glyph;

	ivec2 pixel = ivec2(floor(FRAGCOORD.xy));
	float bayer = BAYER[pixel.x & 3][pixel.y & 3] - 0.5;
	ink += bayer * dither_strength * glyph;

	vec2 edge_uv = abs(uv - 0.5) * 2.0;
	float edge = max(edge_uv.x, edge_uv.y);
	float rim = smoothstep(0.90, 1.0, edge);
	float sheen = smoothstep(0.62, 1.0, edge);

	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, fresnel_power) * fresnel_strength;

	vec3 glass = glass_tint.rgb * (glass_alpha + fresnel);
	glass += bayer * dither_strength * 0.35 * glass_alpha;
	vec3 glow = glass_tint.rgb * (rim * edge_glow + sheen * edge_glow * 0.22);

	vec3 add = max(glass + glow + ink * glyph, vec3(0.0));
	ALBEDO = add;
	EMISSION = ink * glyph * 0.45 + glow * 0.35;
	ALPHA = 1.0;
}
