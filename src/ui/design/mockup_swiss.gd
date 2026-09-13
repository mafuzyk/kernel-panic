extends Control

## Estudo de direção: a referência editorial/suíça da autora traduzida para a
## estética dark neon do KERNEL PANIC.
##
## NÃO é código de produção — é maquete para decidir direção de arte. Se
## aprovada, vira componente de verdade sobre o design system.
##
## Rodar:
##   tools/virtual-session/kp-virtual.sh mockup over  /tmp/over.png
##   tools/virtual-session/kp-virtual.sh mockup menu  /tmp/menu.png
##   tools/virtual-session/kp-virtual.sh mockup pause /tmp/pause.png

## Grotesca pesada. Orbitron não consegue fazer isto: é uma display geométrica
## larga, vira logo de ficção científica em corpo grande, não tipografia suíça.
const GROTESK_PATH := "/usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf"

## Tag OpenType do eixo de peso ("wght" como inteiro).
## `TextServer.name_to_tag()` não é estático, então resolvemos uma vez aqui.
static var _WGHT_TAG: int = TextServerManager.get_primary_interface().name_to_tag("weight")

var _grotesk: FontFile


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_grotesk = FontFile.new()
	if _grotesk.load_dynamic_font(GROTESK_PATH) != OK:
		push_warning("grotesca não encontrada, caindo no Orbitron")
		_grotesk = null

	var bg := ColorRect.new()
	bg.color = Design.SURFACE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var screen := OS.get_environment("KP_MOCKUP")
	if screen == "":
		screen = "over"
	match screen:
		"menu": _screen_menu()
		"pause": _screen_pause()
		_: _screen_over()
	_capture_if_requested()


# ── tipografia ────────────────────────────────────────────────────────

func _grot(size: int, weight: int, color: Color) -> Label:
	var l := Label.new()
	if _grotesk != null:
		var fv := FontVariation.new()
		fv.base_font = _grotesk
		fv.variation_opentype = {_WGHT_TAG: weight}
		l.add_theme_font_override("font", fv)
	else:
		l.add_theme_font_override("font", Design.FONT_DISPLAY)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _mono(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", Design.FONT_MONO)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.text = text
	if parent != null:
		parent.add_child(l)
	return l


func _spacer(parent: Node, h: float, expand: bool = false) -> void:
	var s := Control.new()
	if expand:
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)


func _rule(parent: Node, opacity: float = 0.22) -> void:
	var r := ColorRect.new()
	r.color = Design.alpha(Design.TEXT_PRIMARY, opacity)
	r.custom_minimum_size = Vector2(0, 1)
	parent.add_child(r)


## Coluna raiz com as margens da página.
func _page(top: float = Design.SPACE_2XL, bottom: float = Design.SPACE_2XL) -> VBoxContainer:
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", Design.SPACE_4XL)
	pad.add_theme_constant_override("margin_right", Design.SPACE_4XL)
	pad.add_theme_constant_override("margin_top", int(top))
	pad.add_theme_constant_override("margin_bottom", int(bottom))
	add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	pad.add_child(col)
	return col


## Wordmark empilhado. Presente em toda tela — é a âncora da identidade.
func _wordmark(parent: Node, size: int = 30) -> void:
	var mark := VBoxContainer.new()
	mark.add_theme_constant_override("separation", int(-size * 0.2))
	var l1 := _grot(size, 900, Design.TEXT_PRIMARY); l1.text = "KERNEL"
	var l2 := _grot(size, 900, Design.TEXT_PRIMARY); l2.text = "PANIC"
	mark.add_child(l1); mark.add_child(l2)
	mark.add_child(_mono(null, "last process standing", Design.TEXT_MICRO, Design.TEXT_MUTED))
	parent.add_child(mark)


## Linha de estatística: rótulo mono pequeno em cima, número enorme embaixo.
## É este bloco que resolve estruturalmente as colunas desalinhadas de hoje —
## a informação vira layout em vez de string com espaços contados na mão.
func _stat_row(parent: Node, entries: Array, value_size: int = 52) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	for entry in entries:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", Design.SPACE_XS)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(_mono(null, str(entry[0]), Design.TEXT_CAPTION, Design.TEXT_MUTED))
		var v := _grot(value_size, 900, Design.TEXT_PRIMARY)
		v.text = str(entry[1])
		cell.add_child(v)
		row.add_child(cell)


