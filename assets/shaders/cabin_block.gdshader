shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;

// Flat 2012 face light, times a per-vertex ambient occlusion baked from neighbors.
// A ceiling spot on high quality darkens this further; the sun is ignored.

uniform sampler2D albedo_tex : filter_nearest, repeat_enable;
uniform float lamp = 0.0;
uniform vec3 lamp_tint = vec3(1.0);
uniform float lamp_gain = 1.0;

varying float v_ao;
varying float v_nose;

const mat4 BAYER = mat4(
	vec4(0.0, 12.0, 3.0, 15.0),
	vec4(8.0, 4.0, 11.0, 7.0),
	vec4(2.0, 14.0, 1.0, 13.0),
	vec4(10.0, 6.0, 9.0, 5.0)
) / 16.0;

void vertex() {
	v_ao = COLOR.r;
	v_nose = COLOR.g;
}

void fragment() {
	vec3 tex = texture(albedo_tex, UV).rgb;
	vec3 n = normalize(inverse(mat3(VIEW_MATRIX * MODEL_MATRIX)) * NORMAL);
	float shade = 0.75;
	if (n.y > 0.5) {
		shade = 1.0;
	} else if (n.y < -0.5) {
		shade = 0.45;
	} else if (abs(n.x) > 0.5) {
		shade = 0.55;
	}
	vec3 col = tex * shade * v_ao;
	// Flat zones, not light pools: window is brighter and cooler, lamps are warm,
	// and the CRTs spill a little green onto whatever is next to them.
	float warm = clamp(COLOR.b, 0.0, 1.0);
	float crt = clamp(COLOR.a, 0.0, 1.0);
	float zone = mix(0.56, 1.14, v_nose) * mix(0.78, 1.18, warm);
	vec3 tint = mix(vec3(0.9, 0.87, 0.82), vec3(1.06, 0.97, 0.84), warm);
	tint = mix(tint, vec3(0.84, 0.94, 1.06), v_nose * 0.6);
	tint = mix(tint, vec3(0.72, 1.0, 0.78), crt * 0.42);
	col *= zone * tint * lamp_tint * lamp_gain;
	float core = smoothstep(0.78, 0.96, max(tex.r, max(tex.g, tex.b)));
	col += vec3(1.0, 0.78, 0.45) * core * lamp;
	ALBEDO = col;
	EMISSION = col;
}

void light() {
	// The world sun is directional. Only the cabin spot should shade.
	float gate = LIGHT_IS_DIRECTIONAL ? 0.0 : 1.0;
	float shadow = clamp(ATTENUATION, 0.0, 1.0);
	ivec2 pixel = ivec2(floor(FRAGCOORD.xy));
	float bayer = BAYER[pixel.x & 3][pixel.y & 3];
	float hard = step(bayer * 0.35, shadow);
	DIFFUSE_LIGHT += -ALBEDO * (1.0 - hard) * 0.48 * gate;
}
