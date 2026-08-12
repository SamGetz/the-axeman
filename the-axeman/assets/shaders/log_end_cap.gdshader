shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// One centred growth-ring image per authored trunk or branch end. The end UV
// island is intentionally planar and non-repeating; runtime fresh cuts continue
// to use the separate inside material supplied to MeshSlicer.
uniform sampler2D end_texture : source_color, repeat_disable, filter_linear_mipmap_anisotropic;
uniform vec4 end_tint : source_color = vec4(1.0);
uniform float edge_warmth : hint_range(0.0, 0.35, 0.01) = 0.08;

// See log_bark_triplanar.gdshader. This material does not consume the value, but
// matching declarations keep the per-instance parameter valid on multi-surface
// log meshes.
instance uniform vec3 projection_offset : instance_index(0) = vec3(0.0);


void fragment() {
	vec3 color = texture(end_texture, UV).rgb * end_tint.rgb;
	float radius = length(UV - vec2(0.5)) / 0.5;
	color *= mix(vec3(1.0), vec3(0.78, 0.60, 0.42),
		smoothstep(1.0 - edge_warmth, 1.0, radius));
	ALBEDO = color;
	ROUGHNESS = 0.92;
	SPECULAR = 0.16;
}
