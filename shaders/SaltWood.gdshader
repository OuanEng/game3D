shader_type spatial;
varying vec3 point;
void vertex() { point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 float grain = sin((point.x + point.z) * 22.0 + sin(point.y * 2.0) * 3.0);
 vec3 wood = mix(vec3(0.30,0.17,0.07), vec3(0.42,0.25,0.11), grain * 0.5 + 0.5);
 float speck = fract(sin(dot(floor(point * 42.0), vec3(12.9,78.2,34.6))) * 43758.5);
 float crust = (1.0 - smoothstep(0.1,2.3,point.y)) * step(0.48,speck);
 ALBEDO = mix(wood,vec3(0.83,0.86,0.80),crust * 0.45);
 ROUGHNESS = 0.95;
}
