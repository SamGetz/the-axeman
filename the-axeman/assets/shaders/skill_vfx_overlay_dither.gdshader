shader_type canvas_item;
render_mode unshaded;

// Dithered screen pulse shared by skill procs and the level-up crown. This is
// an effect-local mask, not a grade over the underlying game scene.
uniform vec4 tint : source_color = vec4(1.0);
uniform float intensity = 0.0;
uniform float center_weight = 0.0;
uniform int mask_mode : hint_range(0, 1, 1) = 0;
uniform int dither_mode : hint_range(1, 4, 1) = 1;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.75;
uniform float dither_pixel_size : hint_range(1.0, 6.0) = 2.0;
uniform float directional_bias : hint_range(0.0, 1.0) = 0.0;
uniform vec2 effect_center = vec2(0.5, 0.54);


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
	return (value + 0.5) / 16.0;
}


void fragment() {
	vec2 p = (UV - effect_center) * vec2(1.0, 0.72);
	float distance_from_center = length(p);
	float mask = 0.0;
	if (mask_mode == 0) {
		float center = 1.0 - smoothstep(0.02, 0.28, distance_from_center);
		float local_ring = smoothstep(0.06, 0.13, distance_from_center)
			* (1.0 - smoothstep(0.20, 0.30, distance_from_center));
		mask = mix(local_ring, center, center_weight);
	} else {
		float lift = (1.0 - smoothstep(0.06, 0.34, distance_from_center))
			* (1.0 - smoothstep(0.18, 0.98, UV.y));
		mask = lift;
	}

	vec2 pattern_pixel = FRAGCOORD.xy;
	if (dither_mode == 2) {
		pattern_pixel = vec2(
			FRAGCOORD.x + FRAGCOORD.y * directional_bias,
			FRAGCOORD.y * mix(1.0, 0.55, directional_bias));
	} else if (dither_mode == 3) {
		pattern_pixel = vec2(
			FRAGCOORD.x + FRAGCOORD.y * 0.28,
			FRAGCOORD.y - FRAGCOORD.x * 0.14);
	}
	float threshold = bayer_4x4(pattern_pixel / max(dither_pixel_size, 1.0));
	float smooth_value = mask * intensity;
	float coverage = step(threshold, clamp(smooth_value * 3.2, 0.0, 1.0));
	float dotted_value = coverage * min(1.0, intensity * 2.6);
	float value = mix(smooth_value, dotted_value, dither_strength);
	COLOR = vec4(tint.rgb * value, tint.a * value);
}
