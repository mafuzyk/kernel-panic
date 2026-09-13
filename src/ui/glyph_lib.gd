class_name GlyphLib
extends RefCounted

## Shared code-drawn silhouettes for enemies and playable programs.
## Pure canvas drawing: no state, no Game.rng, no node allocation.

static func glyph_kinds() -> Array:
	return ["drone", "lancer", "spewer", "splitter", "bulwark", "trojan", "oom", "recursor", "firewall", "bloatware", "update_loop", "page", "root", "boss", "segfault", "bluescreen", "pagefault", "god", "kernel", "daemon", "rootlet"]

## Maximum silhouette reach per kind, in multiples of the draw radius.
## Conservative outer bounds (lancer's lance tip reaches 2.4x, oom horns 1.6x,
## segfault jitter 1.45x); detail views use this to fit glyphs into fixed boxes.
const GLYPH_EXTENT := {
	"drone": 1.5, "lancer": 2.4, "spewer": 1.1, "splitter": 1.05, "bulwark": 1.05,
	"trojan": 1.25, "oom": 1.6, "recursor": 1.05, "firewall": 1.05, "bloatware": 1.05,
	"update_loop": 1.05, "page": 1.25, "root": 1.05, "boss": 1.05, "segfault": 1.45,
	"bluescreen": 1.30, "pagefault": 1.15, "god": 1.35, "kernel": 1.5, "daemon": 1.45,
	"rootlet": 1.1,
}

static func glyph_extent(kind: String) -> float:
	return float(GLYPH_EXTENT.get(kind, 1.0))

static func era_mix(base: Color, era: Color, amount: float = 0.25) -> Color:
	if era.a <= 0.0 or amount <= 0.0:
		return base
	return base.lerp(era, clampf(amount, 0.0, 1.0))

