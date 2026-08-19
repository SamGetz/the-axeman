shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_disabled,
	shadows_disabled, fog_disabled;

// Solid painterly treatment for real run-power geometry. The shared daub
// shader is deliberately unshaded with depth_draw_never so its cutout marks
// stay flat; coherent 3D props need depth writes and a lit ramp instead, or
// interior faces read through the silhouette.
uniform vec4 dark_color : source_color = vec4(0.10, 0.18, 0.12, 1.0);
uniform vec4 mid_color : source_color = vec4(0.42, 0.72, 0.34, 1.0);
uniform vec4 light_color : source_color = vec4(0.86, 0.96, 0.72, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
// Painterly break-up across the surface. Stays subtle so silhouettes read at
// the small on-screen sizes these props occupy.
uniform float dry_amount : hint_range(0.0, 1.0) = 0.16;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.55;
uniform float seed = 0.0;

varying vec3 local_position;


float hash31(vec3 value) {
	vec3 p = fract(value * 0.1031 + seed * 0.07);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}


void vertex() {
	local_position = VERTEX;
}


void fragment() {
	// Two-band toon ramp driven by the view-space normal keeps the read stable
	// under the Compatibility renderer without a real light in the burst.
	float facing = clamp(dot(normalize(NORMAL), normalize(vec3(0.34, 0.82, 0.46))),
		-1.0, 1.0);
	// A wide, lifted shadow band. These props are small and often seen from the
	// side the key light misses; a tight ramp turned them into black silhouettes.
	float band = smoothstep(-0.65, 0.35, facing);
	float highlight = smoothstep(0.55, 0.92, facing);
	vec3 pigment = mix(dark_color.rgb, mid_color.rgb, band);
	pigment = mix(pigment, light_color.rgb, highlight * 0.85);

	float grain = hash31(floor(local_position * 46.0));
	pigment *= 1.0 - dry_amount * 0.42 * grain;

	float rim = pow(1.0 - clamp(dot(normalize(NORMAL),
		normalize(VIEW)), 0.0, 1.0), 2.6);
	pigment += light_color.rgb * rim * rim_strength * 0.5;

	ALBEDO = pigment;
	ALPHA = clamp(mid_color.a * opacity, 0.0, 1.0);
}
