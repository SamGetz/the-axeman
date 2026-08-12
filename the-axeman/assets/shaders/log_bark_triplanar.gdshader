shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Live UV-free bark projection. The scale is supplied by SpeciesDef and remains
// explicitly placeholder tuning until the complete species set is art-directed.
uniform sampler2D bark_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 bark_tint : source_color = vec4(1.0);
uniform float projection_scale : hint_range(0.25, 24.0, 0.05) = 1.8;
uniform float blend_sharpness : hint_range(1.0, 16.0, 0.25) = 6.0;

// Sliced meshes are recentered around each descendant. Keeping the accumulated
// old-local centre per MeshInstance makes the bark stay fixed across that cut.
// The authored-end shader declares the same name/type/index because Godot shares
// one per-instance parameter list across every material on a MeshInstance3D.
instance uniform vec3 projection_offset : instance_index(0) = vec3(0.0);

varying vec3 local_position;
varying vec3 local_normal;


void vertex() {
	local_position = VERTEX + projection_offset;
	local_normal = NORMAL;
}


vec3 triplanar_bark(vec3 position, vec3 normal) {
	vec3 weights = pow(abs(normalize(normal)), vec3(blend_sharpness));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);

	// X and Z projections both keep object Y on texture Y, so upright trunk
	// bark retains one readable grain direction instead of rotating at corners.
	vec2 uv_x = vec2(position.z, position.y) * projection_scale;
	vec2 uv_y = vec2(position.x, position.z) * projection_scale;
	vec2 uv_z = vec2(position.x, position.y) * projection_scale;
	vec3 sample_x = texture(bark_texture, uv_x).rgb;
	vec3 sample_y = texture(bark_texture, uv_y).rgb;
	vec3 sample_z = texture(bark_texture, uv_z).rgb;
	return sample_x * weights.x + sample_y * weights.y + sample_z * weights.z;
}


void fragment() {
	ALBEDO = triplanar_bark(local_position, local_normal) * bark_tint.rgb;
	ROUGHNESS = 0.88;
	SPECULAR = 0.20;
}