## Ação primária: bloco sólido de acento com texto escuro. Em fundo escuro é a
## coisa mais forte que existe — não precisa de moldura nenhuma.
func _primary_action(label: String, key: String, tint: Color = Design.ACCENT) -> Control:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.content_margin_left = Design.SPACE_2XL
	sb.content_margin_right = Design.SPACE_2XL
	sb.content_margin_top = Design.SPACE_LG
	sb.content_margin_bottom = Design.SPACE_LG
	box.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Design.SPACE_2XL)
	var l := _grot(34, 800, Design.SURFACE)
	l.text = label
	row.add_child(l)
	row.add_child(_mono(null, key, Design.TEXT_CAPTION, Design.alpha(Design.SURFACE, 0.7)))
	box.add_child(row)
	return box


## Ação secundária: só tipo, sem moldura, sem preenchimento.
func _text_action(label: String, key: String, size: int = 26,
		color: Color = Design.TEXT_PRIMARY) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Design.SPACE_MD)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := _grot(size, 700, color)
	l.text = label
	row.add_child(l)
	if key != "":
		row.add_child(_mono(null, key, Design.TEXT_CAPTION, Design.TEXT_MUTED))
	return row


## Link terciário com sublinhado ancorado ao texto.
func _link(label: String, color: Color = Design.ACCENT) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Design.SPACE_XS)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(_mono(null, label, Design.TEXT_BODY, color))
	var u := ColorRect.new()
	u.color = color
	u.custom_minimum_size = Vector2(0, 1)
	col.add_child(u)
	return col


func _grow(parent: Node) -> void:
	var g := Control.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(g)


# ── TELA: GAME OVER ───────────────────────────────────────────────────

func _screen_over() -> void:
	var col := _page()

	var head := HBoxContainer.new()
	col.add_child(head)
	_wordmark(head)
	_grow(head)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", Design.SPACE_MD)
	hr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hr.add_child(_mono(null, "CORE DUMP", Design.TEXT_CAPTION, Design.TEXT_SECONDARY))
	var dash := ColorRect.new()
	dash.color = Design.alpha(Design.TEXT_PRIMARY, 0.5)
	dash.custom_minimum_size = Vector2(34, 1)
	dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(dash)
	head.add_child(hr)

	_spacer(col, 56)

	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", Design.SPACE_4XL)
	col.add_child(hero)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l1 := _grot(88, 900, Design.TEXT_PRIMARY); l1.text = "PROCESS"
	left.add_child(l1)
	var line2 := HBoxContainer.new()
	line2.add_theme_constant_override("separation", Design.SPACE_LG)
	var l2 := _grot(88, 900, Design.TEXT_PRIMARY); l2.text = "TERMINATED"
	line2.add_child(l2)
	var dot := ColorRect.new()
	dot.color = Design.DANGER
	dot.custom_minimum_size = Vector2(34, 34)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line2.add_child(dot)
	left.add_child(line2)
	_spacer(left, Design.SPACE_SM)
	_mono(left, "Encerrado por SPLITTER", Design.TEXT_SUBHEAD, Design.TEXT_SECONDARY)
	hero.add_child(left)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", Design.SPACE_XS)
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(_mono(null, "PONTUAÇÃO", Design.TEXT_SUBHEAD, Design.TEXT_SECONDARY))
	var score := _grot(72, 900, Design.TEXT_PRIMARY); score.text = "0000350"
	right.add_child(score)
	right.add_child(_mono(null, "NOVO RECORDE", Design.TEXT_SUBHEAD, Design.DANGER))
	hero.add_child(right)

	_spacer(col, 40)
	_rule(col)
	_spacer(col, 28)
	_stat_row(col, [
		["CICLOS", "1"], ["DAEMONS ELIMINADOS", "3"],
		["TEMPO", "00:05"], ["PRECISÃO", "17%"],
	])
	_spacer(col, 20)
	_mono(col, "KERNEL / SEM PATCHES", Design.TEXT_CAPTION, Design.TEXT_MUTED)
	_spacer(col, 0, true)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", Design.SPACE_2XL)
	col.add_child(actions)
	actions.add_child(_primary_action("Reiniciar", "[ENTER]"))
	actions.add_child(_text_action("Voltar ao menu", "[ESC]"))
	_grow(actions)
	var diag := _link("Ver diagnóstico  →")
	diag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	diag.size_flags_horizontal = Control.SIZE_SHRINK_END
	actions.add_child(diag)


