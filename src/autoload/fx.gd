extends Node

var _glow_tex: GradientTexture2D
var _add_mat: CanvasItemMaterial
var _flash_layer: CanvasLayer
var _flash_rect: ColorRect
var _hitstop_token := 0
var mono_font: Font
var quality_scale := 1.0
var _spark_pool: Array[CPUParticles2D] = []
var _spark_i := 0

const TRACE_TEMPLATES := [
	"segfault at 0xdeadbeef\n #0 purge_one(<%s>)\n #1 hit_loop",
	"BUG: unable to handle kernel paging\n #0 reap_daemon(<%s>)\n #1 swapper/0",
	"%s terminated on signal 11 (core dumped)",
]

func _ready() -> void:
	mono_font = load("res://assets/fonts/ShareTechMono.ttf")
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	process_mode = Node.PROCESS_MODE_ALWAYS

func glow_tex() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.3, Color(1, 1, 1, 0.55))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.width = 128
		_glow_tex.height = 128
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(0.5, 0.0)
	return _glow_tex

func add_material() -> CanvasItemMaterial:
	return _add_mat

func make_glow(radius: float, color: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = glow_tex()
	s.material = _add_mat
	s.modulate = Color(color.r, color.g, color.b, 0.0)
	s.scale = Vector2.ONE * (radius * 4.4 / 128.0)
	return s

func ring(pos: Vector2, color: Color, r0: float, r1: float, dur: float, width: float = 3.0, dashed := false) -> void:
	var n := RingFx.new()
	n.setup(color, r0, r1, dur, width, dashed)
	n.position = pos
	_attach(n)

func sparks(pos: Vector2, color: Color, amount: int, speed: float = 220.0, life: float = 0.5, size: float = 3.0) -> void:
	var n := maxi(1, int(amount * quality_scale))
	var p: CPUParticles2D
	if _spark_pool.size() < 14:
		p = CPUParticles2D.new()
		p.one_shot = true
		p.emitting = false
		p.material = _add_mat
		_attach(p)
		_spark_pool.append(p)
	p = _spark_pool[_spark_i]
	if not is_instance_valid(p):
		p = CPUParticles2D.new()
		p.one_shot = true
		p.emitting = false
		p.material = _add_mat
		_attach(p)
		_spark_pool[_spark_i] = p
	_spark_i = (_spark_i + 1) % 14
	p.position = pos
	p.amount = n
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 2.2
	p.damping_max = speed * 3.2
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.scale_amount_curve = _fall_curve()
	p.color = color
	p.restart()
	p.emitting = true

func _fall_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c

func shards(pos: Vector2, color: Color, n: int = 7, speed: float = 320.0) -> void:
	for i in n:
		var s := ShardFx.new()
		s.setup(color, randf_range(3.0, 7.0), randf_range(speed * 0.4, speed))
		s.position = pos + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		s.rotation = randf() * TAU
		_attach(s)

func burst(pos: Vector2, color: Color, scale: float = 1.0, shards_n: int = 7) -> void:
	ring(pos, color, 4.0, 46.0 * scale, 0.32, 3.0 * scale)
	ring(pos, Color(1, 1, 1, 0.9), 2.0, 22.0 * scale, 0.2, 2.0 * scale)
	sparks(pos, color, int(14 * scale), 300.0 * scale, 0.5, 3.0 * scale)
	sparks(pos, Color(1, 1, 1, 0.8), int(6 * scale), 200.0 * scale, 0.3, 2.0 * scale)
	shards(pos, color, shards_n, 340.0 * scale)
	shake(0.25 * scale)

func text(pos: Vector2, s: String, color: Color, size: int = 15) -> void:
	var t := FloatText.new()
	t.setup(s, color, size, mono_font)
	t.position = pos + Vector2(randf_range(-8, 8), -14)
	_attach(t)

func stacktrace(pos: Vector2, killer: String, big := false) -> void:
	var t := FloatText.new()
	var col := Balance.COL_DANGER if big else Balance.COL_MOTE
	t.setup(TRACE_TEMPLATES[randi() % TRACE_TEMPLATES.size()] % killer, col, 14 if big else 12, mono_font)
	t.dur = 1.1
	t.multiline = true
	t.position = pos + Vector2(randf_range(-8, 8), 26.0)
	_attach(t)

func ghost(pos: Vector2, rot: float, draw_fn: Callable, color: Color, life: float = 0.28, node_scale: float = 1.0) -> void:
	var g := GhostFx.new()
	g.setup(draw_fn, color, life)
	g.position = pos
	g.rotation = rot
	g.scale = Vector2.ONE * node_scale
	_attach(g)

func flash(color: Color, alpha: float, dur: float) -> void:
	if _flash_layer == null:
		_flash_layer = CanvasLayer.new()
		_flash_layer.layer = 90
		_flash_rect = ColorRect.new()
		_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash_rect.modulate.a = 0.0
		_flash_layer.add_child(_flash_rect)
		var root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		root.add_child(_flash_layer)
	_flash_rect.color = Color(color.r, color.g, color.b, alpha)
	var tw := create_tween()
	tw.tween_property(_flash_rect, "modulate:a", 0.0, dur).set_ease(Tween.EASE_OUT)

func shake(amount: float) -> void:
	get_tree().call_group("cam_rig", "add_trauma", amount)

func zoom_punch(amount: float) -> void:
	get_tree().call_group("cam_rig", "zoom_punch", amount)

func hitstop(ms: float, scale: float = 0.05) -> void:
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = scale
	var t := get_tree().create_timer(ms / 1000.0, true, false, true)
	t.timeout.connect(func() -> void:
		if token == _hitstop_token:
			Engine.time_scale = 1.0
	)

func slowmo(scale: float, dur: float) -> void:
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = scale
	var t := get_tree().create_timer(dur, true, false, true)
	t.timeout.connect(func() -> void:
		if token == _hitstop_token:
			Engine.time_scale = 1.0
	)

func ghost_dot(pos: Vector2, radius: float, color: Color, life: float = 0.25) -> void:
	var g := DotGhost.new()
	g.setup(radius, color, life)
	g.position = pos
	_attach(g)

func _attach(n: Node) -> void:
	var sc := get_tree().current_scene
	if sc != null:
		sc.add_child(n)
	else:
		get_tree().root.add_child(n)

class RingFx extends Node2D:
	var col: Color
	var r0: float
	var r1: float
	var dur: float
	var w: float
	var dashed: bool
	var t := 0.0

	func setup(c: Color, a: float, b: float, d: float, width: float, dash: bool) -> void:
		col = c
		r0 = a
		r1 = b
		dur = d
		w = width
		dashed = dash
		z_index = 20

	func _process(delta: float) -> void:
		t += delta
		if t >= dur:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / dur
		var e := 1.0 - pow(1.0 - k, 3.0)
		var r := lerpf(r0, r1, e)
		var c := col
		c.a = col.a * (1.0 - k)
		if dashed:
			var segs := 24
			for i in segs:
				var a0 := float(i) / segs * TAU
				draw_arc(Vector2.ZERO, r, a0, a0 + TAU / segs * 0.55, 6, c, w, true)
		else:
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, c, w, true)

