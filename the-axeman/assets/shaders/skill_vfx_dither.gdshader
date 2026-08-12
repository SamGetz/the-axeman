shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

// Branch-specific ordered dithering for skill procs and level-up celebration.
// Presentation only; all feel values come from skill_vfx_config.tres.
uniform sampler2D effect_texture : source_color, hint_default_white, filter_nearest, repeat_disable;
uniform vec4 effect_color : source_color = vec4(1.0);
uniform vec4 highlight_color : source_color = vec4(1.0);
uniform int dither_mode : hint_range(1, 4, 1) = 1;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.75;
uniform float dither_pixel_size : hint_range(1.0, 6.0) = 2.0;
uniform float core_cleanliness : hint_range(0.05, 1.0) = 0.75;
uniform float directional_bias : hint_range(0.0, 1.0) = 0.0;
uniform float geometry_gradient_strength : hint_range(0.0, 1.0) = 0.68;
// 0 rectangle, 1 closed band, 2 open strip, 3 triangle face, 4 curved volume.
uniform int gradient_mode : hint_range(0, 4, 1) = 0;
uniform bool billboard_enabled = true;


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


vec3 quantize(vec3 color, float levels, float bias) {
	float steps = max(levels - 1.0, 1.0);
	return clamp(floor(color * steps + bias) / steps,
		vec3(0.0), vec3(1.0));
}


float geometry_side_gradient(vec2 uv, vec3 normal, vec3 view, int mode) {
	if (mode == 1) {
		// Closed rings have only inner/outer boundaries; treating their UV seam as
		// an edge would draw one arbitrary dark cut through the circle.
		float band_edge = min(uv.x, 1.0 - uv.x);
		return smoothstep(0.0, 0.48, max(band_edge, 0.0));
	}
	if (mode == 2) {
		// Arc and ribbon strips graduate inward from both rails and both ends.
		float strip_edge = min(min(uv.x, 1.0 - uv.x),
			min(uv.y, 1.0 - uv.y));
		return smoothstep(0.0, 0.34, max(strip_edge, 0.0));
	}
	if (mode == 3) {
		// Every generated triangle is mapped tip-to-base, so all three real sides
		// receive the ramp instead of the bounds of an enclosing rectangle.
		float left_edge = uv.x - 0.5 * (1.0 - uv.y);
		float right_edge = (0.5 + 0.5 * uv.y) - uv.x;
		float base_edge = 1.0 - uv.y;
		float triangle_edge = min(base_edge, min(left_edge, right_edge));
		return smoothstep(0.0, 0.30, max(triangle_edge, 0.0));
	}
	if (mode == 4) {
		// Volumes such as XP-orb bodies ramp from every silhouette toward the
		// view-facing centre, so the gradient wraps rather than exposing a UV seam.
		float facing = abs(dot(normalize(normal), normalize(view)));
		return smoothstep(0.08, 0.92, facing);
	}
	float rectangle_edge = min(min(uv.x, 1.0 - uv.x),
		min(uv.y, 1.0 - uv.y));
	return smoothstep(0.0, 0.42, max(rectangle_edge, 0.0));
}


