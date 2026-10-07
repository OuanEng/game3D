shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 motion = vec2(0.0);
void fragment() {
	// Lightweight camera-rotation blur; UI is drawn afterwards and stays sharp.
	vec4 sum = vec4(0.0);
	for (int i = -2; i <= 2; i++) {
		sum += texture(screen_texture, SCREEN_UV + motion * float(i) * 0.5);
	}
	COLOR = sum / 5.0;
}
