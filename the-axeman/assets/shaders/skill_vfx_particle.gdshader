shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

// Shared particle language for procs, XP pickups, and level-up. Small physical
// particles may carry restrained ordered breakup; glow layers pass 0.0 and are
// deliberately smooth.
uniform vec4 edge_color : source_color = vec4(1.0, 0.12, 0.02, 0.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.82, 0.34, 1.0);
uniform int shape_mode : hint_range(0, 2, 1) = 0; // round, streak, diamond
uniform float softness : hint_range(0.02, 0.98) = 0.58;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.0;
uniform float dither_pixel_size : hint_range(0.5, 5.0) = 1.0;


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


void vertex() {
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


void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float field = length(p);
	if (shape_mode == 1) {
		field = length(vec2(p.x, p.y * 1.42));
	} else if (shape_mode == 2) {
		field = abs(p.x) + abs(p.y);
	}

	float alpha = 1.0 - smoothstep(max(0.02, 1.0 - softness), 1.0, field);
	float centre = 1.0 - smoothstep(0.0, 0.88, field);
	vec3 color = mix(edge_color.rgb, core_color.rgb, pow(centre, 0.72));

	// Dithering is optional by design. Glow/core/halo materials pass zero, so no
	// ordered coverage or tone can leak into their soft falloff.
	if (dither_strength > 0.001) {
		float threshold = bayer_4x4(FRAGCOORD.xy / max(dither_pixel_size, 0.5));
		float ordered = step(threshold, clamp(alpha * 1.08, 0.0, 1.0));
		float edge_mix = dither_strength * (1.0 - smoothstep(0.20, 0.82, alpha));
		alpha = mix(alpha, ordered, max(dither_strength * 0.14, edge_mix));
		float tone = mix(0.68, 1.06, step(threshold, 0.70));
		color *= mix(1.0, tone, dither_strength * 0.34);
	}

	float coverage = alpha * mix(edge_color.a, core_color.a, centre) * COLOR.a;

	// ADDITIVE BLEND CONTRACT: fade RGB to black with the sprite coverage, not
	// only ALPHA. Additive surfaces contribute their colour to the framebuffer;
	// leaving RGB populated in nominally transparent corners exposes the QuadMesh
	// as a faint rectangular card. XPOrb's halo and the grain-cue glow follow the
	// same rule. Carrying the falloff in both channels keeps these particles round
	// through the painterly post-process and on Compatibility renderers.
	ALBEDO = color * COLOR.rgb * coverage;
	ALPHA = coverage;
}
