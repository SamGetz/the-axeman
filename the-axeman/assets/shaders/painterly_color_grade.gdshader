shader_type canvas_item;
render_mode unshaded;

// A restrained storybook finish for the completed 3D Action_Viewport. The HUD
// is drawn by a later CanvasLayer and therefore stays crisp and unaffected.
// Unlike the retired pixel grade, this pass never snaps UVs, quantizes colour,
// or dithers coverage. A small edge-aware wash calms high-frequency texture
// detail while preserving the chopping silhouette and cut-face readability.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float wash_strength : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float wash_radius : hint_range(0.5, 2.5, 0.05) = 1.10;
uniform float edge_preservation : hint_range(0.01, 0.40, 0.01) = 0.14;
uniform float saturation : hint_range(0.0, 1.5, 0.01) = 0.94;
uniform float warmth : hint_range(0.0, 1.0, 0.01) = 0.26;
uniform float vignette_strength : hint_range(0.0, 0.5, 0.01) = 0.10;


float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
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
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