class ShardFx extends Node2D:
	var col: Color
	var size: float
	var vel: Vector2
	var t := 0.0
	var dur: float

	func setup(c: Color, s: float, sp: float) -> void:
		col = c
		size = s
		vel = Vector2.from_angle(randf() * TAU) * sp
		dur = randf_range(0.35, 0.6)
		z_index = 19

	func _process(delta: float) -> void:
		t += delta
		if t >= dur:
			queue_free()
			return
		position += vel * delta
		vel = vel.move_toward(Vector2.ZERO, 900.0 * delta)
		rotation += 9.0 * delta
		queue_redraw()

	func _draw() -> void:
		var c := col
		c.a = clampf(1.0 - t / dur, 0.0, 1.0)
		var pts := PackedVector2Array([
			Vector2(-size, -size * 0.4), Vector2(size, -size), Vector2(size * 0.6, size * 0.5), Vector2(-size * 0.5, size * 0.8)
		])
		draw_colored_polygon(pts, c)

class FloatText extends Node2D:
	var label := ""
	var col: Color
	var fsize: int
	var font: Font
	var t := 0.0
	var dur := 0.75
	var multiline := false

	func setup(s: String, c: Color, sz: int, f: Font) -> void:
		label = s
		col = c
		fsize = sz
		font = f
		z_index = 40

	func _process(delta: float) -> void:
		t += delta
		if t >= dur:
			queue_free()
			return
		position.y -= 34.0 * delta
		queue_redraw()

	func _draw() -> void:
		var k := t / dur
		var c := col
		c.a = clampf(1.6 - k * 1.6, 0.0, 1.0)
		var pop := 1.0 + 0.5 * pow(maxf(0.0, 1.0 - k * 4.0), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(pop, pop))
		if multiline:
			draw_multiline_string(font, Vector2(-120, 0), label, HORIZONTAL_ALIGNMENT_CENTER, 240, fsize, 6, c)
		else:
			draw_string(font, Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize, c)

class DotGhost extends Node2D:
	var radius := 6.0
	var col: Color
	var t := 0.0
	var dur := 0.25

	func setup(r: float, c: Color, d: float) -> void:
		radius = r
		col = c
		dur = d
		z_index = 6

	func _process(delta: float) -> void:
		t += delta
		if t >= dur:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var c := col
		c.a = clampf(1.0 - t / dur, 0.0, 1.0) * 0.4
		draw_circle(Vector2.ZERO, radius, c)

class GhostFx extends Node2D:
	var draw_fn: Callable
	var col: Color
	var t := 0.0
	var dur: float

	func setup(fn: Callable, c: Color, d: float) -> void:
		draw_fn = fn
		col = c
		dur = d
		z_index = 5

	func _process(delta: float) -> void:
		t += delta
		if t >= dur:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if not draw_fn.is_valid():
			queue_free()
			return
		var c := col
		c.a = clampf(1.0 - t / dur, 0.0, 1.0) * 0.5
		draw_fn.call(self, c)
