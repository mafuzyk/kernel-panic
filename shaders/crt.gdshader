shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float curvature = 0.0;
uniform float noise = 0.0;
uniform float scanline = 0.0;
uniform float aberration = 0.0;
uniform float holy = 0.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - vec2(0.5);
	float r2 = dot(centered, centered);
	vec2 curved = centered * (1.0 + curvature * r2 * 3.0) + vec2(0.5);
	vec2 edge = step(vec2(0.0), curved) * step(curved, vec2(1.0));
	vec2 ab = centered * aberration * 0.008;
	vec3 col;
	col.r = texture(screen_tex, curved + ab).r;
	col.g = texture(screen_tex, curved).g;
	col.b = texture(screen_tex, curved - ab).b;
	float line = 0.72 + 0.28 * sin(SCREEN_UV.y * 900.0);
	col *= 1.0 - scanline * (1.0 - line);
	float grain = hash21(floor(SCREEN_UV * vec2(1280.0, 720.0)) + floor(TIME * 24.0)) - 0.5;
	col += grain * noise;
	if (holy > 0.5) {
		float aureole = 0.5 + 0.5 * sin(TIME * 1.8 + SCREEN_UV.x * 5.0);
		vec3 gold = vec3(1.0, 0.72, 0.24);
		vec3 coral = vec3(1.0, 0.18, 0.30);
		col = mix(col, col * 0.78 + gold * 0.22, 0.7);
		col += gold * (0.025 + aureole * 0.025);
		col += coral * grain * 0.12;
	}
	col *= edge.x * edge.y;
	COLOR = vec4(col, 1.0);
}
