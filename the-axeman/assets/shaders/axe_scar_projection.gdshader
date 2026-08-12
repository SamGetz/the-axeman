shader_type spatial;

// Compatibility has no Decal rendering, so each scar is projected onto a
// top-face receiver copied from the struck piece. The generated normal map is
// also its own soft mask: neutral-normal pixels disappear, leaving only the
// torn fibres to shade.
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform sampler2D scar_normal : hint_normal, repeat_disable, filter_linear_mipmap_anisotropic;
uniform vec3 scar_tint : source_color = vec3(0.72, 0.42, 0.12);
uniform vec3 scar_shadow : source_color = vec3(0.30, 0.12, 0.035);
uniform vec3 scar_highlight : source_color = vec3(1.0, 0.78, 0.32);
uniform float scar_opacity : hint_range(0.0, 1.0) = 0.82;
uniform float normal_strength : hint_range(0.0, 4.0) = 3.5;
uniform float mask_start : hint_range(0.0, 0.5) = 0.055;
uniform float mask_full : hint_range(0.0, 0.5) = 0.20;

void fragment() {
	vec3 sampled_normal = texture(scar_normal, UV).rgb;
	float relief = length(sampled_normal - vec3(0.5, 0.5, 1.0));
	float mask = smoothstep(mask_start, mask_full, relief);
	float in_bounds = step(0.0, UV.x) * step(UV.x, 1.0)
		* step(0.0, UV.y) * step(UV.y, 1.0);
	// The normal map's red channel describes the opposing walls of the axe bite.
	// Turn that same data into a restrained fresh-wood shadow/rim cue so one scar
	// remains legible against busy end grain even when the world light is flat.
	float wall = smoothstep(0.18, 0.82, sampled_normal.r);
	vec3 shaped_tint = mix(scar_shadow, scar_highlight, wall);
	shaped_tint = mix(scar_tint, shaped_tint, 0.92);

	ALBEDO = shaped_tint;
	ROUGHNESS = 0.78;
	SPECULAR = 0.35;
	NORMAL_MAP = sampled_normal;
	NORMAL_MAP_DEPTH = normal_strength;
	ALPHA = mask * scar_opacity * in_bounds;
}