# ── TELA: MENU ────────────────────────────────────────────────────────

func _screen_menu() -> void:
	var col := _page()
	var head := HBoxContainer.new()
	col.add_child(head)
	_wordmark(head, 38)
	_grow(head)
	head.add_child(_mono(null, "v2.5.0  //  purge loop online", Design.TEXT_CAPTION, Design.TEXT_MUTED))

	_spacer(col, 0, true)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", Design.SPACE_4XL)
	col.add_child(body)

	# esquerda: silhueta do programa ativo, chapada, tingida com o acento.
	# Usa o asset real de assets/sprites/generated (base branca, tingível).
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", Design.SPACE_LG)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var art := TextureRect.new()
	art.texture = load("res://assets/sprites/generated/kernel.png")
	art.modulate = Design.ACCENT
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(0, 400)
	left.add_child(art)
	var prog := VBoxContainer.new()
	prog.add_theme_constant_override("separation", Design.SPACE_XS)
	prog.add_child(_mono(null, "PROGRAMA ATIVO", Design.TEXT_MICRO, Design.TEXT_MUTED))
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", Design.SPACE_LG)
	var pn := _grot(26, 900, Design.TEXT_PRIMARY); pn.text = "KERNEL"
	prow.add_child(pn)
	var swap := _link("Trocar")
	swap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow.add_child(swap)
	prog.add_child(prow)
	left.add_child(prog)
	body.add_child(left)

	# direita: a ação. PURGE é a única coisa em ciano — hierarquia por cor.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var prow2 := HBoxContainer.new()
	prow2.add_theme_constant_override("separation", Design.SPACE_XL)
	var arrow := _grot(64, 900, Design.ACCENT); arrow.text = "→"
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow2.add_child(arrow)
	var purge := _grot(104, 900, Design.ACCENT); purge.text = "PURGE"
	prow2.add_child(purge)
	right.add_child(prow2)
	_spacer(right, Design.SPACE_SM)
	_mono(right, "CLÁSSICO  /  NORMAL", Design.TEXT_SUBHEAD, Design.TEXT_SECONDARY)
	_spacer(right, Design.SPACE_MD)
	right.add_child(_link("Configurar partida"))

	_spacer(right, Design.SPACE_3XL)
	var short_rule := ColorRect.new()
	short_rule.color = Design.alpha(Design.TEXT_PRIMARY, 0.3)
	short_rule.custom_minimum_size = Vector2(48, 1)
	right.add_child(short_rule)
	_spacer(right, Design.SPACE_XL)

	for item in ["História", "Arquivos"]:
		var e := _grot(44, 900, Design.TEXT_PRIMARY)
		e.text = item
		right.add_child(e)
		_spacer(right, Design.SPACE_SM)
	body.add_child(right)

	_spacer(col, 0, true)
	_rule(col, 0.18)
	_spacer(col, Design.SPACE_LG)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", Design.SPACE_LG)
	col.add_child(foot)
	foot.add_child(_mono(null, "ENTER", Design.TEXT_CAPTION, Design.ACCENT))
	foot.add_child(_mono(null, "Iniciar", Design.TEXT_CAPTION, Design.TEXT_SECONDARY))
	_grow(foot)
	foot.add_child(_mono(null, "Configurações", Design.TEXT_CAPTION, Design.TEXT_SECONDARY))
	foot.add_child(_mono(null, "|", Design.TEXT_CAPTION, Design.TEXT_FAINT))
	foot.add_child(_mono(null, "Sair", Design.TEXT_CAPTION, Design.TEXT_SECONDARY))


# ── TELA: PAUSA ───────────────────────────────────────────────────────

