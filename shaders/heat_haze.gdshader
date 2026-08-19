shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 0.01) = 0.0017;
uniform float shimmer_speed : hint_range(0.0, 4.0) = 0.575;

varying vec2 world_anchor;

void vertex() {
	world_anchor = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float broad = sin(world_anchor.y * 0.091 + TIME * 2.2 * shimmer_speed + sin(world_anchor.x * 0.017));
	float fine = cos(world_anchor.x * 0.137 - world_anchor.y * 0.043 - TIME * 3.1 * shimmer_speed);
	vec2 offset = vec2(broad + fine * 0.35, fine * 0.28) * strength;
	vec4 scene = texture(screen_texture, uv + offset);
	vec3 heat_tint = vec3(0.018, 0.008, -0.006);
	COLOR = vec4(scene.rgb + heat_tint, scene.a);
}
