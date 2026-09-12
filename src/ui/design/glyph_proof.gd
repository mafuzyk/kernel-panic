extends Control

## Folha de prova dos glifos desenhados em código.
##
## Renderiza cada entidade em três tamanhos e mede a cobertura, para que
## refinamento de arte seja verificável em vez de opinião:
##   - tamanho REAL em que a arena desenha (raio da entidade)
##   - ampliação 4x sem suavizar, para inspecionar o traço
##   - 24px, o teste de legibilidade mínima
##
## Imprime as medições em stdout com prefixo GLYPH_METRIC para o autotest.
##
## Rodar:
##   tools/virtual-session/kp-virtual.sh glyphs /tmp/glifos.png

## Raio com que cada entidade é desenhada na arena. Fonte: o `radius` de cada
## script em src/enemies/ (e player.gd). Mantido aqui porque a folha de prova
## precisa saber o tamanho de exibição real, não o nominal.
const ARENA_RADIUS := {
	"drone": 13.0, "lancer": 12.0, "spewer": 15.0, "splitter": 18.0,
	"bulwark": 26.0, "trojan": 15.0, "recursor": 13.0, "firewall": 16.0,
	"oom": 14.0, "update_loop": 16.0, "bloatware": 34.0, "page": 13.0,
	"segfault": 13.0, "bluescreen": 13.0, "pagefault": 13.0,
	"root": 52.0, "boss": 52.0, "god": 56.0,
	"kernel": 13.0, "daemon": 13.0, "rootlet": 13.0,
}

## Faixa de cobertura no tamanho real, calibrada sobre a distribuição medida
## do conjunto (q1 0.20, mediana 0.37, q3 0.44) e deliberadamente LARGA.
##
## Esta métrica serve para pegar extremos — glifo que some ou que empasta —
## não para prescrever densidade: o `kernel` tem 0.54 e lê muito bem. A
## métrica que realmente governa distinção é a de similaridade de silhueta,
## em `_report_similarity()`.
const COVERAGE_MIN := 0.15
const COVERAGE_MAX := 0.55

const COLS := 5
const CELL_W := 260.0
const CELL_H := 330.0
## Meia-altura da caixa de inspeção. Todo glifo é desenhado para caber nela,
## então formas de raio muito diferente ficam comparáveis.
const INSPECT_BOX := 78.0

var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_report.call_deferred()


func _process(delta: float) -> void:
	# glifos animados usam t; congelamos num valor fixo para a captura ser
	# determinística, mas deixamos avançar quando inspecionado ao vivo.
	if OS.get_environment("KP_SHOT_OUT") == "":
		_t += delta
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Design.SURFACE)
	var kinds := GlyphLib.glyph_kinds()
	var mono: Font = Design.FONT_MONO
	for i in kinds.size():
		var kind := str(kinds[i])
		var col := i % COLS
		var row := i / COLS
		var origin := Vector2(col * CELL_W + 20.0, row * CELL_H + 24.0)
		var radius: float = float(ARENA_RADIUS.get(kind, 14.0))
		var extent: float = maxf(GlyphLib.glyph_extent(kind), 1.0)

		# 1. inspeção em tamanho NORMALIZADO: todos ocupam a mesma caixa,
		# independente do raio de arena. É o que torna espessura de traço e
		# densidade comparáveis entre entidades — um boss de raio 56 e um
		# drone de raio 13 precisam ser julgados lado a lado.
		var inspect_radius: float = INSPECT_BOX / extent
		var zoom_center := origin + Vector2(CELL_W * 0.5 - 20.0, INSPECT_BOX + 10.0)
		GlyphLib.draw_glyph(self, kind, zoom_center, inspect_radius, Design.ACCENT, _t)

		# 2. tamanho real da arena e 3. teste de legibilidade em 24px
		var base_y := origin.y + INSPECT_BOX * 2.0 + 34.0
		GlyphLib.draw_glyph(self, kind, Vector2(origin.x + 44.0, base_y), radius, Design.ACCENT, _t)
		GlyphLib.draw_glyph(self, kind, Vector2(origin.x + 124.0, base_y), 12.0, Design.ACCENT, _t)

		draw_string(mono, Vector2(origin.x, base_y + 44.0), kind,
			HORIZONTAL_ALIGNMENT_LEFT, -1, Design.TEXT_CAPTION, Design.TEXT_PRIMARY)
		draw_string(mono, Vector2(origin.x, base_y + 62.0),
			"arena %dpx      24px" % int(radius * 2.0),
			HORIZONTAL_ALIGNMENT_LEFT, -1, Design.TEXT_MICRO, Design.TEXT_MUTED)


