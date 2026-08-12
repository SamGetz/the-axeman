shader_type canvas_item;
render_mode unshaded;

// A restrained storybook finish for the completed 3D Action_Viewport. The HUD
// is drawn by a later CanvasLayer and therefore stays crisp and unaffected.
// Unlike the retired pixel grade, this pass never snaps UVs or quantizes colour.
// A small edge-aware wash calms high-frequency texture detail, followed by Sam's
// selected broad broken-brush treatment around strong geometry edges.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float wash_strength : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float wash_radius : hint_range(0.5, 2.5, 0.05) = 1.10;
uniform float edge_preservation : hint_range(0.01, 0.40, 0.01) = 0.14;
uniform float saturation : hint_range(0.0, 1.5, 0.01) = 0.94;
uniform float warmth : hint_range(0.0, 1.0, 0.01) = 0.26;
uniform float vignette_strength : hint_range(0.0, 0.5, 0.01) = 0.10;
uniform float brush_sample_radius : hint_range(0.5, 4.0, 0.1) = 2.1;
uniform float brush_edge_threshold : hint_range(0.01, 0.5, 0.001) = 0.115;
uniform float brush_edge_softness : hint_range(0.001, 0.2, 0.001) = 0.052;
uniform float brush_coverage : hint_range(0.0, 1.0, 0.01) = 0.46;
uniform float brush_darkening : hint_range(0.0, 1.0, 0.01) = 0.68;
uniform float brush_strength : hint_range(0.0, 1.0, 0.01) = 0.88;
uniform float brush_dash_length : hint_range(4.0, 64.0, 1.0) = 28.0;


float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}


float hash21(vec2 value) {
	vec3 p = fract(vec3(value.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}


float edge_weight(vec3 centre, vec3 sample_color) {
	float difference = abs(luminance(centre) - luminance(sample_color));
	return 1.0 - smoothstep(edge_preservation * 0.35,
		edge_preservation, difference);
}


void add_wash_sample(inout vec3 sum, inout float total_weight,
		vec3 centre, vec2 uv, float base_weight) {
	vec3 sample_color = texture(screen_texture,
		clamp(uv, vec2(0.0), vec2(1.0))).rgb;
	float weight = base_weight * edge_weight(centre, sample_color);
	sum += sample_color * weight;
	total_weight += weight;
}


float brush_edge_mask(vec2 uv, vec2 screen_pixel_size, vec2 pixel) {
	vec2 px = screen_pixel_size * brush_sample_radius;
	float tl = luminance(texture(screen_texture,
		clamp(uv + vec2(-px.x, -px.y), vec2(0.0), vec2(1.0))).rgb);
	float tc = luminance(texture(screen_texture,
		clamp(uv + vec2(0.0, -px.y), vec2(0.0), vec2(1.0))).rgb);
	float tr = luminance(texture(screen_texture,
		clamp(uv + vec2(px.x, -px.y), vec2(0.0), vec2(1.0))).rgb);
	float ml = luminance(texture(screen_texture,
		clamp(uv + vec2(-px.x, 0.0), vec2(0.0), vec2(1.0))).rgb);
	float mr = luminance(texture(screen_texture,
		clamp(uv + vec2(px.x, 0.0), vec2(0.0), vec2(1.0))).rgb);
	float bl = luminance(texture(screen_texture,
		clamp(uv + vec2(-px.x, px.y), vec2(0.0), vec2(1.0))).rgb);
	float bc = luminance(texture(screen_texture,
		clamp(uv + vec2(0.0, px.y), vec2(0.0), vec2(1.0))).rgb);
	float br = luminance(texture(screen_texture,
		clamp(uv + vec2(px.x, px.y), vec2(0.0), vec2(1.0))).rgb);

	float gx = -tl - 2.0 * ml - bl + tr + 2.0 * mr + br;
	float gy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;
	float edge_magnitude = length(vec2(gx, gy)) * 0.25;
	float edge = smoothstep(brush_edge_threshold,
		brush_edge_threshold + brush_edge_softness, edge_magnitude);

	float along_brush = (pixel.x + pixel.y * 0.31) / brush_dash_length;
	vec2 dash_cell = floor(vec2(along_brush,
		(pixel.y - pixel.x * 0.09) / 9.0));
	float dash_noise = hash21(dash_cell);
	float dash = smoothstep(1.0 - brush_coverage,
		1.08 - brush_coverage, dash_noise);
	float within_dash = fract(along_brush);
	float tapered_ends = smoothstep(0.02, 0.18, within_dash)
		* smoothstep(0.02, 0.22, 1.0 - within_dash);
	dash *= tapered_ends;

	float bristle_noise = hash21(floor(pixel * vec2(0.48, 0.82)));
	float bristle = smoothstep(0.16, 0.52, bristle_noise);
	float confident_edge = smoothstep(0.18, 0.72, edge);
	return confident_edge * dash * mix(0.68, 1.0, bristle)
		* brush_strength;
}


float soft_vignette(vec2 uv) {
	vec2 centred = uv * 2.0 - 1.0;
	float edge = dot(centred, centred);
	return 1.0 - smoothstep(0.34, 1.42, edge) * vignette_strength;
}


void fragment() {
	vec2 radius = SCREEN_PIXEL_SIZE * wash_radius;
	vec3 centre = texture(screen_texture, SCREEN_UV).rgb;
	vec3 wash = centre * 4.0;
	float total_weight = 4.0;

	add_wash_sample(wash, total_weight, centre,
		SCREEN_UV + vec2(radius.x, 0.0), 1.0);
	add_wash_sample(wash, total_weight, centre,
		SCREEN_UV - vec2(radius.x, 0.0), 1.0);
	add_wash_sample(wash, total_weight, centre,
		SCREEN_UV + vec2(0.0, radius.y), 1.0);
	add_wash_sample(wash, total_weight, centre,
		SCREEN_UV - vec2(0.0, radius.y), 1.0);
	add_wash_sample(wash, total_weight, centre,
		SCREEN_UV + radius, 0.55);
	add_wash_sample(wash, total_weight, centre,
		SCREEN_UV - radius, 0.55);
	add_wash_sample(wash, total_weight, centre,
		SCREEN_UV + vec2(radius.x, -radius.y), 0.55);
	add_wash_sample(wash, total_weight, centre,
		SCREEN_UV + vec2(-radius.x, radius.y), 0.55);

	vec3 color = mix(centre, wash / total_weight, wash_strength);
	float luma = luminance(color);
	color = mix(vec3(luma), color, saturation);
	vec3 warmed = color * vec3(1.055, 1.012, 0.925);
	color = mix(color, warmed, warmth);

	// A mild shoulder keeps bright cut faces creamy instead of glaring, without
	// flattening the mid-tone bark and ground detail into posterized bands.
	color = color * (vec3(1.035) - color * 0.035);
	color *= soft_vignette(SCREEN_UV);

	// Multiplication preserves the colour family under each mark: foliage gains
	// forest-green pigment, bark gains brown pigment, and painted equipment gains
	// a darker version of its own local colour rather than one universal black.
	float brush = clamp(brush_edge_mask(
		SCREEN_UV, SCREEN_PIXEL_SIZE, FRAGCOORD.xy), 0.0, 1.0);
	vec3 local_ink = color * (1.0 - brush_darkening);
	color = mix(color, local_ink, brush);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
