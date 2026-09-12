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
	if OS.get_environment("KP_METRIC_SWEEP") != "":
		await _report_metric_sweep()
		await _report_patch_sweep()
	_capture_if_requested()


## Distinção de silhueta: a função de um glifo de inimigo é ser reconhecido de
## relance. Renderiza cada um como máscara binária e compara par a par por
## interseção-sobre-união.
##
## Limiar 0.55, VALIDADO pela varredura de 2026-09-12 nesta configuração: o par
## idêntico dá 1.000 e o maior par distinto do conjunto aprovado dá 0.336, então
## 0.55 fica com folga dos dois lados. O `0.55` sempre foi certo para máscara
## CRUA — o erro tinha sido aplicá-lo à máscara dilatada, onde o conjunto
## aprovado já marcava 0.892 e reprovaria a si mesmo.
const SILHOUETTE_MAX := 0.55
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
		var verdict := "ok" if pr[0] < SILHOUETTE_MAX else "CONFUNDIVEL"
		print("GLYPH_SIMILAR %.3f %s <-> %s %s" % [pr[0], pr[1], pr[2], verdict])


## Varredura de calibração da métrica de silhueta.
##
## O problema: `0.55` veio da métrica de máscara CRUA e não transfere para a
## dilatada. Escolher um número novo no olho seria trocar um palpite por outro.
##
## Existe um ponto de verdade: `root` e `boss` desenham o MESMO glifo. Uma
## métrica útil tem de dar ~1.0 neles e claramente menos em todo o resto — o
## que interessa é a MARGEM entre o par idêntico e o segundo colocado. Quanto
## maior a margem, mais poder de discriminação o número tem.
##
## Roda sob `KP_METRIC_SWEEP=1` porque é caro: nove combinações de raio e caixa.
func _report_metric_sweep() -> void:
	var kinds: Array = GlyphLib.glyph_kinds()
	for box in [48, 64, 96]:
		for radius in [0, 1, 2, 3]:
			var masks := {}
			for kind in kinds:
				masks[str(kind)] = await _sweep_mask(str(kind), int(box), int(radius))
			var identical := 0.0
			var runner_up := 0.0
			for i in kinds.size():
				for j in range(i + 1, kinds.size()):
					var score := _iou(masks[kinds[i]], masks[kinds[j]])
					var pair_is_root: bool = (str(kinds[i]) == "root" and str(kinds[j]) == "boss") \
						or (str(kinds[i]) == "boss" and str(kinds[j]) == "root")
					if pair_is_root:
						identical = score
					else:
						runner_up = maxf(runner_up, score)
			print("METRIC_SWEEP box=%d radius=%d identical=%.3f runner_up=%.3f margin=%.3f"
				% [int(box), int(radius), identical, runner_up, identical - runner_up])


## Varredura de calibração da métrica de CONTORNO.
##
## A varredura de inimigo não vale aqui. O ponto de verdade dela é `root` e
## `boss`, dois glifos PREENCHIDOS; ícone de patch é traço de 2px sobre vazio.
## Aplicar um número calibrado em massa a uma forma de contorno repetiria
## exatamente o erro que o `0.55` cometeu.
##
## Ponto de verdade próprio: o MESMO ícone deslocado 1px continua sendo o
## mesmo ícone. Uma métrica útil para contorno tem de dar alto nele — é para
## isso que a dilatação existe, tolerar desregistro de traço — e baixo entre
## famílias diferentes. De novo o que interessa é a MARGEM.
func _report_patch_sweep() -> void:
	var families := ["damage", "fire", "defense", "utility", "movement", "economy"]
	for box in [48, 64, 96]:
		for radius in [0, 1, 2, 3]:
			var masks := {}
			for family in families:
				masks[str(family)] = await _patch_sweep_mask(str(family), int(box), int(radius), Vector2.ZERO)
			# o mesmo ícone, deslocado: tem de continuar sendo ele mesmo
			var shifted := await _patch_sweep_mask("damage", int(box), int(radius), Vector2.ONE)
			var identical := _iou(masks["damage"], shifted)
			var runner_up := 0.0
			for i in families.size():
				for j in range(i + 1, families.size()):
					runner_up = maxf(runner_up, _iou(masks[families[i]], masks[families[j]]))
			print("PATCH_SWEEP box=%d radius=%d identical=%.3f runner_up=%.3f margin=%.3f"
				% [int(box), int(radius), identical, runner_up, identical - runner_up])