## Desenha a silhueta da entidade EM CÓDIGO. É o caminho da arena.
##
## Decisão da autora (2026-09-11, reverte a migração de 2026-08-30): a arena
## volta ao desenho em código. Motivos medidos em
## docs/superpowers/specs/2026-09-11-brief-sprites.md — o sprite raster é
## 256px exibido a 24-36px (detalhe que nunca chega na tela), e como ele é
## desenhado alinhado ao eixo, descartava o `t` e deixava estáticas as 10
## entidades que animam, bosses inclusos.
##
## Para retrato grande e estático (menu, bestiário) use `draw_portrait()`.
static func draw_glyph(canvas: CanvasItem, kind: String, center: Vector2, radius: float, color: Color, t: float = 0.0) -> void:
	if canvas == null or radius <= 0.0:
		return
	var c := color
	match kind:
		"drone":
			# É um DRONE: quatro rotores em torno de um núcleo. Antes dividia o
			# mesmo _dart() com kernel e lancer — três entidades, uma forma só.
			# braços longos e casulos menores: mais vazio entre eles, para o
			# contorno ler como cruz e não como disco (colidia com a espiral
			# do recursor em 0.507).
			var arm := radius * 0.74
			for i in 4:
				var da := t * 1.2 + TAU * float(i) / 4.0 + PI * 0.25
				var pod := center + Vector2.from_angle(da) * arm
				canvas.draw_line(center, pod, Color(c.r, c.g, c.b, 0.8), 2.4)
				canvas.draw_circle(pod, radius * 0.24, Color(c.r, c.g, c.b, 0.25))
				canvas.draw_arc(pod, radius * 0.24, 0, TAU, 14, c, 2.2, true)
			canvas.draw_circle(center, radius * 0.18, c)
		"lancer":
			# Dispara uma lança: a ELONGAÇÃO é a silhueta. Antes era o mesmo
			# _dart do kernel mais uma linha de alpha 0.5 que sumia em jogo.
			var shaft := PackedVector2Array([
				center + Vector2(radius * 2.25, 0.0),
				center + Vector2(radius * 0.40, radius * 0.18),
				center + Vector2(-radius * 0.95, radius * 0.60),
				center + Vector2(-radius * 0.50, 0.0),
				center + Vector2(-radius * 0.95, -radius * 0.60),
				center + Vector2(radius * 0.40, -radius * 0.18),
			])
			canvas.draw_colored_polygon(shaft, Color(c.r, c.g, c.b, 0.22))
			canvas.draw_polyline(shaft + PackedVector2Array([shaft[0]]), c, 2.2, true)
		"spewer":
			# Cospe orbes: o contorno tem BICOS. Antes era hexágono + ponto
			# central, genérico, e disputava com o octógono do firewall.
			var spouts := 3
			var body := PackedVector2Array()
			var body_steps := 30
			for i in body_steps:
				var ba := TAU * float(i) / float(body_steps)
				var lobe := 1.0
				for k2 in spouts:
					var sa := t * 0.9 + TAU * float(k2) / float(spouts)
					var d: float = absf(wrapf(ba - sa, -PI, PI))
					if d < 0.36:
						lobe = maxf(lobe, 1.0 + 0.58 * cos(d / 0.36 * PI * 0.5))
				body.push_back(center + Vector2.from_angle(ba) * radius * 0.70 * lobe)
			canvas.draw_colored_polygon(body, Color(c.r, c.g, c.b, 0.20))
			canvas.draw_polyline(body + PackedVector2Array([body[0]]), c, 2.2, true)
			canvas.draw_circle(center, radius * 0.24, c)
		"splitter":
			# A distinção precisa estar no CONTORNO, não no miolo: em 24px o
			# interior some. Antes era círculo + barra + dois pontos, e lia
			# igual ao oom (IoU 0.82 medido). Agora a própria silhueta está
			# partida — duas metades com folga, que é o que o inimigo faz.
			var gap := radius * 0.17
			var half_steps := 18
			for side in [-1.0, 1.0]:
				var half := PackedVector2Array()
				for i in half_steps + 1:
					var ha := -PI * 0.5 + PI * float(i) / float(half_steps)
					var hp := Vector2.from_angle(ha) * radius
					if side < 0.0:
						hp.x = -hp.x
					half.push_back(center + hp + Vector2(side * gap, 0.0))
				canvas.draw_colored_polygon(half, Color(c.r, c.g, c.b, 0.18))
				canvas.draw_polyline(half + PackedVector2Array([half[0]]), c, 2.2, true)
		"bulwark":
			# Bloqueador blindado. Era quadrado + círculo + X empilhados, sem
			# ideia única, e colidia com o update_loop (IoU 0.578). O contorno
			# agora é um escudo: ombro largo, base em ponta.
			var shield := PackedVector2Array([
				center + Vector2(-radius * 0.84, -radius * 0.82),
				center + Vector2(radius * 0.84, -radius * 0.82),
				center + Vector2(radius * 0.84, radius * 0.14),
				center + Vector2(0.0, radius * 1.04),
				center + Vector2(-radius * 0.84, radius * 0.14),
			])
			canvas.draw_colored_polygon(shield, Color(c.r, c.g, c.b, 0.16))
			canvas.draw_polyline(shield + PackedVector2Array([shield[0]]), c, 3.0, true)
			canvas.draw_line(center + Vector2(0.0, -radius * 0.46), center + Vector2(0.0, radius * 0.56), Color(c.r, c.g, c.b, 0.75), 2.2)
		"trojan":
			# Ameaça disfarçada: casco fechado com algo rompendo por cima. A
			# primeira tentativa apontava para baixo e lia como alfinete de
			# mapa; a linha interna reforçava "etiqueta". Invertido, a leitura
			# passa a ser irrupção.
			var tw := radius * 0.74
			var th := radius * 0.60
			var crate := PackedVector2Array([
				center + Vector2(-tw, -th * 0.30),
				center + Vector2(-tw * 0.30, -th * 0.30),
				center + Vector2(0.0, -radius * 1.22),
				center + Vector2(tw * 0.30, -th * 0.30),
				center + Vector2(tw, -th * 0.30),
				center + Vector2(tw, th),
				center + Vector2(-tw, th),
			])
			canvas.draw_colored_polygon(crate, Color(c.r, c.g, c.b, 0.22))
			canvas.draw_polyline(crate + PackedVector2Array([crate[0]]), c, 2.4, true)
		"oom":
			# Os chifres eram detalhes de 0.45r pousados sobre um círculo:
			# sumiam em 24px e o glifo lia como círculo simples. Agora fazem
			# parte do contorno, então a silhueta é inconfundível de relance.
			var maw := PackedVector2Array()
			var maw_steps := 20
			for i in maw_steps + 1:
				var ma := PI * 0.06 + PI * 0.88 * float(i) / float(maw_steps)
				maw.push_back(center + Vector2.from_angle(ma) * radius)
			maw.push_back(center + Vector2(-radius * 0.92, -radius * 0.34))
			maw.push_back(center + Vector2(-radius * 1.02, -radius * 1.30))
			maw.push_back(center + Vector2(-radius * 0.34, -radius * 0.52))
			maw.push_back(center + Vector2(0.0, -radius * 0.86))
			maw.push_back(center + Vector2(radius * 0.34, -radius * 0.52))
			maw.push_back(center + Vector2(radius * 1.02, -radius * 1.30))
			maw.push_back(center + Vector2(radius * 0.92, -radius * 0.34))
			canvas.draw_colored_polygon(maw, Color(c.r, c.g, c.b, 0.2))
			canvas.draw_polyline(maw + PackedVector2Array([maw[0]]), c, 2.2, true)
		"recursor":
			# Recursão. Duas tentativas antes falharam: o polígono de 8 pontos
			# não fechava (traço solto no canto) e os chevrons aninhados
			# colapsaram num V único. Espiral resolve — é auto-similar por
			# construção e é a única forma espiralada do conjunto.
			var spiral := PackedVector2Array()
			var spiral_steps := 48
			for i in spiral_steps + 1:
				var u := float(i) / float(spiral_steps)
				var sa := t * 0.8 + u * TAU * 2.3
				var sr := radius * (0.16 + 0.84 * u)
				spiral.push_back(center + Vector2.from_angle(sa) * sr)
			canvas.draw_polyline(spiral, c, 3.0, true)
			canvas.draw_circle(center, radius * 0.14, c)
		"firewall":
			# Barreira. A primeira tentativa (muro com ameias) trocou uma
			# colisão por outra: virou retângulo largo e passou a bater com o
			# bluescreen (IoU 0.587). Agora são barras SEPARADAS — não existe
			# contorno sólido para confundir com tela nenhuma.
			var bar_count := 3
			var bar_h := radius * 0.90
			var bar_w := radius * 0.26
			var pitch := radius * 2.0 / float(bar_count)
			for i in bar_count:
				var bx: float = -radius + pitch * (float(i) + 0.5)
				var scale_h: float = 1.0 if i % 2 == 0 else 0.66
				var bar := Rect2(
					center + Vector2(bx - bar_w * 0.5, -bar_h * scale_h),
					Vector2(bar_w, bar_h * scale_h * 2.0))
				canvas.draw_rect(bar, Color(c.r, c.g, c.b, 0.14))
				canvas.draw_rect(bar, c, false, 2.2)
			# pulso varrendo a grade: preserva a animação que o glifo já tinha
			var sweep: float = fmod(t * 0.55, 1.0) * 2.0 - 1.0
			canvas.draw_line(center + Vector2(-radius, sweep * bar_h), center + Vector2(radius, sweep * bar_h), Color(c.r, c.g, c.b, 0.55), 2.0)
		"bloatware":
			# Processo inchado. Era retângulo com linhas e colidia com o
			# bluescreen (IoU 0.491). O contorno agora é uma massa lobulada:
			# a silhueta diz "inchado" sem depender de detalhe interno.
			var lobes := PackedVector2Array()
			var lobe_steps := 30
			for i in lobe_steps:
				var la := TAU * float(i) / float(lobe_steps)
				var bulge: float = 1.0 + 0.17 * sin(la * 4.0 + t * 0.6)
				lobes.push_back(center + Vector2.from_angle(la) * radius * 0.90 * bulge)
			canvas.draw_colored_polygon(lobes, Color(c.r, c.g, c.b, 0.18))
			canvas.draw_polyline(lobes + PackedVector2Array([lobes[0]]), c, 3.0, true)
			# o "spinner" de carregamento continua sendo o telegrafo do ataque,
			# agora dentro do corpo em vez de na borda
			var spin := t * 3.2
			for i in 8:
				var a := spin + TAU * i / 8.0
				var alpha := 0.18 + 0.72 * float(i + 1) / 8.0
				canvas.draw_line(center + Vector2.from_angle(a) * (radius * 0.26), center + Vector2.from_angle(a) * (radius * 0.48), Color(c.r, c.g, c.b, alpha), 3.0)
		"update_loop":
			# Morre e reinstala. Era retângulo + arcos e colidia com o bulwark
			# (IoU 0.578). Agora a ideia de ciclo está no contorno: anel aberto
			# com seta, girando. Sem retângulo nenhum.
			var spin_u := t * 1.6
			var gap_u := 0.55
			canvas.draw_arc(center, radius * 0.80, spin_u + gap_u, spin_u + TAU - gap_u, 28, c, 3.2, true)
			var tip_a := spin_u + gap_u
			var tip_p := center + Vector2.from_angle(tip_a) * radius * 0.80
			var head_u := PackedVector2Array([
				tip_p + Vector2.from_angle(tip_a + PI * 0.5) * radius * 0.40,
				tip_p + Vector2.from_angle(tip_a - PI * 0.16) * radius * 0.46,
				tip_p + Vector2.from_angle(tip_a - PI * 0.5) * radius * 0.16,
			])
			canvas.draw_colored_polygon(head_u, c)
			canvas.draw_circle(center, radius * 0.22, Color(1, 1, 1, 0.85))
		"page":
			# Documento com canto dobrado — a dobra é CONTORNO, não detalhe
			# interno. Antes era um quadrilátero torto que parecia descuido.
			var pw2 := radius * 0.70
			var ph2 := radius * 1.08
			var fold := radius * 0.46
			var sheet := PackedVector2Array([
				center + Vector2(-pw2, -ph2),
				center + Vector2(pw2 - fold, -ph2),
				center + Vector2(pw2, -ph2 + fold),
				center + Vector2(pw2, ph2),
				center + Vector2(-pw2, ph2),
			])
			canvas.draw_colored_polygon(sheet, Color(c.r, c.g, c.b, 0.18))
			canvas.draw_polyline(sheet + PackedVector2Array([sheet[0]]), c, 2.2, true)
			canvas.draw_polyline(PackedVector2Array([
				center + Vector2(pw2 - fold, -ph2),
				center + Vector2(pw2 - fold, -ph2 + fold),
				center + Vector2(pw2, -ph2 + fold),
			]), Color(c.r, c.g, c.b, 0.7), 2.0, true)
		"root":
			# Boss principal. Era anel de arcos com o triângulo fino escondido
			# atrás — lia como spinner de carregamento. Agora o triângulo DOMINA
			# (é o sigilo do processo raiz) e o anel quebrado apenas o contém.
			var seg := 5
			for i in seg:
				var a0 := t * 0.55 + TAU * float(i) / float(seg)
				canvas.draw_arc(center, radius, a0, a0 + TAU / float(seg) * 0.52, 12, Color(c.r, c.g, c.b, 0.55), 4.0, true)
			var tri := PackedVector2Array()
			for i in 3:
				tri.push_back(center + Vector2.from_angle(-PI * 0.5 - t * 0.4 + TAU * float(i) / 3.0) * radius * 0.78)
			canvas.draw_colored_polygon(tri, Color(c.r, c.g, c.b, 0.30))
			canvas.draw_polyline(tri + PackedVector2Array([tri[0]]), c, 4.5, true)
			canvas.draw_circle(center, radius * 0.22, Color(c.r, c.g, c.b, 0.9))
		"boss":
			draw_glyph(canvas, "root", center, radius, color, t)
		"segfault":
			# Corrupção de memória: a MESMA forma duplicada e deslocada, como
			# leitura em endereço errado. Antes o laço construía só 4 dos 6
			# vértices e o resultado parecia aleatório, não intencional.
			for ghost in 2:
				var off := Vector2(radius * (0.20 if ghost == 0 else -0.20), radius * (-0.10 if ghost == 0 else 0.10))
				var shard := PackedVector2Array()
				for i in 5:
					var ga := -PI * 0.5 + TAU * float(i) / 5.0 + t * 0.35
					shard.push_back(center + off + Vector2.from_angle(ga) * radius * 0.76)
				canvas.draw_polyline(shard + PackedVector2Array([shard[0]]), Color(c.r, c.g, c.b, 0.9 if ghost == 0 else 0.42), 3.0, true)
		"bluescreen":
			# Tela travada. Mantém o retângulo (é uma TELA) mas ganha pé de
			# monitor, então o contorno deixa de ser retângulo puro e para de
			# disputar com page e pagefault.
			var sw := radius * 0.86
			var sh := radius * 0.54
			var frame := Rect2(center + Vector2(-sw, -sh - radius * 0.30), Vector2(sw * 2.0, sh * 2.0))
			canvas.draw_rect(frame, Color(c.r, c.g, c.b, 0.10))
			canvas.draw_rect(frame, Color(c.r, c.g, c.b, 0.9), false, 3.0)
			# o pé usa coordenadas ABSOLUTAS: frame.end.y já é absoluto e somá-lo
			# a center jogava o pé para fora da tela (o desenho sumia).
			var stand_y := frame.end.y + radius * 0.40
			canvas.draw_line(Vector2(center.x, frame.end.y), Vector2(center.x, stand_y), c, 3.0)
			canvas.draw_line(Vector2(center.x - sw * 0.56, stand_y), Vector2(center.x + sw * 0.56, stand_y), c, 3.0)
			for i in 3:
				var ly: float = frame.position.y + frame.size.y * (0.26 + 0.24 * float(i)) + sin(t * 3.0 + float(i)) * 2.5
				canvas.draw_line(Vector2(frame.position.x + radius * 0.16, ly), Vector2(frame.end.x - radius * 0.16, ly), Color(c.r, c.g, c.b, 0.30), 1.6)
		"pagefault":
			# Falha de página: o contorno é uma página RACHADA, metades
			# deslocadas. Antes eram três retângulos vazados de alpha 0.10 —
			# simplesmente não apareciam (cobertura 0.101 medida).
			var pw := radius * 0.70
			var ph := radius * 0.96
			var drift := radius * 0.13 * (0.6 + 0.4 * sin(t * 1.4))
			var pf_top := PackedVector2Array([
				center + Vector2(-pw - drift, -ph),
				center + Vector2(pw - drift, -ph),
				center + Vector2(pw - drift, -ph * 0.12),
				center + Vector2(pw * 0.18 - drift, ph * 0.06),
				center + Vector2(-pw * 0.34 - drift, -ph * 0.20),
				center + Vector2(-pw - drift, -ph * 0.04),
			])
			var pf_bot := PackedVector2Array([
				center + Vector2(-pw + drift, ph * 0.08),
				center + Vector2(-pw * 0.30 + drift, -ph * 0.08),
				center + Vector2(pw * 0.22 + drift, ph * 0.16),
				center + Vector2(pw + drift, ph * 0.02),
				center + Vector2(pw + drift, ph),
				center + Vector2(-pw + drift, ph),
			])
			for piece in [pf_top, pf_bot]:
				canvas.draw_colored_polygon(piece, Color(c.r, c.g, c.b, 0.20))
				canvas.draw_polyline(piece + PackedVector2Array([piece[0]]), c, 2.2, true)
		"god":
			# Boss oráculo. Era alvo concêntrico: lia como mira, não como
			# presença, e media ralo (0.133) porque tudo era alpha baixo.
			# Agora o contorno é um olho — forma inconfundível — com raios em
			# volta. Boss carrega mais detalhe que inimigo comum, de propósito.
			var rays := 12
			for i in rays:
				var ra := t * 0.25 + TAU * float(i) / float(rays)
				canvas.draw_line(
					center + Vector2.from_angle(ra) * radius * 0.88,
					center + Vector2.from_angle(ra) * radius * (1.16 + 0.10 * sin(t * 2.0 + float(i))),
					Color(c.r, c.g, c.b, 0.45), 2.4)
			var lens := PackedVector2Array()
			var lens_steps := 20
			for i in lens_steps + 1:
				var u := float(i) / float(lens_steps)
				lens.push_back(center + Vector2(lerpf(-radius * 0.86, radius * 0.86, u), -sin(u * PI) * radius * 0.48))
			for i in lens_steps + 1:
				var u2 := 1.0 - float(i) / float(lens_steps)
				lens.push_back(center + Vector2(lerpf(-radius * 0.86, radius * 0.86, u2), sin(u2 * PI) * radius * 0.48))
			canvas.draw_colored_polygon(lens, Color(c.r, c.g, c.b, 0.20))
			canvas.draw_polyline(lens + PackedVector2Array([lens[0]]), c, 3.0, true)
			canvas.draw_circle(center, radius * 0.30, Color(1.0, 0.92, 0.62, 0.92))
			canvas.draw_circle(center, radius * 0.13, Color(1.0, 0.25, 0.35, 1.0))
		"kernel":
			_dart(canvas, center, radius, c, 1.5, 1.0, 0.45)
			var hex := PackedVector2Array()
			for i in 6:
				hex.push_back(center + Vector2.from_angle(TAU * i / 6.0) * radius * 0.34)
			canvas.draw_polyline(hex + PackedVector2Array([hex[0]]), c, 1.6, true)
			canvas.draw_circle(center + Vector2(radius * 0.25, 0), radius * 0.22, c)
		"daemon":
			# Caçador de curta distância. Reusava o mesmo _dart do kernel e os
			# dois liam igual (IoU 0.725 medido). Agora o contorno é uma lâmina
			# bifurcada, com asas recuadas — leitura distinta do bico sólido.
			var fang := PackedVector2Array([
				center + Vector2(radius * 1.30, 0.0),
				center + Vector2(radius * 0.10, radius * 0.32),
				center + Vector2(-radius * 0.62, radius * 1.00),
				center + Vector2(-radius * 0.26, radius * 0.18),
				center + Vector2(-radius * 1.05, 0.0),
				center + Vector2(-radius * 0.26, -radius * 0.18),
				center + Vector2(-radius * 0.62, -radius * 1.00),
				center + Vector2(radius * 0.10, -radius * 0.32),
			])
			canvas.draw_colored_polygon(fang, Color(c.r, c.g, c.b, 0.20))
			canvas.draw_polyline(fang + PackedVector2Array([fang[0]]), c, 2.2, true)
		"rootlet":
			# Programa blindado do jogador. Era escudo de 6 pontos e ficou
			# parecido demais com o bulwark depois que este virou escudo
			# (IoU 0.482). Contorno ancorado: base chata e dois contrafortes —
			# leitura oposta à do escudo que afunila.
			var bw := radius * 0.88
			var anchor := PackedVector2Array([
				center + Vector2(-bw * 0.42, -radius * 0.92),
				center + Vector2(bw * 0.42, -radius * 0.92),
				center + Vector2(bw * 0.62, -radius * 0.24),
				center + Vector2(bw, -radius * 0.24),
				center + Vector2(bw, radius * 0.80),
				center + Vector2(bw * 0.52, radius * 0.80),
				center + Vector2(bw * 0.52, radius * 0.18),
				center + Vector2(-bw * 0.52, radius * 0.18),
				center + Vector2(-bw * 0.52, radius * 0.80),
				center + Vector2(-bw, radius * 0.80),
				center + Vector2(-bw, -radius * 0.24),
				center + Vector2(-bw * 0.62, -radius * 0.24),
			])
			canvas.draw_colored_polygon(anchor, Color(c.r, c.g, c.b, 0.16))
			canvas.draw_polyline(anchor + PackedVector2Array([anchor[0]]), c, 2.4, true)
			canvas.draw_arc(center - Vector2(0.0, radius * 0.30), radius * 0.30, 0, TAU, 24, Color(1, 1, 1, 0.7), 1.6, true)