func _screen_pause() -> void:
	# a pausa fica SOBRE o jogo: véu translúcido, não superfície opaca.
	# Grade fraca atrás para o teste de legibilidade ser honesto.
	_fake_arena_behind()
	var veil := ColorRect.new()
	veil.color = Design.SCRIM
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

	var col := _page()
	var head := HBoxContainer.new()
	col.add_child(head)
	_wordmark(head, 24)
	_grow(head)
	head.add_child(_mono(null, "RUN STATE FROZEN", Design.TEXT_CAPTION, Design.TEXT_SECONDARY))

	_spacer(col, 0, true)

	var t := _grot(112, 900, Design.TEXT_PRIMARY); t.text = "PAUSADO"
	col.add_child(t)
	_spacer(col, Design.SPACE_SM)
	_mono(col, "O processo continua quando você mandar", Design.TEXT_SUBHEAD, Design.TEXT_SECONDARY)

	_spacer(col, 40)
	_rule(col)
	_spacer(col, 28)
	_stat_row(col, [
		["CICLO", "07"], ["PONTUAÇÃO", "0012480"],
		["CADEIA", "x3"], ["INTEGRIDADE", "2/4"],
	], 44)
	_spacer(col, 20)
	_mono(col, "KERNEL / RICOCHETE +1 / ROUNDS PESADOS", Design.TEXT_CAPTION, Design.TEXT_MUTED)

	_spacer(col, 0, true)

	# mixagem: sliders reduzidos a trilho + preenchimento, sem moldura
	var mix := HBoxContainer.new()
	mix.add_theme_constant_override("separation", Design.SPACE_3XL)
	col.add_child(mix)
	for entry in [["SFX", 0.9], ["MÚSICA", 0.75]]:
		var m := VBoxContainer.new()
		m.add_theme_constant_override("separation", Design.SPACE_SM)
		m.custom_minimum_size = Vector2(320, 0)
		var lrow := HBoxContainer.new()
		lrow.add_child(_mono(null, str(entry[0]), Design.TEXT_CAPTION, Design.TEXT_MUTED))
		_grow(lrow)
		lrow.add_child(_mono(null, "%d%%" % int(float(entry[1]) * 100.0),
			Design.TEXT_CAPTION, Design.TEXT_SECONDARY))
		m.add_child(lrow)
		var track := Control.new()
		track.custom_minimum_size = Vector2(0, 3)
		var back := ColorRect.new()
		back.color = Design.alpha(Design.TEXT_PRIMARY, 0.18)
		back.set_anchors_preset(Control.PRESET_FULL_RECT)
		track.add_child(back)
		var fill := ColorRect.new()
		fill.color = Design.ACCENT
		fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		fill.anchor_right = float(entry[1])
		track.add_child(fill)
		m.add_child(track)
		mix.add_child(m)
	_grow(mix)

	_spacer(col, Design.SPACE_2XL)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", Design.SPACE_2XL)
	col.add_child(actions)
	actions.add_child(_primary_action("Continuar", "[ESC]"))
	actions.add_child(_text_action("Reiniciar", "[R]"))
	actions.add_child(_text_action("Terminal", "[T]"))
	_grow(actions)
	# abandono em vermelho, afastado das ações seguras
	var quit_action := _text_action("Abandonar processo", "[Q] [Q]", 22, Design.DANGER)
	quit_action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_child(quit_action)


func _fake_arena_behind() -> void:
	var grid := Control.new()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid)
	for i in range(0, 40):
		var v := ColorRect.new()
		v.color = Design.alpha(Design.ACCENT, 0.10)
		v.position = Vector2(i * 52, 0)
		v.size = Vector2(1, 1080)
		grid.add_child(v)
	for j in range(0, 22):
		var h := ColorRect.new()
		h.color = Design.alpha(Design.ACCENT, 0.10)
		h.position = Vector2(0, j * 52)
		h.size = Vector2(1920, 1)
		grid.add_child(h)


func _capture_if_requested() -> void:
	var out := OS.get_environment("KP_SHOT_OUT")
	if out == "":
		return
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SHOT_SAVED ", out, " ", img.get_width(), "x", img.get_height())
	get_tree().quit(0)
