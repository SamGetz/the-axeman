shader_type spatial;
render_mode unshaded, cull_disabled;

// Leaf-canopy cutout: this instance never draws in the color pass
// (MeshInstance3D.cast_shadow = SHADOWS_ONLY on the node that uses it) — the
// only thing that matters is ALPHA feeding the shadow pass's alpha-scissor
// test, which stencils the light into a dappled leaf pattern.
uniform sampler2D gobo_tex : source_color, repeat_enable;
uniform float tile_scale = 3.0;
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec3 tex_col = texture(gobo_tex, UV * tile_scale + uv_offset).rgb;
	// Source texture is bright where light passes between leaves, dark where
	// a leaf/branch blocks it — so occluder opacity is the INVERSE of luminance.
	float lum = dot(tex_col, vec3(0.299, 0.587, 0.114));
	ALBEDO = vec3(0.0);
	ALPHA = 1.0 - lum;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
