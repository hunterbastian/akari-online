shader_type canvas_item;
render_mode blend_mix, unshaded;

// Helmet glass over the filmed view. The world stays pixel-graded underneath.
// drop is 0 with the visor raised and 1 when the plate has come down.
// whiteout is the airlock breath that hides the cabin-to-hull layer change.
// The plate does not recopy the screen. A screen sample feedbacks into rings.

uniform float drop = 0.0;
uniform float fog = 0.0;
uniform float breath = 0.0;
uniform float whiteout = 0.0;
uniform float allow_fog = 1.0;
uniform float allow_reflect = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - vec2(0.5, 0.46)) * vec2(1.02, 1.16);
	float r = length(p);
	float edge = mix(-0.22, 1.18, drop);
	float covered = 1.0 - smoothstep(edge - 0.03, edge + 0.055, uv.y);
	float rim = smoothstep(0.3, 0.9, r);
	float lip = smoothstep(0.6, 0.99, r);

	float pulse = 0.5 + 0.5 * sin(breath * 2.244);
	float cond = allow_fog * fog * (0.28 + 0.72 * pulse) * smoothstep(0.18, 0.82, r);

	float scuff = smoothstep(0.997, 1.0, sin(p.x * 37.0 + p.y * 9.0 + hash12(floor(p * 18.0)) * 2.0));
	scuff += smoothstep(0.998, 1.0, sin(p.y * 51.0 - p.x * 6.0)) * 0.35;
	float glint = allow_reflect * covered * smoothstep(0.55, 0.2, length(p - vec2(-0.22, 0.18)));

	vec3 helmet = vec3(0.01, 0.012, 0.014);
	vec3 glass = mix(vec3(0.62, 0.74, 0.68), helmet, smoothstep(0.45, 1.0, r));
	glass += vec3(0.8, 0.92, 0.86) * (scuff * 0.35 + glint * 0.08);
	vec3 frost = vec3(0.62, 0.7, 0.74);
	glass = mix(glass, frost, whiteout);
	float alpha = covered * (0.018 + rim * 0.28 + lip * 0.78 + cond * 0.16 + glint * 0.04);
	alpha = mix(alpha, 1.0, whiteout);
	COLOR = vec4(glass, alpha);
}