func _patch_sweep_mask(family: String, box: int, radius: int, offset: Vector2) -> Array:
	var vp := SubViewport.new()
	vp.size = Vector2i(box, box)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var probe := _PatchProbe.new()
	probe.family = family
	probe.offset = offset
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
	return raw if radius <= 0 else _dilate(raw, box, radius)


static func _iou(a: Array, b: Array) -> float:
	var inter := 0
	var uni := 0
	for n in a.size():
		var pa: bool = a[n]
		var pb: bool = b[n]
		if pa and pb:
			inter += 1
		if pa or pb:
			uni += 1
	return float(inter) / float(maxi(uni, 1))


func _sweep_mask(kind: String, box: int, radius: int) -> Array:
	var vp := SubViewport.new()
	vp.size = Vector2i(box, box)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var probe := _GlyphProbe.new()
	probe.kind = kind
	probe.radius = float(box) * 0.25
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
	return raw if radius <= 0 else _dilate(raw, box, radius)


## Mesma prova, aplicada às famílias de ícone dos patches.
##
## São 26 patches e SEIS símbolos: cada família é compartilhada por até oito
## cartas. Isso já é pouca distinção; se as seis famílias ainda se parecerem
## entre si, a coluna do ícone deixa de informar qualquer coisa e vira ruído
## decorativo ao lado do título.
## Similaridade de ícone de patch: RELATÓRIO, sem limiar. Deliberado.
##
## A varredura de contorno de 2026-09-12 procurou um limiar e mostrou que não
## existe um utilizável. Ponto de verdade: o MESMO ícone deslocado 1px.
##
##   raio=0 -> mesmo ícone 0.410, famílias distintas 0.319, margem 0.091
##   raio=2 -> mesmo ícone 0.709, famílias distintas 0.505, margem 0.205
##   raio=3 -> mesmo ícone 0.760, famílias distintas 0.560, margem 0.199
##
## No melhor caso o mesmo ícone marca 0.760 e dois ícones DIFERENTES marcam
## 0.560. As faixas quase se encostam, e 1px de desregistro está dentro da
## variação normal de render. Qualquer limiar aqui reprovaria desenhos bons ou
## aprovaria colisões reais, dependendo do pixel.
##
## A causa é a representação, não a métrica: interseção sobre união compara
## ÁREA, e estes ícones são traço de 2px sobre vazio — quase toda a área é
## fundo compartilhado. Para virar critério, precisaria de um descritor de
## FORMA, não de área. Até lá o número serve para comparar versões do mesmo
## ícone, não para aprovar ou reprovar um ícone sozinho.
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
	## Deslocamento em pixels. Serve ao ponto de verdade da varredura de
	## contorno: o MESMO ícone deslocado continua sendo o mesmo ícone.
	var offset := Vector2.ZERO

	func _draw() -> void:
		PatchCard.draw_family_glyph(self, family, size * 0.5 + offset, Color.WHITE)


## Máscara de silhueta de inimigo, na configuração VARRIDA (2026-09-12).
##
## box=96 raio=0. A varredura mediu as doze combinações contra o ponto de
## verdade `root`/`boss` (o mesmo glifo desenhado duas vezes) e a margem entre
## o par idêntico e o segundo colocado cai de forma monótona com a dilatação:
##
##   box=96 raio=0 -> idêntico 1.000, 2º 0.336, margem 0.664  <- escolhido
##   box=96 raio=3 -> idêntico 1.000, 2º 0.728, margem 0.272
##   box=48 raio=3 -> idêntico 1.000, 2º 0.892, margem 0.108  <- config antiga
##
## Ou seja: dilatar não dava sensibilidade, dava BORRÃO. O segundo colocado
## subindo de 0.336 para 0.892 é a métrica perdendo a capacidade de separar
## formas diferentes, não ganhando a de detectar formas parecidas.
func _mask_24(kind: String) -> Array:
	var box := 96
	var vp := SubViewport.new()
	vp.size = Vector2i(box, box)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var probe := _GlyphProbe.new()
	probe.kind = kind
	probe.radius = float(box) * 0.25
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
	return raw


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
