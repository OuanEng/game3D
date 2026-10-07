shader_type spatial;
// Normal depth testing remains enabled: UV never renders pearls through barn walls.
// Tools only enables fluorescence under a thin, unobstructed foam layer.
uniform float residue : hint_range(0.0, 1.0) = 1.0;
uniform float uv_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 item_tint : source_color = vec4(1.0, 0.94, 0.79, 1.0);
uniform int item_kind = 0;

void fragment() {
	vec3 clean = item_tint.rgb;
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.0);
	float grain = fract(sin(dot(floor(UV * 180.0), vec2(12.9898, 78.233))) * 43758.5453);
	if (item_kind == 0) {
		// Pearlescent thin-film approximation; no expensive screen refraction.
		clean = mix(clean, vec3(0.72, 0.82, 1.0), rim * 0.35);
	} else if (item_kind == 1) {
		clean *= 0.72 + 0.28 * grain;
	} else {
		clean = mix(clean, vec3(0.20, 0.13, 0.29), rim * 0.4);
	}
	vec3 dirty = vec3(0.43, 0.39, 0.27);
	vec3 fluorescence = vec3(0.04, 1.0, 0.68);
	ALBEDO = mix(mix(clean, dirty, residue), fluorescence, uv_strength * 0.75);
	METALLIC = mix(item_kind == 0 ? 0.12 : 0.92, 0.05, residue);
	ROUGHNESS = mix(item_kind == 1 ? 0.24 : 0.10, 0.70, residue);
	CLEARCOAT = (1.0 - residue) * 0.65;
	EMISSION = fluorescence * uv_strength * (0.35 + rim * 1.6);
}
