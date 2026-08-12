shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;

// Uses the camera depth buffer to increase pixel size with world distance.
// Mounted on a fullscreen camera quad before transparent cues and the base
// 3-pixel CanvasItem pass.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float gradient_near_distance : hint_range(0.1, 20.0, 0.1) = 2.0;
uniform float gradient_far_distance : hint_range(0.1, 40.0, 0.1) = 9.0;
uniform float near_pixel_block_size : hint_range(1.0, 12.0, 1.0) = 3.0;
uniform float far_pixel_block_size : hint_range(1.0, 12.0, 1.0) = 7.0;


void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}


void fragment() {
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float linear_depth = -view.z / view.w;
	float distance_mix = smoothstep(
		gradient_near_distance, gradient_far_distance, linear_depth);
	float block_size = mix(
		near_pixel_block_size, far_pixel_block_size, distance_mix);
	vec2 block = vec2(block_size) / VIEWPORT_SIZE;
	vec2 block_uv = (floor(SCREEN_UV / block) + 0.5) * block;
	block_uv = clamp(block_uv, block * 0.5, vec2(1.0) - block * 0.5);
	ALBEDO = textureLod(screen_texture, block_uv, 0.0).rgb;
	ALPHA = 1.0;
}
