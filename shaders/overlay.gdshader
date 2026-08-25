shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float aberr = 0.0;
uniform float hurt = 0.0;
uniform float low_hp = 0.0;
uniform float flash_white = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.5);
	float r = length(d * vec2(1.78, 1.0));
	float ab = aberr * 0.011 + hurt * 0.014;
	vec3 col;
	col.r = texture(screen_tex, uv + d * ab).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - d * ab).b;
	float scan = sin(uv.y * 1300.0) * 0.5 + 0.5;
	col *= 1.0 - 0.05 * scan;
	float vig = smoothstep(1.35, 0.42, r);
	col *= mix(1.0, vig, 0.8);
	float edge = smoothstep(0.5, 1.02, r);
	float hp_pulse = low_hp * (0.32 + 0.14 * sin(TIME * 6.0));
	col = mix(col, vec3(0.72, 0.06, 0.16), clamp(edge * (hurt * 0.85 + hp_pulse), 0.0, 0.85));
	col += vec3(1.0, 0.95, 0.9) * flash_white;
	COLOR = vec4(col, 1.0);
}