## Mede a cobertura de cada glifo renderizando-o isolado num viewport pequeno.
## É o número que torna "simples mas não feio" verificável: cobertura fora da
## faixa significa que o glifo some ou empasta, independente do desenho.
func _report() -> void:
	for kind in GlyphLib.glyph_kinds():
		var radius: float = float(ARENA_RADIUS.get(str(kind), 14.0))
		var cov := await _measure(str(kind), radius)
		var verdict := "ok"
		if cov < COVERAGE_MIN:
			verdict = "RARO"
		elif cov > COVERAGE_MAX:
			verdict = "DENSO"
		print("GLYPH_METRIC %s size=%d coverage=%.3f %s"
			% [kind, int(radius * 2.0), cov, verdict])
	await _report_similarity()
	await _report_patch_similarity()
	_capture_if_requested()


## Distinção de silhueta: a função de um glifo de inimigo é ser reconhecido de
## relance. Renderiza cada um como máscara binária em 24px e compara par a par
## por interseção-sobre-união. Pares acima de ~0.55 são confundíveis em jogo.
func _report_similarity() -> void:
	var masks := {}
	for kind in GlyphLib.glyph_kinds():
		masks[str(kind)] = await _mask_24(str(kind))
	var kinds: Array = masks.keys()
	var pairs := []
	for i in kinds.size():
		for j in range(i + 1, kinds.size()):
			var a: Array = masks[kinds[i]]
			var b: Array = masks[kinds[j]]
			var inter := 0
			var uni := 0
			for n in a.size():
				var pa: bool = a[n]
				var pb: bool = b[n]
				if pa and pb:
					inter += 1
				if pa or pb:
					uni += 1
			if uni > 0:
				pairs.append([float(inter) / float(uni), kinds[i], kinds[j]])
	pairs.sort_custom(func(x, y): return x[0] > y[0])
	for k in mini(12, pairs.size()):
		var pr: Array = pairs[k]
		print("GLYPH_SIMILAR %.3f %s <-> %s" % [pr[0], pr[1], pr[2]])


## Mesma prova, aplicada às famílias de ícone dos patches.
##
## São 26 patches e SEIS símbolos: cada família é compartilhada por até oito
## cartas. Isso já é pouca distinção; se as seis famílias ainda se parecerem
## entre si, a coluna do ícone deixa de informar qualquer coisa e vira ruído
## decorativo ao lado do título.
func _report_patch_similarity() -> void:
	var families := ["damage", "fire", "defense", "utility", "movement", "economy"]
	var masks := {}
	for family in families:
		masks[str(family)] = await _patch_mask(str(family))
	var pairs := []
	for i in families.size():
		for j in range(i + 1, families.size()):
			var a: Array = masks[families[i]]
			var b: Array = masks[families[j]]
			var inter := 0
			var uni := 0
			for n in a.size():
				var pa: bool = a[n]
				var pb: bool = b[n]
				if pa and pb:
					inter += 1
				if pa or pb:
					uni += 1
			if uni > 0:
				pairs.append([float(inter) / float(uni), families[i], families[j]])
	pairs.sort_custom(func(x, y): return x[0] > y[0])
	for pr in pairs:
		var pair: Array = pr
		print("PATCH_SIMILAR %.3f %s <-> %s" % [pair[0], pair[1], pair[2]])


