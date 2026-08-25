shader_type canvas_item;

uniform vec3 base_col : source_color = vec3(0.012, 0.014, 0.033);
uniform vec3 grid_col : source_color = vec3(0.075, 0.13, 0.24);
uniform vec3 glow_col : source_color = vec3(0.05, 0.13, 0.2);
uniform vec3 era_tint = vec3(1.0, 0.0, 0.0);
uniform float era_mix = 0.0;
uniform float pulse = 0.0;

float grid(vec2 c) {
	vec2 f = abs(fract(c) - 0.5);
	float d = min(f.x, f.y);
	return smoothstep(0.09, 0.0, d);
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p * vec2(1.78, 1.0));
	vec2 uv1 = UV * vec2(1280.0, 720.0) / 46.0;
	vec2 uv2 = UV * vec2(1280.0, 720.0) / 23.0;
	uv1 += vec2(TIME * 0.12, TIME * 0.045);
	uv2 -= vec2(TIME * 0.05, -TIME * 0.02);
	float g = grid(uv1) * 0.55 + grid(uv2) * 0.22;
	vec3 ecol = mix(grid_col, era_tint * 0.85, era_mix * 0.7);
	vec3 eglo = mix(glow_col, era_tint * 0.6, era_mix * 0.9);
	vec3 col = base_col + ecol * g;
	col += eglo * exp(-r * 3.2) * 0.9;
	col *= 1.0 - r * r * 0.85;
	if (pulse > 0.001) {
		float ring = exp(-abs(r - pulse * 1.5) * 16.0) * (1.0 - pulse);
		col += grid_col * 2.4 * ring;
	}
	COLOR = vec4(col, 1.0);
}
