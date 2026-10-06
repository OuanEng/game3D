shader_type spatial;
// Normal depth testing remains enabled: UV never renders pearls through barn walls.
// Tools fades only intervening foam that passed its cone and world-occlusion tests.
uniform float residue : hint_range(0.0, 1.0) = 1.0;
uniform float uv_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 clean = vec3(1.0, 0.94, 0.79);
	vec3 dirty = vec3(0.43, 0.39, 0.27);
	vec3 fluorescence = vec3(0.04, 1.0, 0.68);
	ALBEDO = mix(mix(clean, dirty, residue), fluorescence, uv_strength * 0.75);
	METALLIC = 0.16;
	ROUGHNESS = mix(0.2, 0.62, residue);
	EMISSION = fluorescence * uv_strength * 3.0;
}
