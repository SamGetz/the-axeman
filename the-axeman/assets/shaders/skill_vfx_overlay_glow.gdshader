shader_type canvas_item;
render_mode unshaded;

// Smooth local exposure pulse. This replaces the dotted overlay: glows should
// feather continuously even when the physical ember sprites retain texture.
uniform vec4 tint : source_color = vec4(1.0);
uniform float intensity = 0.0;
uniform float center_weight = 0.0;
uniform int mask_mode : hint_range(0, 1, 1) = 0;
uniform vec2 effect_center = vec2(0.5, 0.54);


void fragment() {
	vec2 p = (UV - effect_center) * vec2(1.0, 0.72);
	float distance_from_center = length(p);
	float mask = 0.0;
	if (mask_mode == 0) {
		float center = 1.0 - smoothstep(0.02, 0.27, distance_from_center);
		float local_bloom = 1.0 - smoothstep(0.08, 0.31, distance_from_center);
		mask = mix(local_bloom, center, center_weight);
	} else {
		mask = (1.0 - smoothstep(0.05, 0.34, distance_from_center))
			* (1.0 - smoothstep(0.18, 0.98, UV.y));
	}
	float value = mask * intensity;
	COLOR = vec4(tint.rgb * value, tint.a * value);
}
