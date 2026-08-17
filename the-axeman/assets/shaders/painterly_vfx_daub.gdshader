shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

// Shared world-space VFX language: opaque pigment, irregular silhouettes and
// small dry-brush gaps. This deliberately avoids screen-space projection and
// additive bloom, so the marks stay attached to the effect that spawned them.
uniform vec4 dark_color : source_color = vec4(0.22, 0.06, 0.02, 0.86);
uniform vec4 mid_color : source_color = vec4(0.82, 0.22, 0.05, 0.94);
uniform vec4 light_color : source_color = vec4(1.0, 0.64, 0.18, 0.98);
uniform int shape_mode : hint_range(0, 2, 1) = 0; // daub, dry slash, fleck
uniform bool billboard_enabled = true;
// Opt-in for real 3D tool meshes. The default keeps the existing painterly
// cutout language for quads/particles; action silhouettes need coherent faces.
uniform bool solid_geometry = false;
uniform float dry_amount : hint_range(0.0, 1.0) = 0.16;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;


float hash21(vec2 value) {
	vec3 p = fract(vec3(value.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33 + seed * 7.1);
	return fract((p.x + p.y) * p.z);
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
	vec2 p = UV * 2.0 - 1.0;
	float boundary = 0.0;
	float along = 0.0;
	if (shape_mode == 0) {
		float angle = atan(p.y, p.x);
		float wobble = sin(angle * 5.0 + seed * 2.7) * 0.075
			+ sin(angle * 9.0 - seed * 1.3) * 0.035;
		boundary = 1.0 - length(vec2(p.x, p.y * 1.08)) + wobble;
		along = p.x * 0.35 + p.y * 0.65;
	} else if (shape_mode == 1) {
		float taper = max(0.04, 1.0 - abs(p.x));
		float bristle_edge = taper * (0.40 + 0.16 * sin(p.x * 8.0 + seed));
		boundary = bristle_edge - abs(p.y);
		along = p.x;
	} else {
		vec2 q = vec2(p.x + p.y * 0.20, p.y - p.x * 0.12);
		boundary = 0.92 - (abs(q.x) + abs(q.y) * 1.08);
		boundary += sin((q.x - q.y) * 7.0 + seed) * 0.055;
		along = q.y;
	}

	float coverage = smoothstep(-0.025, 0.035, boundary);
	float edge_distance = smoothstep(0.00, 0.28, boundary);
	vec2 grain_cell = floor(vec2(UV.x * 27.0, UV.y * 13.0));
	float grain = hash21(grain_cell);
	float bristle_band = 0.5 + 0.5 * sin(
		p.y * 22.0 + p.x * 4.0 + seed * 3.0);
	float dry_gap = step(grain,
		dry_amount * (1.0 - edge_distance) * 0.48) * step(0.36, bristle_band);
	coverage *= 1.0 - dry_gap;
	if (solid_geometry) {
		coverage = 1.0;
		edge_distance = 1.0;
	}

	float centre = smoothstep(0.02, 0.58, boundary);
	float light_patch = smoothstep(0.38, 0.82,
		0.52 + along * 0.24 + hash21(floor(UV * 7.0)) * 0.34);
	vec3 pigment = mix(dark_color.rgb, mid_color.rgb,
		smoothstep(0.0, 0.52, edge_distance));
	pigment = mix(pigment, light_color.rgb, centre * light_patch * 0.78);
	float alpha = coverage * mix(dark_color.a, mid_color.a, edge_distance)
		* opacity * COLOR.a;
	ALBEDO = pigment * COLOR.rgb;
	ALPHA = alpha;
}
