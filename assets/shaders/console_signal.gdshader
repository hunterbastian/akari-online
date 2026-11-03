shader_type canvas_item;

// The console's own last steps, after the film pass on the low-res world view.
// First the GameCube's deflicker filter: each line blended with the lines above
// and below it, 1:2:1, which is most of why its games look soft. Then a composite
// video signal: colour carried with far less detail than brightness, so it bleeds
// sideways along each line, brightness a touch soft with a faint ring after sharp
// edges, and a little colour crawling on those edges. One texel is one rendered
// pixel, so both stay on the pixel grid and the view is nearest-upscaled after.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float deflicker : hint_range(0.0, 1.0) = 1.0;
uniform float composite : hint_range(0.0, 1.0) = 0.6;

// RGB to YIQ (brightness, then the two colour axes) and back. Columns, as GLSL builds them.
const mat3 TO_YIQ = mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312));
const mat3 FROM_YIQ = mat3(vec3(1.0, 1.0, 1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703));

// One rendered pixel, deflickered: blended with the pixels above and below.
vec3 line_tap(vec2 uv, float dy) {
	vec3 mid = texture(screen_tex, uv).rgb;
	vec3 above = texture(screen_tex, uv - vec2(0.0, dy)).rgb;
	vec3 below = texture(screen_tex, uv + vec2(0.0, dy)).rgb;
	return mix(mid, (above + 2.0 * mid + below) * 0.25, deflicker);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float dx = SCREEN_PIXEL_SIZE.x;
	float dy = SCREEN_PIXEL_SIZE.y;
	vec3 here = line_tap(uv, dy);
	vec3 col = here;
	if (composite > 0.001) {
		// Seven pixels along the line, three either side.
		vec3 l3 = TO_YIQ * line_tap(uv - vec2(3.0 * dx, 0.0), dy);
		vec3 l2 = TO_YIQ * line_tap(uv - vec2(2.0 * dx, 0.0), dy);
		vec3 l1 = TO_YIQ * line_tap(uv - vec2(dx, 0.0), dy);
		vec3 c0 = TO_YIQ * here;
		vec3 r1 = TO_YIQ * line_tap(uv + vec2(dx, 0.0), dy);
		vec3 r2 = TO_YIQ * line_tap(uv + vec2(2.0 * dx, 0.0), dy);
		vec3 r3 = TO_YIQ * line_tap(uv + vec2(3.0 * dx, 0.0), dy);
		// Colour bleeds: a wide, soft smear (1 2 3 4 3 2 1), a little paler.
		vec2 iq = (l3.yz + 2.0 * l2.yz + 3.0 * l1.yz + 4.0 * c0.yz + 3.0 * r1.yz + 2.0 * r2.yz + r3.yz) / 16.0;
		iq *= 0.94;
		// Brightness: a touch soft, then a faint ring off the pixels two out.
		float y = mix(c0.x, (l1.x + 2.0 * c0.x + r1.x) * 0.25, 0.5);
		y += (y - (l2.x + r2.x) * 0.5) * 0.18;
		// Colour crawling on sharp edges, in a fine diagonal pattern that steps each frame.
		float edge = clamp(abs(r1.x - l1.x) * 2.0, 0.0, 1.0);
		vec2 pixel = floor(FRAGCOORD.xy);
		float phase = (pixel.x + pixel.y + floor(TIME * 30.0)) * 1.5707963;
		iq += vec2(cos(phase), sin(phase)) * edge * 0.035;
		col = mix(here, FROM_YIQ * vec3(y, iq), composite);
	}
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
