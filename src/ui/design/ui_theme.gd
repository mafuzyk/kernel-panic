class_name UiTheme
extends RefCounted

## Constrói o `Theme` do KERNEL PANIC a partir dos tokens de `Design`.
##
## Substitui o padrão atual de estilizar cada widget à mão: hoje o projeto tem
## 310 chamadas `add_theme_*_override` e 83 `load()` de fonte espalhados por 19
## arquivos. Com um Theme aplicado na raiz, um `Label` novo já nasce certo e
## um `Button` novo já nasce com hover, pressed, foco e disabled.
##
## Uso:
##     var root := get_tree().root
##     root.theme = UiTheme.build()
##
## Variações de tipo disponíveis (atribua em `Control.theme_type_variation`):
##     DisplayLabel  TitleLabel  HeadingLabel  SubheadLabel
##     BodyLabel     CaptionLabel  MicroLabel
##     MutedLabel    FaintLabel    DangerLabel   WarningLabel  SuccessLabel
##     PrimaryButton DangerButton  GhostButton

const _LABEL_VARIANTS := {
	"DisplayLabel": {"font": "display", "size": Design.TEXT_DISPLAY, "color": Design.TEXT_PRIMARY},
	"TitleLabel": {"font": "display", "size": Design.TEXT_TITLE, "color": Design.TEXT_PRIMARY},
	"HeadingLabel": {"font": "display", "size": Design.TEXT_HEADING, "color": Design.TEXT_PRIMARY},
	"SubheadLabel": {"font": "mono", "size": Design.TEXT_SUBHEAD, "color": Design.TEXT_PRIMARY},
	"BodyLabel": {"font": "mono", "size": Design.TEXT_BODY, "color": Design.TEXT_PRIMARY},
	"CaptionLabel": {"font": "mono", "size": Design.TEXT_CAPTION, "color": Design.TEXT_SECONDARY},
	"MicroLabel": {"font": "mono", "size": Design.TEXT_MICRO, "color": Design.TEXT_MUTED},
	"MutedLabel": {"font": "mono", "size": Design.TEXT_BODY, "color": Design.TEXT_MUTED},
	"FaintLabel": {"font": "mono", "size": Design.TEXT_CAPTION, "color": Design.TEXT_FAINT},
	"DangerLabel": {"font": "mono", "size": Design.TEXT_BODY, "color": Design.DANGER},
	"WarningLabel": {"font": "mono", "size": Design.TEXT_BODY, "color": Design.WARNING},
	"SuccessLabel": {"font": "mono", "size": Design.TEXT_BODY, "color": Design.SUCCESS},
}

## Botões por papel. A ação primária precisa DOMINAR a secundária: só variar
## o alpha de preenchimento não resolve — some no fundo escuro. Ela ganha
## traço mais grosso, preenchimento maior e tipo maior.
const _BUTTON_VARIANTS := {
	"": {"accent": Design.ACCENT, "fill": 0.03, "stroke": Design.STROKE_HAIRLINE,
		"size": Design.TEXT_SUBHEAD},
	"PrimaryButton": {"accent": Design.ACCENT, "fill": 0.18, "stroke": Design.STROKE_REGULAR,
		"size": Design.TEXT_HEADING},
	"DangerButton": {"accent": Design.DANGER, "fill": 0.07, "stroke": Design.STROKE_HAIRLINE,
		"size": Design.TEXT_SUBHEAD},
	"GhostButton": {"accent": Design.ACCENT_MUTED, "fill": 0.0,
		"stroke": Design.STROKE_HAIRLINE, "size": Design.TEXT_BODY},
}


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = Design.FONT_MONO
	theme.default_font_size = Design.TEXT_BODY

	_build_labels(theme)
	_build_buttons(theme)
	_build_panels(theme)
	_build_sliders(theme)
	_build_containers(theme)
	return theme


static func _font_for(kind: String) -> Font:
	return Design.FONT_DISPLAY if kind == "display" else Design.FONT_MONO


