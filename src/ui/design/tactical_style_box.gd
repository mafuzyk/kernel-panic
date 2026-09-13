class_name TacticalStyleBox
extends StyleBox

## O frame táctico do KERNEL PANIC como StyleBox de verdade.
##
## Antes, o visual de painel/botão (polígono de cantos cortados + trilhos +
## pontos de canto) só existia como código `_draw` dentro de `TacticalChrome`,
## um Control separado que precisava ser posicionado atrás de cada widget.
## Isso impedia usá-lo num `Theme` e, por consequência, impedia ter estados:
## hover, pressed, focus e disabled não existiam em lugar nenhum da UI.
##
## Como StyleBox ele vira atribuível por tema — um `Button` ganha os cinco
## estados de graça, e o Godot cuida de trocar entre eles.

## Cor do traço e dos detalhes.
@export var accent: Color = Design.ACCENT
## Preenchimento interno (0 = vazado).
@export var fill_alpha: float = 0.0
## Espessura do contorno.
@export var stroke: float = 1.35
## Tamanho do canto cortado. Limitado a metade do menor lado.
@export var corner_cut: float = 16.0
## Desenha os trilhos horizontais curtos perto das bordas.
@export var rails: bool = true
## Comprimento do trilho. Painéis usam trilho longo, controles usam curto.
@export var rail_length: float = 156.0
## Desenha os quatro pontos de canto.
@export var corner_dots: bool = true
## Anel de foco por fora do frame (acessibilidade de teclado).
@export var focus_ring: bool = false

const _RAIL_INSET := 7.0
const _RAIL_START := 28.0
const _DOT_RADIUS := 2.1

## Margens de conteúdo: a decoração (trilhos e pontos de canto) vive na área
## de padding. Sem isto o Godot dispõe o texto de borda a borda e os trilhos
## passam por cima dele — o que acontecia com o botão primário.
const _PAD_H := 34.0
const _PAD_V := 12.0


func _init() -> void:
	content_margin_left = _PAD_H
	content_margin_right = _PAD_H
	content_margin_top = _PAD_V
	content_margin_bottom = _PAD_V


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var cut: float = minf(corner_cut, minf(rect.size.x, rect.size.y) * 0.5)
	var points := _angular_points(rect, cut)

	if fill_alpha > 0.0:
		RenderingServer.canvas_item_add_polygon(
			to_canvas_item, points,
			PackedColorArray([Design.alpha(accent, fill_alpha)])
		)

	var closed := points.duplicate()
	closed.append(points[0])
	RenderingServer.canvas_item_add_polyline(
		to_canvas_item, closed,
		PackedColorArray([Design.alpha(accent, 0.76)]), stroke, true
	)

	if rails:
		_draw_rails(to_canvas_item, rect)
	if corner_dots:
		_draw_dots(to_canvas_item, rect)
	if focus_ring:
		_draw_focus_ring(to_canvas_item, rect, cut)


func _draw_rails(item: RID, rect: Rect2) -> void:
	var color := Design.alpha(accent, 0.62)
	var reach: float = minf(rail_length, maxf(rect.size.x * 0.5 - _RAIL_START - 8.0, 0.0))
	if reach <= 4.0:
		return
	for y in [rect.position.y + _RAIL_INSET, rect.end.y - _RAIL_INSET]:
		RenderingServer.canvas_item_add_line(item,
			Vector2(rect.position.x + _RAIL_START, y),
			Vector2(rect.position.x + _RAIL_START + reach, y), color, 1.0, true)
		RenderingServer.canvas_item_add_line(item,
			Vector2(rect.end.x - _RAIL_START - reach, y),
			Vector2(rect.end.x - _RAIL_START, y), color, 1.0, true)


func _draw_dots(item: RID, rect: Rect2) -> void:
	var color := Design.alpha(accent, 0.85)
	var inset_y: float = minf(15.0, rect.size.y * 0.32)
	var inset_x: float = minf(29.0, rect.size.x * 0.32)
	for p in [
		Vector2(rect.position.x + inset_x, rect.position.y + inset_y),
		Vector2(rect.end.x - inset_x, rect.position.y + inset_y),
		Vector2(rect.position.x + inset_x, rect.end.y - inset_y),
		Vector2(rect.end.x - inset_x, rect.end.y - inset_y),
	]:
		RenderingServer.canvas_item_add_circle(item, p, _DOT_RADIUS, color, true)


func _draw_focus_ring(item: RID, rect: Rect2, cut: float) -> void:
	var grown := rect.grow(Design.SPACE_XS)
	var ring := _angular_points(grown, cut + Design.SPACE_XS)
	var closed := ring.duplicate()
	closed.append(ring[0])
	RenderingServer.canvas_item_add_polyline(
		item, closed,
		PackedColorArray([Design.FOCUS_RING_COLOR]),
		Design.FOCUS_RING_WIDTH, true
	)


## Polígono de cantos cortados. Mesma geometria de `TacticalUI.angular_points`,
## reimplementada aqui para o StyleBox não depender de um Control.
static func _angular_points(rect: Rect2, cut: float) -> PackedVector2Array:
	var c: float = clampf(cut, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	return PackedVector2Array([
		rect.position + Vector2(c, 0.0),
		Vector2(rect.end.x - c, rect.position.y),
		Vector2(rect.end.x, rect.position.y + c),
		Vector2(rect.end.x, rect.end.y - c),
		Vector2(rect.end.x - c, rect.end.y),
		Vector2(rect.position.x + c, rect.end.y),
		Vector2(rect.position.x, rect.end.y - c),
		Vector2(rect.position.x, rect.position.y + c),
	])


## Cria a variante de um estado a partir desta. Usado pelo construtor de tema
## para derivar hover/pressed/disabled sem repetir configuração.
func variant(accent_color: Color, fill: float, with_focus_ring: bool = false) -> TacticalStyleBox:
	var out := TacticalStyleBox.new()
	out.accent = accent_color
	out.fill_alpha = fill
	out.stroke = stroke
	out.corner_cut = corner_cut
	out.rails = rails
	out.rail_length = rail_length
	out.corner_dots = corner_dots
	out.focus_ring = with_focus_ring
	out.content_margin_left = content_margin_left
	out.content_margin_right = content_margin_right
	out.content_margin_top = content_margin_top
	out.content_margin_bottom = content_margin_bottom
	return out
