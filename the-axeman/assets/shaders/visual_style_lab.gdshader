shader_type canvas_item;
render_mode unshaded;

// PROTOTYPE ONLY: screenshot exploration for visual direction selection. None
// of these candidate values are production tuning.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform int style_mode : hint_range(1, 4, 1) = 1;
uniform float chunky_block_size : hint_range(1.0, 8.0, 1.0) = 5.0;
uniform float chunky_color_levels : hint_range(4.0, 32.0, 1.0) = 10.0;


float bayer_4x4(vec2 pixel) {
	vec2 cell = mod(floor(pixel), 4.0);
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
	return (value + 0.5) / 16.0 - 0.5;
}


vec3 quantize(vec3 color, float levels, float dither) {
	float steps = max(levels - 1.0, 1.0);
	return clamp(floor(color * steps + 0.5 + dither) / steps,
		vec3(0.0), vec3(1.0));
}


float vignette(vec2 uv, float strength) {
	vec2 centred = uv * 2.0 - 1.0;
	float edge = dot(centred, centred);
	return 1.0 - smoothstep(0.28, 1.35, edge) * strength;
}


vec3 chunky_pixels(vec2 uv, vec2 texel) {
	vec2 block = texel * chunky_block_size;
	vec2 block_uv = (floor(uv / block) + 0.5) * block;
	vec3 color = texture(screen_texture, clamp(block_uv,
		block * 0.5, vec2(1.0) - block * 0.5)).rgb;
	return quantize(color, chunky_color_levels, 0.0);
}


vec3 autumn_storybook(vec3 source, vec2 uv, vec2 fragment_pixel) {
	float luma = dot(source, vec3(0.299, 0.587, 0.114));
	vec3 color = mix(vec3(luma), source, 0.88);
	color *= vec3(1.12, 1.02, 0.82);
	color = pow(clamp(color, vec3(0.0), vec3(1.0)), vec3(0.88));
	color = mix(color, vec3(0.92, 0.58, 0.27), 0.055);
	color = quantize(color, 11.0, bayer_4x4(fragment_pixel) * 0.25);
	return color * vignette(uv, 0.24);
}


vec3 woodcut_print(vec3 source, vec2 fragment_pixel) {
	float luma = dot(source, vec3(0.299, 0.587, 0.114));
	float ordered = bayer_4x4(floor(fragment_pixel / 2.0));
	float diagonal = step(0.56, fract((fragment_pixel.x + fragment_pixel.y) / 7.0));
	float crossline = step(0.72, fract((fragment_pixel.x - fragment_pixel.y) / 11.0));
	float hatch = mix(diagonal, max(diagonal, crossline),
		smoothstep(0.20, 0.62, 1.0 - luma));
	float printed = floor(clamp(luma * 4.0 + 0.90 + ordered * 0.65
		- hatch * (1.0 - luma) * 0.30, 0.0, 4.0)) / 4.0;
	vec3 ink = vec3(0.105, 0.055, 0.028);
	vec3 paper = vec3(0.93, 0.77, 0.49);
	return mix(ink, paper, printed);
}


vec3 miniature_diorama(vec2 uv, vec2 texel) {
	float focus_distance = abs(uv.y - 0.57);
	float blur = smoothstep(0.17, 0.43, focus_distance);
	vec2 radius = texel * mix(1.0, 11.0, blur);
	vec3 color = texture(screen_texture, uv).rgb * 0.36;
	color += texture(screen_texture, clamp(uv + vec2(radius.x, 0.0), vec2(0.0), vec2(1.0))).rgb * 0.13;
	color += texture(screen_texture, clamp(uv - vec2(radius.x, 0.0), vec2(0.0), vec2(1.0))).rgb * 0.13;
	color += texture(screen_texture, clamp(uv + vec2(0.0, radius.y), vec2(0.0), vec2(1.0))).rgb * 0.13;
	color += texture(screen_texture, clamp(uv - vec2(0.0, radius.y), vec2(0.0), vec2(1.0))).rgb * 0.13;
	color += texture(screen_texture, clamp(uv + radius, vec2(0.0), vec2(1.0))).rgb * 0.06;
	color += texture(screen_texture, clamp(uv - radius, vec2(0.0), vec2(1.0))).rgb * 0.06;
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luma), color, 1.28);
	color = (color - 0.5) * 1.08 + 0.5;
	color *= vec3(1.06, 1.015, 0.92);
	return clamp(color * vignette(uv, 0.34), vec3(0.0), vec3(1.0));
}


void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec3 styled = source;
	if (style_mode == 1) {
		styled = chunky_pixels(SCREEN_UV, SCREEN_PIXEL_SIZE);
	} else if (style_mode == 2) {
		styled = autumn_storybook(source, SCREEN_UV, FRAGCOORD.xy);
	} else if (style_mode == 3) {
		styled = woodcut_print(source, FRAGCOORD.xy);
	} else if (style_mode == 4) {
		styled = miniature_diorama(SCREEN_UV, SCREEN_PIXEL_SIZE);
	}
	COLOR = vec4(styled, 1.0);
}
