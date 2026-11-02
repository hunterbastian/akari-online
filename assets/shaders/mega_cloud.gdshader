shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform sampler2D cloud_tex : filter_linear, repeat_enable;
uniform vec4 cloud_color : source_color = vec4(0.93, 0.9, 0.86, 1.0);
uniform float cloud_alpha = 0.45;

void fragment() {
	float puff = texture(cloud_tex, UV * 2.0).r;
	float edge = smoothstep(0.72, 0.18, length(UV - vec2(0.5)));
	float alpha = smoothstep(0.32, 0.7, puff) * cloud_alpha * edge;
	ALBEDO = cloud_color.rgb;
	ALPHA = alpha;
}
