shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 0.01) = 0.0017;
uniform float shimmer_speed : hint_range(0.0, 4.0) = 1.15;

void fragment() {
	vec2 uv = SCREEN_UV;
	float lower_field = smoothstep(0.16, 0.94, uv.y);
	float broad = sin(uv.y * 91.0 + TIME * 2.2 * shimmer_speed + sin(uv.x * 17.0));
	float fine = cos(uv.x * 137.0 - uv.y * 43.0 - TIME * 3.1 * shimmer_speed);
	vec2 offset = vec2(broad + fine * 0.35, fine * 0.28) * strength * lower_field;
	vec4 scene = texture(screen_texture, uv + offset);
	vec3 heat_tint = vec3(0.018, 0.008, -0.006) * lower_field;
	COLOR = vec4(scene.rgb + heat_tint, scene.a);
}
