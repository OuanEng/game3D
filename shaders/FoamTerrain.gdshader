shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform float base_height = 0.0;
uniform int material_kind = 0;
uniform bool uv_scan_enabled = false;
uniform vec3 uv_origin = vec3(0.0);
uniform vec3 uv_direction = vec3(0.0, 0.0, -1.0);
uniform float uv_range = 7.0;
// CPU-tested surface positions: xyz = beam entry point, w = glow strength.
// The opaque mountain never turns into a beam-wide window onto deep objects.
uniform vec4 uv_hints[8];
uniform int uv_hint_count = 0;
varying vec3 world_point;
varying float foam_height;

float hash_cell(vec3 point) {
	return fract(sin(dot(point, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	foam_height = VERTEX.y - base_height;
}

void fragment() {
	// The zero-height rectangle is the bare wooden floor, not a foam carpet.
	if (foam_height < 0.004) {
		discard;
	}
	float grain = hash_cell(floor(world_point * 42.0));
	float fleck = smoothstep(0.76, 0.96, grain);
	ALBEDO = mix(vec3(0.78, 0.83, 0.83), vec3(0.96, 0.97, 0.93), grain);
	ALBEDO *= 1.0 - fleck * 0.10;
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
	int visible_material = material_kind;
	if (material_kind == 3) { visible_material = foam_height < 1.0 ? 2 : (foam_height < 2.2 ? 1 : 0); }
	if (visible_material == 1) {
		float crystal = hash_cell(floor(world_point * 85.0));
		ALBEDO = mix(vec3(0.66, 0.72, 0.79), vec3(0.92, 0.97, 1.0), crystal);
		ROUGHNESS = 0.62;
		SPECULAR = 0.4;
	} else if (visible_material == 2) {
		float ripple = sin(world_point.x * 14.0 + sin(world_point.z * 3.0));
		ALBEDO = mix(vec3(0.38, 0.24, 0.10), vec3(0.78, 0.59, 0.31), grain) * (0.96 + ripple * 0.04);
		ROUGHNESS = 1.0;
	}
	if (uv_scan_enabled) {
		vec3 offset = world_point - uv_origin;
		float distance_to_beam = length(offset);
		float alignment = dot(offset / max(distance_to_beam, 0.001), uv_direction);
		float cone = smoothstep(0.91, 0.97, alignment);
		float reach = 1.0 - smoothstep(uv_range - 1.0, uv_range, distance_to_beam);
		float scan = cone * reach;
		ALBEDO = mix(ALBEDO, vec3(0.27, 0.37, 0.48), scan * 0.30);
		float glow = 0.0;
		for (int index = 0; index < 8; index++) {
			if (index >= uv_hint_count) { break; }
			float radius = distance(world_point, uv_hints[index].xyz);
			// A soft, round fluorescence hint represents light diffusing through
			// a thin covering. Ordinary depth testing and solid foam stay intact.
			glow = max(glow, (1.0 - smoothstep(0.04, 0.22, radius)) * uv_hints[index].w);
		}
		ALBEDO = mix(ALBEDO, vec3(0.13, 0.65, 0.51), glow * 0.65);
		EMISSION = vec3(0.04, 0.65, 0.42) * glow * 1.4;
	}
}
