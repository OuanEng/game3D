shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
// Animated rain rivulets; no screen texture, so this also works on WebGL.
void fragment() {
	vec2 p = UV * vec2(48.0, 10.0);
	float speed = 0.6 + fract(sin(floor(p.x) * 91.7) * 437.2);
	float streak = pow(max(0.0, 1.0 - abs(fract(p.x) - 0.5) * 10.0), 2.0);
	float drop = pow(1.0 - fract(p.y + TIME * speed), 8.0);
	ALBEDO = vec3(0.18, 0.38, 0.53);
	ALPHA = 0.06 + streak * drop * 0.65;
}