func _patch_mask(family: String) -> Array:
	var box := 48
	var vp := SubViewport.new()
	vp.size = Vector2i(box, box)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var probe := _PatchProbe.new()
	probe.family = family
	probe.size = Vector2(box, box)
	vp.add_child(probe)
	add_child(vp)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var raw := []
	for y in box:
		for x in box:
			raw.append(img.get_pixel(x, y).a > 0.35)
	vp.queue_free()
	return _dilate(raw, box, 3)


## Dilata a máscara antes de comparar.
##
## Correção de método, 2026-09-12. A prova de silhueta de INIMIGO compara
## máscaras cruas e funciona, porque aqueles glifos são preenchidos. Os ícones
## de patch são de CONTORNO: traço de 2px sobre vazio. Duas formas com o mesmo
## contorno externo — um hexágono e outro hexágono — dão interseção quase zero
## em máscara crua, porque os traços quase não se tocam, e a métrica declara
## "distintas" duas coisas que o olho lê como a mesma.
##
## Dilatar transforma o traço no BLOCO que ele delimita, que é o que a visão
## periférica registra a essa distância. É a mesma pergunta de antes — "isso se
## confunde de relance?" — feita sobre o dado certo.
static func _dilate(mask: Array, box: int, radius: int) -> Array:
	var out := []
	out.resize(mask.size())
	for y in box:
		for x in box:
			var on := false
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= box or ny >= box:
						continue
					if bool(mask[ny * box + nx]):
						on = true
						break
				if on:
					break
			out[y * box + x] = on
	return out


## Nó mínimo que desenha um ícone de família isolado, para medição. Reusa o
## desenho real do card — medir uma cópia seria medir ficção.
class _PatchProbe extends Control:
	var family := "damage"

	func _draw() -> void:
		PatchCard.draw_family_glyph(self, family, size * 0.5, Color.WHITE)


func _mask_24(kind: String) -> Array:
	var box := 48
	var vp := SubViewport.new()
	vp.size = Vector2i(box, box)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var probe := _GlyphProbe.new()
	probe.kind = kind
	probe.radius = 12.0
	probe.centre = Vector2(box, box) * 0.5
	vp.add_child(probe)
	add_child(vp)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var raw := []
	for y in box:
		for x in box:
			raw.append(img.get_pixel(x, y).a > 0.35)
	vp.queue_free()
	# Dilatada igual à dos patches, para as duas provas ficarem na MESMA escala.
	# Os glifos de inimigo são a régua: eles já foram aprovados no jogo, então o
	# maior par deles é o que "aceitável" significa nesta métrica. Comparar um
	# número dilatado com um limiar de máscara crua é comparar réguas diferentes.
	return _dilate(raw, box, 3)


func _measure(kind: String, radius: float) -> float:
	var extent: float = GlyphLib.glyph_extent(kind)
	var box := int(ceil(radius * 2.0 * maxf(extent, 1.0))) + 4
	var vp := SubViewport.new()
	vp.size = Vector2i(box, box)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var probe := _GlyphProbe.new()
	probe.kind = kind
	probe.radius = radius
	probe.centre = Vector2(box, box) * 0.5
	vp.add_child(probe)
	add_child(vp)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var on := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.35:
				on += 1
	vp.queue_free()
	# Normaliza pela área NOMINAL de exibição (raio*2)², não pela caixa do
	# extent. Glifos alongados (lancer alcança 2.4x o raio) têm caixa grande e
	# apareceriam falsamente ralos se medidos contra ela — o que importa é
	# quanta tinta existe no tamanho em que o jogador vê.
	var nominal := radius * 2.0
	return float(on) / float(maxf(nominal * nominal, 1.0))


## Nó mínimo que desenha um glifo isolado, para medição.
class _GlyphProbe extends Node2D:
	var kind := ""
	var radius := 14.0
	var centre := Vector2.ZERO

	func _draw() -> void:
		GlyphLib.draw_glyph(self, kind, centre, radius, Color.WHITE, 0.0)


func _capture_if_requested() -> void:
	var out := OS.get_environment("KP_SHOT_OUT")
	if out == "":
		return
	queue_redraw()
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SHOT_SAVED ", out, " ", img.get_width(), "x", img.get_height())
	get_tree().quit(0)
