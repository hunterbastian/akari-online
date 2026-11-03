shader_type canvas_item;

// Film pass on the low-res world view. The Bayer grid is one step per rendered
// pixel, then the view is nearest-upscaled, so the dither stays on the pixel grid.
// UI and the wordmark sit outside this viewport and stay full resolution.
//
// stack == 0 is the Destiny grade: this Bayer, grain, vignette. stack == 1 runs
// the sixth-gen chain on that same pass: Kawase bloom, distance blur, sun shafts,
// then this Bayer as the 5-bit dither (dither_strength is zeroed so it is not
// applied twice), GameCube vertical deflicker, composite chroma, and a light mask.
// A canvas shader cannot read the depth buffer, so the blur tests the view ray
// against the ship and against Mina.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float dither_strength : hint_range(0.0, 0.04) = 0.01;
uniform float grain_strength : hint_range(0.0, 0.06) = 0.014;
uniform float quantize_steps : hint_range(8.0, 128.0) = 36.0;
uniform float vignette : hint_range(0.0, 0.6) = 0.14;
uniform float ca_strength : hint_range(0.0, 0.02) = 0.0;
uniform float streak : hint_range(0.0, 1.0) = 0.0;

uniform float stack = 0.0;
uniform float bloom_strength = 0.0;
uniform float dof_strength = 0.0;
uniform float dof_near = 36.0;
uniform float dof_far = 200.0;
uniform float shaft_strength = 0.0;
uniform vec2 sun_uv = vec2(2.0, 2.0);
uniform float sun_on = 0.0;
uniform float deflicker = 0.0;
uniform float chroma = 0.0;
uniform float crt = 0.0;
uniform float cabin = 0.0;
uniform float cabin_bloom = 0.1;
uniform float cabin_deflicker = 0.16;
uniform float cabin_chroma = 0.2;
uniform float cabin_crt = 0.22;
uniform float cabin_shafts = 0.18;
uniform vec2 pixel_size = vec2(0.0013, 0.0023);
uniform vec3 cam_pos = vec3(0.0);
uniform vec3 cam_fwd = vec3(0.0, 0.0, -1.0);
uniform vec3 cam_right = vec3(1.0, 0.0, 0.0);
uniform vec3 cam_up = vec3(0.0, 1.0, 0.0);
uniform float cam_fov = 52.0;
uniform vec3 focus_pos = vec3(0.0);
uniform float focus_radius = 4.0;
uniform vec3 planet_pos = vec3(0.0);
uniform float planet_radius = 24.0;

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

float bayer_at(vec2 pixel) {
	ivec2 ip = ivec2(floor(pixel));
	return BAYER[ip.x & 3][ip.y & 3];
}

vec3 sample_scene(vec2 uv) {
	if (ca_strength > 0.00001) {
		vec2 shift = (uv - 0.5) * ca_strength;
		vec3 col;
		col.r = texture(screen_tex, uv + shift).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - shift).b;
		return col;
	}
	return texture(screen_tex, uv).rgb;
}

vec3 bright(vec3 c) {
	float l = max(c.r, max(c.g, c.b));
	return c * smoothstep(0.8, 1.15, l);
}

vec3 kawase(vec2 uv, float radius) {
	vec2 o = pixel_size * radius;
	vec3 s = bright(texture(screen_tex, uv + vec2(-o.x, -o.y)).rgb);
	s += bright(texture(screen_tex, uv + vec2(o.x, -o.y)).rgb);
	s += bright(texture(screen_tex, uv + vec2(-o.x, o.y)).rgb);
	s += bright(texture(screen_tex, uv + vec2(o.x, o.y)).rgb);
	return s * 0.25;
}

float ray_sphere(vec3 ro, vec3 rd, vec3 center, float radius) {
	vec3 oc = ro - center;
	float b = dot(oc, rd);
	float h = b * b - (dot(oc, oc) - radius * radius);
	if (h < 0.0) {
		return -1.0;
	}
	return -b - sqrt(h);
}

float focus_amount(vec2 uv) {
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	float half_y = tan(radians(cam_fov) * 0.5);
	float half_x = half_y * (pixel_size.y / max(pixel_size.x, 0.00001));
	vec3 rd = normalize(cam_fwd + cam_right * ndc.x * half_x + cam_up * ndc.y * half_y);
	float ship_t = ray_sphere(cam_pos, rd, focus_pos, focus_radius);
	if (ship_t > 0.0) {
		return 0.0;
	}
	float planet_t = ray_sphere(cam_pos, rd, planet_pos, planet_radius);
	float dist = planet_t > 0.0 ? planet_t : dof_far;
	return smoothstep(dof_near, dof_far, dist);
}