void vertex() {
	if (billboard_enabled) {
		vec3 keep_scale = vec3(
			length(MODEL_MATRIX[0].xyz),
			length(MODEL_MATRIX[1].xyz),
			length(MODEL_MATRIX[2].xyz));
		mat4 billboard_model = mat4(
			vec4(INV_VIEW_MATRIX[0].xyz * keep_scale.x, 0.0),
			vec4(INV_VIEW_MATRIX[1].xyz * keep_scale.y, 0.0),
			vec4(INV_VIEW_MATRIX[2].xyz * keep_scale.z, 0.0),
			MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * billboard_model;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}


void fragment() {
	vec4 base = texture(effect_texture, UV) * effect_color * COLOR;
	float opacity_energy = smoothstep(0.04, 1.0, base.a);
	vec3 palette = effect_color.rgb * mix(0.48, 1.12, opacity_energy);
	float side_gradient = geometry_side_gradient(UV, NORMAL, VIEW, gradient_mode);
	vec3 gradient_edge = effect_color.rgb * 0.42;
	vec3 gradient_center = mix(effect_color.rgb * 1.08,
		highlight_color.rgb, 0.46);
	vec3 gradient_palette = mix(gradient_edge, gradient_center, side_gradient);
	palette = mix(palette, gradient_palette, geometry_gradient_strength);
	float hot_core = smoothstep(0.78, 1.0,
		max(base.r, max(base.g, base.b))) * smoothstep(0.86, 1.0, base.a);
	// Preserve the branch hue; white is a small hot-core accent, not the palette.
	palette = mix(palette, highlight_color.rgb, hot_core * 0.28);

	vec2 pattern_pixel = FRAGCOORD.xy / max(dither_pixel_size, 1.0);
	if (dither_mode == 2) {
		// Speed: shear and compress the grid into the direction of the swing.
		pattern_pixel = vec2(
			FRAGCOORD.x + FRAGCOORD.y * directional_bias,
			FRAGCOORD.y * mix(1.0, 0.55, directional_bias))
			/ max(dither_pixel_size, 1.0);
	} else if (dither_mode == 3) {
		// EXP: a softer rotated dissolve rather than a forceful screen-aligned grid.
		pattern_pixel = vec2(
			FRAGCOORD.x + FRAGCOORD.y * 0.28,
			FRAGCOORD.y - FRAGCOORD.x * 0.14)
			/ max(dither_pixel_size, 1.0);
	}
	float threshold = bayer_4x4(pattern_pixel);
	float edge = 1.0 - smoothstep(0.18, core_cleanliness, base.a);
	float pattern_amount = dither_strength * edge;
	float interior_pattern = min(1.0, dither_strength * 1.10);
	if (dither_mode == 1) {
		// Strength carries the coarsest breakup through wedges, both shock rings,
		// sparks and the contact core—not only their feathered edges.
		pattern_amount = max(pattern_amount, dither_strength * 0.65);
		interior_pattern = min(1.0, dither_strength * 1.25);
	} else if (dither_mode == 2) {
		// Keep the full axe-swipe geometry and every trailing streak visibly ordered.
		pattern_amount = max(pattern_amount, dither_strength * 0.52);
		interior_pattern = min(1.0, dither_strength * 1.15);
	} else if (dither_mode == 3) {
		// EXP is softer than Strength, but its ribbons, motes, rings, orb bodies and
		// halos still retain a visible pattern through their opaque interiors.
		pattern_amount = max(pattern_amount * 0.72, dither_strength * 0.46);
		interior_pattern = min(1.0, dither_strength * 1.10);
	} else if (dither_mode == 4) {
		// The crown stays bright without exempting its rays, sparks or hot core.
		pattern_amount = max(pattern_amount * edge, dither_strength * 0.42);
		interior_pattern = min(1.0, dither_strength * 1.10);
	}

	// A slightly lowered interior coverage ensures even a fully opaque input has
	// ordered breakup. `core_cleanliness` protects readability, not smooth pixels.
	float coverage_alpha = base.a * mix(0.74, 0.92, core_cleanliness);
	float ordered_alpha = step(threshold, clamp(coverage_alpha, 0.0, 1.0));
	float alpha = mix(base.a, ordered_alpha, clamp(pattern_amount, 0.0, 1.0));
	float color_levels = dither_mode == 1 ? 7.0 : (dither_mode == 2 ? 10.0 : 13.0);
	// Five cells in each 4x4 block become unmistakably dark. This is what keeps
	// small opaque elements (notably the swipe body and XP-orb cores) from
	// reading as smooth additive white while the surrounding falloff is dithered.
	float ordered_tone = mix(0.14, 1.08, step(threshold, 0.68));
	vec3 patterned_palette = mix(palette, palette * ordered_tone,
		clamp(interior_pattern, 0.0, 1.0));
	vec3 color = quantize(patterned_palette, color_levels,
		threshold * pattern_amount * 0.68 + 0.35);

	ALBEDO = color;
	ALPHA = alpha;
}
