shader_type spatial;
render_mode unshaded, shadows_disabled, ambient_light_disabled;

// 2012 Minecraft face light: top full, Z sides 80%, X sides 60%, bottom 50%.
// A soft darkening in the corners of each block tile, like smooth lighting.

uniform sampler2D albedo_tex : filter_nearest, repeat_enable;
uniform float lamp = 0.0;

void fragment() {
	vec3 tex = texture(albedo_tex, UV).rgb;
	vec3 n = normalize(inverse(mat3(VIEW_MATRIX * MODEL_MATRIX)) * NORMAL);
	float shade = 0.8;
	if (n.y > 0.5) {
		shade = 1.0;
	} else if (n.y < -0.5) {
		shade = 0.5;
	} else if (abs(n.x) > 0.5) {
		shade = 0.6;
	}
	vec2 cell = fract(UV);
	vec2 edge = min(cell, vec2(1.0) - cell);
	float corner = min(edge.x, edge.y);
	float ao = mix(0.78, 1.0, smoothstep(0.0, 0.2, corner));
	vec3 col = tex * shade * ao;
	float core = smoothstep(0.78, 0.96, max(tex.r, max(tex.g, tex.b)));
	col += vec3(1.0, 0.78, 0.45) * core * lamp;
	ALBEDO = col;
}