vec3 apply_spatial(vec3 col, vec2 uv) {
	float cab = clamp(cabin, 0.0, 1.0);
	if (bloom_strength > 0.001) {
		vec2 texel = pixel_size * 4.0;
		vec2 base = (floor(uv / texel) + 0.5) * texel;
		vec3 glow = kawase(base, 2.5) * 0.58 + kawase(base, 7.0) * 0.42;
		col += glow * bloom_strength * mix(1.0, cabin_bloom, cab);
	}
	if (dof_strength > 0.001) {
		float coc = focus_amount(uv) * dof_strength;
		if (coc > 0.04) {
			vec2 px = pixel_size * (1.0 + coc * 5.0);
			vec3 acc = col;
			acc += texture(screen_tex, uv + vec2(px.x, 0.0)).rgb;
			acc += texture(screen_tex, uv - vec2(px.x, 0.0)).rgb;
			acc += texture(screen_tex, uv + vec2(0.0, px.y)).rgb;
			acc += texture(screen_tex, uv - vec2(0.0, px.y)).rgb;
			col = mix(col, acc * 0.2, clamp(coc, 0.0, 0.65));
		}
	}
	if (shaft_strength > 0.001 && sun_on > 0.5) {
		vec2 to_sun = sun_uv - uv;
		vec2 stepv = to_sun * 0.11;
		vec3 acc = vec3(0.0);
		float fall = 1.0;
		vec2 p = uv;
		for (int i = 0; i < 8; i++) {
			p += stepv;
			vec3 lit = texture(screen_tex, clamp(p, vec2(0.001), vec2(0.999))).rgb;
			float l = max(lit.r, max(lit.g, lit.b));
			acc += lit * smoothstep(0.55, 0.95, l) * fall;
			fall *= 0.82;
		}
		float reach = smoothstep(1.15, 0.0, length(to_sun));
		float amt = shaft_strength * mix(1.0, cabin_shafts, cab);
		col += acc * amt * reach * 0.55;
	}
	return col;
}

vec3 crushed(vec2 uv) {
	vec3 c = texture(screen_tex, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
	float steps = max(quantize_steps, 2.0);
	float bayer = bayer_at(uv / pixel_size);
	c += (bayer - 0.5) / steps;
	return floor(clamp(c, 0.0, 1.0) * steps) / steps;
}

vec3 film_grade(vec3 col, vec2 uv, vec2 frag_px, float time) {
	ivec2 pixel = ivec2(floor(frag_px));
	float bayer = BAYER[pixel.x & 3][pixel.y & 3];
	float steps = max(quantize_steps, 2.0);
	col += (bayer - 0.5) / steps;
	col = floor(clamp(col, 0.0, 1.0) * steps) / steps;
	col += (bayer - 0.5) * dither_strength;
	float tick = floor(time * 12.0);
	float grain = hash12(vec2(pixel) + vec2(tick, tick * 0.37)) - 0.5;
	col += grain * grain_strength;
	vec2 p = uv * 2.0 - 1.0;
	if (streak > 0.001) {
		vec2 dir = (uv - 0.5) * streak * 0.01;
		vec3 smear = col + texture(screen_tex, uv + dir).rgb + texture(screen_tex, uv + dir * 2.0).rgb;
		float edge = smoothstep(0.2, 1.05, length(p));
		col = mix(col, smear / 3.0, edge * streak);
	}
	float vig = smoothstep(1.2, 0.25, dot(p, p));
	col *= mix(1.0 - vignette, 1.0, vig);
	return col;
}

vec3 apply_finish(vec3 col, vec2 uv, float frag_x, float frag_y) {
	float cab = clamp(cabin, 0.0, 1.0);
	float defl = deflicker * mix(1.0, cabin_deflicker, cab);
	if (defl > 0.001) {
		// GameCube copy-filter weights, about 21/64, 22/64, 21/64.
		vec3 up = crushed(uv + vec2(0.0, -pixel_size.y));
		vec3 dn = crushed(uv + vec2(0.0, pixel_size.y));
		vec3 blended = up * 0.328125 + col * 0.34375 + dn * 0.328125;
		col = mix(col, blended, defl);
	}
	float cable = chroma * mix(1.0, cabin_chroma, cab);
	if (cable > 0.001) {
		vec3 left = crushed(uv + vec2(pixel_size.x * 1.6, 0.0));
		vec3 right = crushed(uv - vec2(pixel_size.x * 1.6, 0.0));
		vec3 bled = col;
		bled.r = mix(col.r, right.r, 0.62);
		bled.b = mix(col.b, left.b, 0.62);
		bled.g = mix(col.g, (left.g + right.g) * 0.5, 0.16);
		col = mix(col, bled, cable);
	}
	float mask_amt = crt * mix(1.0, cabin_crt, cab);
	if (mask_amt > 0.001) {
		float line = step(0.5, fract(frag_y * 0.5));
		float scan = mix(0.76, 1.0, line);
		float column = mod(frag_x, 3.0);
		float aperture = 0.93 + 0.07 * step(2.0, column);
		col *= mix(1.0, scan * aperture, mask_amt);
	}
	return col;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = sample_scene(uv);
	if (stack > 0.5) {
		col = apply_spatial(col, uv);
	}
	col = film_grade(col, uv, FRAGCOORD.xy, TIME);
	if (stack > 0.5) {
		col = apply_finish(col, uv, FRAGCOORD.x, FRAGCOORD.y);
	}
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