## DESLIGADO por ora. O redesenho de silhuetas de 2026-09-11 tornou 19 dos 20
## sprites raster defasados — só `kernel` não mudou. Com o raster ligado, o
## bestiário ensinava o jogador a reconhecer formas que a arena não desenha
## mais, que é o pior lugar possível para essa divergência: o bestiário existe
## justamente para reconhecimento.
##
## Para religar, os PNGs em assets/sprites/generated/ precisam ser regerados a
## partir dos glifos atuais. Ver docs/superpowers/specs/2026-09-11-brief-sprites.md.
const USE_RASTER_PORTRAITS := false


## Retrato grande e estático: usaria o sprite raster quando existe, caindo no
## glifo desenhado em código quando não. Só para UI (menu, bestiário), onde a
## arte aparece grande o bastante para o detalhe do arquivo chegar na tela.
static func draw_portrait(canvas: CanvasItem, kind: String, center: Vector2, radius: float, color: Color, t: float = 0.0) -> void:
	if canvas == null or radius <= 0.0:
		return
	if USE_RASTER_PORTRAITS and EntitySprite.draw_entity(canvas, kind, center, radius * 2.4, color):
		return
	draw_glyph(canvas, kind, center, radius, color, t)


static func _dart(canvas: CanvasItem, center: Vector2, radius: float, c: Color, nose: float, wing: float, tail: float) -> void:
	var pts := PackedVector2Array([
		center + Vector2(radius * nose, 0), center + Vector2(-radius, radius * wing),
		center + Vector2(-radius * tail, 0), center + Vector2(-radius, -radius * wing),
	])
	canvas.draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.22))
	canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), c, 2.0, true)

static func _horn(canvas: CanvasItem, base: Vector2, size: float, c: Color, mirrored: bool = false) -> void:
	var sign_x := -1.0 if mirrored else 1.0
	var pts := PackedVector2Array([base, base + Vector2(sign_x * size * 0.8, -size * 1.9), base + Vector2(sign_x * size * 0.1, -size * 0.55)])
	canvas.draw_colored_polygon(pts, c)
