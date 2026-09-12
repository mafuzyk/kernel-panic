shader_type canvas_item;

uniform vec3 base_col : source_color = vec3(0.012, 0.014, 0.033);
uniform vec3 grid_col : source_color = vec3(0.075, 0.13, 0.24);
uniform vec3 glow_col : source_color = vec3(0.05, 0.13, 0.2);
uniform vec3 era_tint = vec3(1.0, 0.0, 0.0);
uniform float era_mix = 0.0;
uniform float pulse = 0.0;
uniform float corruption = 0.0;
// Vindos de `Balance` para existir uma fonte só: o autotest afirma a regra de
// legibilidade sobre essas constantes.
uniform vec3 corruption_col : source_color = vec3(0.075, 0.012, 0.030);
uniform float corruption_mix = 0.72;
uniform float corruption_coverage = 0.14;
uniform float subgrid_weight = 0.10;

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
	float g = grid(uv1) * 0.55 + grid(uv2) * subgrid_weight;
	vec3 ecol = mix(grid_col, era_tint * 0.85, era_mix * 0.7);
	vec3 eglo = mix(glow_col, era_tint * 0.6, era_mix * 0.9);
	vec3 col = base_col + ecol * g;
	col += eglo * exp(-r * 3.2) * 0.9;
	col *= 1.0 - r * r * 0.85;
	if (pulse > 0.001) {
		float ring = exp(-abs(r - pulse * 1.5) * 16.0) * (1.0 - pulse);
		col += grid_col * 2.4 * ring;
	}
	// Setor corrompido = grade DANIFICADA. Escurece em vez de acender, para o
	// fundo nunca competir em brilho com as entidades. A borda do setor guarda
	// o matiz vermelho, que é onde ele informa sem ofuscar.
	vec2 corruption_cell = floor(UV * vec2(22.0, 13.0));
	float corruption_hash = fract(sin(dot(corruption_cell, vec2(12.9898, 78.233))) * 43758.5453);
	float corruption_patch = step(1.0 - corruption_coverage, corruption_hash) * smoothstep(0.0, 0.18, corruption);
	float corruption_flicker = 0.82 + 0.18 * sin(TIME * 2.7 + corruption_hash * 12.0);
	float corruption_amount = corruption_patch * corruption_flicker * corruption_mix;
	col = mix(col, corruption_col, corruption_amount);
	vec2 cell_uv = fract(UV * vec2(22.0, 13.0));
	vec2 cell_edge = abs(cell_uv - 0.5);
	float edge = smoothstep(0.42, 0.5, max(cell_edge.x, cell_edge.y));
	col += vec3(0.30, 0.03, 0.10) * edge * corruption_patch * 0.55;
	COLOR = vec4(col, 1.0);
}
