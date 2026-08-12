shader_type canvas_item;
render_mode unshaded;

// Samples the completed 3D Action_Viewport. The production HUD is drawn later
// by its sibling CanvasLayer, so its text and icons stay full-colour and crisp.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// These defaults are mirrored by the labelled placeholder material resource.
uniform float pixel_block_size : hint_range(1.0, 8.0, 1.0) = 3.0;
uniform float color_levels : hint_range(2.0, 32.0, 1.0) = 16.0;
uniform float dither_strength : hint_range(0.0, 1.0, 0.05) = 0.0;
uniform float dither_pixel_size : hint_range(1.0, 4.0, 1.0) = 1.0;


float bayer_4x4(vec2 screen_pixel) {
	vec2 cell = mod(floor(screen_pixel / dither_pixel_size), 4.0);
	float value = 0.0;

	if (cell.y < 1.0) {
		if (cell.x < 1.0) { value = 0.0; }
		else if (cell.x < 2.0) { value = 8.0; }
		else if (cell.x < 3.0) { value = 2.0; }
		else { value = 10.0; }
	} else if (cell.y < 2.0) {
		if (cell.x < 1.0) { value = 12.0; }
		else if (cell.x < 2.0) { value = 4.0; }
		else if (cell.x < 3.0) { value = 14.0; }
		else { value = 6.0; }
	} else if (cell.y < 3.0) {
		if (cell.x < 1.0) { value = 3.0; }
		else if (cell.x < 2.0) { value = 11.0; }
		else if (cell.x < 3.0) { value = 1.0; }
		else { value = 9.0; }
	} else {
		if (cell.x < 1.0) { value = 15.0; }
		else if (cell.x < 2.0) { value = 7.0; }
		else if (cell.x < 3.0) { value = 13.0; }
		else { value = 5.0; }
	}

	// Centre each ordered threshold around zero so the effect does not bias the
	// scene brighter or darker overall.
	return (value + 0.5) / 16.0 - 0.5;
}


void fragment() {
	vec2 block = SCREEN_PIXEL_SIZE * pixel_block_size;
	vec2 sample_uv = (floor(SCREEN_UV / block) + 0.5) * block;
	sample_uv = clamp(sample_uv, block * 0.5, vec2(1.0) - block * 0.5);
	vec3 source = texture(screen_texture, sample_uv).rgb;
	float dither = bayer_4x4(FRAGCOORD.xy / pixel_block_size) * dither_strength;
	float steps = max(color_levels - 1.0, 1.0);
	vec3 color = floor(source * steps + 0.5 + dither) / steps;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
