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
	float clean_roughness = 0.16;
	float clean_metallic = 0.08;
	vec3 grime = vec3(0.29, 0.16, 0.055);
	vec3 stuck_material = vec3(0.86, 0.81, 0.65);
	float dirt_roughness = 0.96;
	if (item_kind == 0) {
		// Smooth nacre: restrained rose/blue interference, not metal or glitter.
		float nacre = 0.5 + 0.5 * sin(UV.y * 35.0 + sin(UV.x * 19.0));
		vec3 sheen = mix(vec3(0.88, 0.94, 1.0), vec3(1.0, 0.86, 0.90), nacre);
		clean = mix(clean, sheen, rim * 0.45);
		clean_roughness += nacre * 0.025;
	} else if (item_kind == 1) {
		// Warm antique brass with shallow machining marks and fine wear.
		float rings = 0.5 + 0.5 * sin(UV.y * 420.0 + sin(UV.x * 25.0));
		clean *= 0.90 + 0.10 * rings;
		clean_metallic = 0.82;
		clean_roughness = 0.25 + rings * 0.055 + grain * 0.025;
		grime = vec3(0.055, 0.19, 0.12); // Green oxidized surface deposits.
		stuck_material = vec3(0.39, 0.24, 0.08);
	} else {
		// Silver bearing steel: smooth, reflective, with faint polishing lines.
		float polish = 0.5 + 0.5 * sin(UV.x * 530.0 + UV.y * 70.0);
		clean *= 0.96 + 0.04 * polish;
		clean_metallic = 0.86;
		clean_roughness = 0.13 + polish * 0.035;
		grime = vec3(0.025, 0.033, 0.043); // Dark workshop grease, not brass patina.
		stuck_material = vec3(0.43, 0.47, 0.49);
		dirt_roughness = 0.48;
	}
	// Broad deposits stay readable in the dark and retreat continuously in water.
	// Leave small exposed patches so the underlying item remains identifiable.
	float patches = 0.5 + 0.25 * sin(UV.x * 51.0 + sin(UV.y * 23.0) * 3.0)
		+ 0.25 * sin(UV.y * 43.0 + cos(UV.x * 31.0) * 2.0);
	float coating = smoothstep(1.12 - residue, 1.30 - residue, patches) * smoothstep(0.0, 0.08, residue);
	float flecks = step(0.78, patches) * step(0.4, grain);
	vec3 dirty = mix(grime, stuck_material, flecks);

	vec3 fluorescence = vec3(0.04, 1.0, 0.68);
	ALBEDO = mix(mix(clean, dirty, coating), fluorescence, uv_strength * 0.75);
	METALLIC = mix(clean_metallic, 0.0, coating);
	ROUGHNESS = mix(clean_roughness, dirt_roughness, coating);
	CLEARCOAT = (1.0 - coating) * 0.65;
	EMISSION = fluorescence * uv_strength * (0.35 + rim * 1.6);
}
