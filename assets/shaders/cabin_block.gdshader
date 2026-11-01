shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;

// Flat 2012 face light, times a per-vertex ambient occlusion baked from neighbors.
// A ceiling spot on high quality darkens this further; the sun is ignored.

uniform sampler2D albedo_tex : filter_nearest, repeat_enable;
uniform float lamp = 0.0;

varying float v_ao;

const mat4 BAYER = mat4(
	vec4(0.0, 12.0, 3.0, 15.0),
	vec4(8.0, 4.0, 11.0, 7.0),
	vec4(2.0, 14.0, 1.0, 13.0),
	vec4(10.0, 6.0, 9.0, 5.0)
) / 16.0;

void vertex() {
	v_ao = COLOR.r;
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