static func _build_labels(theme: Theme) -> void:
	theme.set_font("font", "Label", Design.FONT_MONO)
	theme.set_font_size("font_size", "Label", Design.TEXT_BODY)
	theme.set_color("font_color", "Label", Design.TEXT_PRIMARY)

	for key in _LABEL_VARIANTS:
		var variant_name := str(key)
		var spec: Dictionary = _LABEL_VARIANTS[key]
		theme.set_type_variation(variant_name, "Label")
		theme.set_font("font", variant_name, _font_for(str(spec["font"])))
		theme.set_font_size("font_size", variant_name, int(spec["size"]))
		theme.set_color("font_color", variant_name, spec["color"])


static func _build_buttons(theme: Theme) -> void:
	for key in _BUTTON_VARIANTS:
		var variant_name := str(key)
		var spec: Dictionary = _BUTTON_VARIANTS[key]
		var accent: Color = spec["accent"]
		var fill: float = float(spec["fill"])
		var target: String = variant_name if variant_name != "" else "Button"
		if variant_name != "":
			theme.set_type_variation(variant_name, "Button")

		var base := TacticalStyleBox.new()
		base.accent = accent
		base.fill_alpha = fill
		base.stroke = float(spec["stroke"])
		base.rail_length = 68.0

		theme.set_stylebox("normal", target, base)
		theme.set_stylebox("hover", target,
			base.variant(Design.shade(accent, Design.STATE_HOVER_BOOST), fill + 0.06))
		theme.set_stylebox("pressed", target,
			base.variant(Design.shade(accent, Design.STATE_PRESSED_BOOST), fill + 0.12))
		theme.set_stylebox("focus", target,
			base.variant(accent, fill + 0.04, true))
		theme.set_stylebox("disabled", target,
			base.variant(Design.alpha(accent, Design.STATE_DISABLED_ALPHA), 0.0))

		theme.set_font("font", target, Design.FONT_MONO)
		theme.set_font_size("font_size", target, int(spec["size"]))
		theme.set_color("font_color", target, Design.TEXT_PRIMARY)
		theme.set_color("font_hover_color", target, Design.TEXT_PRIMARY)
		theme.set_color("font_pressed_color", target, accent)
		theme.set_color("font_focus_color", target, Design.TEXT_PRIMARY)
		theme.set_color("font_disabled_color", target, Design.TEXT_FAINT)
		theme.set_constant("h_separation", target, Design.SPACE_SM)


static func _build_panels(theme: Theme) -> void:
	var surface := StyleBoxFlat.new()
	surface.bg_color = Design.SURFACE
	theme.set_stylebox("panel", "Panel", surface)

	## Painel táctico: use `theme_type_variation = "TacticalPanel"`.
	var tactical := TacticalStyleBox.new()
	tactical.accent = Design.ACCENT
	tactical.fill_alpha = 0.04
	theme.set_type_variation("TacticalPanel", "Panel")
	theme.set_stylebox("panel", "TacticalPanel", tactical)

	## Overlay OPACO por contrato. Quatro painéis usavam alphas diferentes e o
	## de conquistas (0.88) deixava o menu vazar por trás.
	var overlay := StyleBoxFlat.new()
	overlay.bg_color = Design.SURFACE
	theme.set_type_variation("OverlayPanel", "Panel")
	theme.set_stylebox("panel", "OverlayPanel", overlay)

	## Véu translúcido sobre a cena de jogo — aqui a transparência é intencional.
	var scrim := StyleBoxFlat.new()
	scrim.bg_color = Design.SCRIM
	theme.set_type_variation("ScrimPanel", "Panel")
	theme.set_stylebox("panel", "ScrimPanel", scrim)


static func _build_sliders(theme: Theme) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Design.alpha(Design.ACCENT, 0.18)
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	theme.set_stylebox("slider", "HSlider", track)

	var filled := StyleBoxFlat.new()
	filled.bg_color = Design.alpha(Design.ACCENT, 0.55)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)


static func _build_containers(theme: Theme) -> void:
	theme.set_constant("separation", "VBoxContainer", Design.SPACE_MD)
	theme.set_constant("separation", "HBoxContainer", Design.SPACE_MD)
	theme.set_constant("h_separation", "GridContainer", Design.SPACE_MD)
	theme.set_constant("v_separation", "GridContainer", Design.SPACE_MD)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		theme.set_constant(side, "MarginContainer", Design.SPACE_LG)
