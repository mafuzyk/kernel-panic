extends RefCounted

## Autotest section script. Function bodies below are moved verbatim from
## src/autoload/dev_harness.gd; only harness-helper references are prefixed
## with `h` per plan section G3. No behavior changes. AT_STEP labels and
## message strings are byte-identical to the originals.

var h: Node


func _init(harness: Node) -> void:
	h = harness

## Probe que executa desenho de teste dentro de `_draw`, o único contexto
## onde CanvasItem permite draw_*. Usada pelos testes de regression visual.
class GlyphDrawProbe extends Control:
	var draw_fn: Callable
	func _draw() -> void:
		if draw_fn.is_valid():
			draw_fn.call(self)

func _hud_style_test(arena: Arena) -> void:
	print("AT_STEP hud_style")
	var tui_script: Script = load("res://src/ui/tactical_ui.gd")
	var tui = tui_script.new() if tui_script != null else null
	h._check(tui != null and tui.has_method("panel_fill_color"), "tactical ui exposes panel_fill_color")
	if tui == null or not tui.has_method("panel_fill_color"):
		return
	var combat_fill: Color = tui.call("panel_fill_color", true)
	var menu_fill: Color = tui.call("panel_fill_color", false)
	h._check(combat_fill.a <= 0.08, "combat panel fill stays faint (alpha <= 0.08)")
	h._check(combat_fill.a >= 0.04, "combat panel fill keeps a visible tint (alpha >= 0.04)")
	h._check(menu_fill.is_equal_approx(TacticalUI.PANEL), "non-combat surfaces keep the opaque PANEL fill")
	var hud_ref: Hud = arena.hud
	h._check(hud_ref != null and hud_ref.has_method("primary_surface_points") and hud_ref.has_method("primary_surface_fill"),
		"combat HUD exposes live primary-surface geometry and fill")
	if hud_ref != null and hud_ref.has_method("primary_surface_points") and hud_ref.has_method("primary_surface_fill"):
		var probe := Rect2(24.0, 32.0, 220.0, 96.0)
		var points: PackedVector2Array = hud_ref.call("primary_surface_points", probe)
		var fill: Color = hud_ref.call("primary_surface_fill")
		h._check(points.size() == 4 and points[0] == probe.position and points[2] == probe.end,
			"primary combat modules use rectangular editorial geometry instead of cut corners")
		# Regra revista em 2026-09-16, terceira versão.
		#
		# v1 era "fundo fraco (alpha <= 0.08) para o campo continuar visível
		# através do módulo" — escrita para um fundo parado, e o fundo não está
		# parado: a câmera segue o jogador, então parede, réguas e setores
		# corrompidos passam por baixo de cada módulo o tempo todo.
		#
		# v2 respondeu tapando tudo (alpha 0.92, cor fixa). Resolveu a régua e
		# criou dois problemas: o chão ficava azul marinho em TODA fase, e os
		# inimigos que cruzavam um módulo sumiam da tela.
		#
		# v3: o chão tinge com o campo, fica translúcido, e quem passa por baixo
		# é redesenhado como silhueta entre o chão e o texto.
		h._check(fill.a >= 0.65, "combat modules carry a real ground, not a tint")
		h._check(fill.a <= 0.85, "that ground stays translucent enough to show what crosses it")
		h._check(fill.get_luminance() < 0.08, "that ground stays dark enough for the status ink")
		h._check(hud_ref.has_method("surface_fill_for_accent") and hud_ref.has_method("module_cover_depth"),
			"combat HUD exposes the ground tint and the cover math as pure functions")
		# O chão segue o acento vivo: mesma família de matiz, luminância travada.
		for probe_accent in [Balance.COL_PLAYER, Balance.COL_LANCER, Balance.COL_MOTE, Balance.COL_SPEWER]:
			var accent: Color = probe_accent
			var ground: Color = hud_ref.call("surface_fill_for_accent", accent)
			h._check(ground.get_luminance() < 0.08,
				"the %s ground stays dark enough for the status ink" % accent.to_html(false))
			h._check(absf(fposmod(ground.h - accent.h + 0.5, 1.0) - 0.5) < 0.06,
				"the %s ground keeps the hue of the field it sits on" % accent.to_html(false))
		var stale: Color = hud_ref.call("surface_fill_for_accent", Balance.COL_MOTE)
		h._check(not stale.is_equal_approx(hud_ref.call("surface_fill_for_accent", Balance.COL_SPEWER)),
			"two different field accents do not produce the same ground")
		# A silhueta entra pela profundidade, não por um teste de dentro/fora.
		var probe_rect := Rect2(0.0, 0.0, 100.0, 40.0)
		h._check(float(hud_ref.call("module_cover_depth", probe_rect, Vector2(50.0, 20.0))) == 20.0,
			"cover depth peaks at the centre of a module")
		h._check(float(hud_ref.call("module_cover_depth", probe_rect, Vector2(-10.0, 20.0))) == -10.0,
			"cover depth goes negative outside the module")
	h._check(hud_ref != null and hud_ref.has_method("outer_frame_segments"), "combat HUD exposes outer-frame geometry")
	if hud_ref != null and hud_ref.has_method("outer_frame_segments"):
		h._check(hud_ref.call("outer_frame_segments", Vector2(1366, 768)).is_empty(), "combat HUD no longer encloses the arena in a decorative outer frame")
	# A parede da arena desenhava marcas de canto em L de 26px por 3px de
	# espessura. Elas são decoração — a polilinha do retângulo já mostra o
	# limite — e, como a câmera se move, caem sobre o texto do HUD. No capture
	# de 2026-09-12 uma delas atravessa "DASH READY" e outra atravessa o placar.
	h._check(ArenaWalls.CORNER_MARK_LENGTH == 0.0,
		"arena walls stop drawing decorative corner marks over the HUD")

	# Uma tinta só para rótulo de módulo. `SCORE` e `EVENT LOG` usavam o acento
	# de era (âmbar no endless) enquanto `INTEGRITY` e os valores eram ciano —
	# duas paletas dentro do mesmo bloco. O acento de era pertence ao CAMPO, que
	# é o que ele identifica; rótulo de HUD é tipografia de status.
	h._check(hud_ref != null and hud_ref.has_method("status_label_ink"),
		"combat HUD owns one ink for module labels")
	if hud_ref != null and hud_ref.has_method("status_label_ink"):
		var label_ink: Color = hud_ref.call("status_label_ink")
		h._check(label_ink == Design.TEXT_MUTED, "module labels use the shared muted ink")
		h._check(not label_ink.is_equal_approx(hud_ref.get("_era_accent")),
			"module labels do not borrow the era accent")

	# Rótulo SEMPRE acima do medidor que ele nomeia. `INTEGRITY` ficava acima dos
	# pips e `OVERCLOCK` abaixo da barra, no mesmo módulo.
	h._check(hud_ref != null and hud_ref.has_method("meter_label_baselines"),
		"combat HUD exposes where its meter labels sit")
	if hud_ref != null and hud_ref.has_method("meter_label_baselines"):
		var baselines: Dictionary = hud_ref.call("meter_label_baselines")
		for key in ["integrity", "overclock"]:
			var pair: Dictionary = baselines.get(key, {})
			h._check(float(pair.get("label", 1.0)) < float(pair.get("meter", 0.0)),
				"%s label sits above its meter" % key)

	# A insígnia de canto cortado em volta dos chevrons do dash era o último
	# sobrevivente da linguagem antiga dentro do HUD. Os três chevrons já dizem
	# "dash"; a caixa em volta era moldura por elemento.
	h._check(TacticalIcon.DASH_BADGE_ENABLED == false,
		"the dash glyph drops its cut-corner badge")
	h._check(hud_ref != null and hud_ref.get("_score_font") == Design.grotesk(Design.WEIGHT_BLACK),
		"combat HUD display hierarchy uses the shared grotesk instead of Orbitron")

func _era_accent_test(arena: Arena) -> void:
	print("AT_STEP era_accent")
	var hud_ref = arena.hud
	h._check(hud_ref != null and hud_ref.has_method("set_era_accent") and hud_ref.has_method("era_accent"), "hud exposes era accent controls")
	if hud_ref == null or not hud_ref.has_method("set_era_accent"):
		return
	var hud_script: Script = load("res://src/ui/hud.gd")
	var fresh_hud = hud_script.new() if hud_script != null else null
	h._check(fresh_hud != null and fresh_hud.call("era_accent") == TacticalUI.CYAN, "hud era accent defaults to cyan")
	if fresh_hud != null:
		fresh_hud.free()
	var seed_before := Game.rng.seed
	hud_ref.call("set_era_accent", Balance.era_color(8))
	h._check(hud_ref.call("era_accent") == Balance.era_color(8), "set_era_accent updates the hud accent")
	h._check(Game.rng.seed == seed_before, "era accent changes never advance the gameplay rng")
	arena.call("_on_wave_started", 8, false)
	h._check(arena.hud.call("era_accent") == Balance.era_color(8), "arena pushes the per-wave era accent to the hud")
	arena.set("_temple_mode", true)
	var accent_a: Color = arena.hud.call("era_accent")
	await h._ticks(4)
	var accent_b: Color = arena.hud.call("era_accent")
	arena.set("_temple_mode", false)
	h._check(accent_a != accent_b, "rainbow mode cycles the hud accent over time")
	hud_ref.call("set_era_accent", TacticalUI.CYAN)

func _story_test(arena: Arena) -> void:
	print("AT_STEP story")
	var story_script: Script = load("res://src/story/story_data.gd")
	h._check(story_script != null, "story stage data script loads")
	h._check(Game.has_method("story_stage_count") and Game.has_method("story_stage_def"), "game exposes story stage data")
	h._check(Game.has_method("story_stage_unlocked"), "game exposes story unlock progression")
	h._check(arena.spawner.has_method("start_story"), "spawner exposes fixed story queue")
	if story_script == null or not Game.has_method("story_stage_count") or not Game.has_method("story_stage_def") or not arena.spawner.has_method("start_story"):
		return
	var count := int(Game.story_stage_count())
	# Contagem por ATO, não por total: um ato novo não deve reprovar um teste
	# que só queria saber se os atos antigos continuam inteiros.
	h._check(Game.STORY_DATA.act_stage_count("unix") == 6
		and Game.STORY_DATA.act_stage_count("windows") == 3
		and Game.STORY_DATA.act_stage_count("macos") == 4
		and Game.STORY_DATA.act_stage_count("templeos") == 2,
		"Story contains UNIX, Windows, macOS and TempleOS stages")
	h._check(count == 15, "Story has every act's stages on the chain (%d)" % count)
	h._check(Game.STORY_DATA.act_ids() == ["unix", "windows", "macos", "templeos"],
		"the acts run in narrative order with the bonus act last")
	var expected_ids := ["boot", "var_log", "net", "mem", "quarantine", "kernel"]
	var expected_paths := ["/boot", "/var/log", "/net", "/mem", "/quarantine", "/kernel"]
	for i in mini(count, expected_ids.size()):
		var stage: Dictionary = Game.story_stage_def(i)
		h._check(str(stage.get("id", "")) == expected_ids[i] and str(stage.get("path", "")) == expected_paths[i], "story stage %d has the expected UNIX path" % (i + 1))
	h._check(Game.story_stage_def(0).get("waves", []).size() > 0, "story stages declare fixed waves")
	h._check("boss" in Game.story_stage_def(5), "kernel stage declares its boss")
	var saved_mode := Game.mode
	var saved_state := Game.state
	var saved_stage := int(Game.get("story_stage_index")) if Game.get("story_stage_index") != null else 0
	var saved_cleared: Dictionary = Game.story_cleared.duplicate(true) if Game.get("story_cleared") is Dictionary else {}
	Game.story_cleared = {}
	h._check(bool(Game.story_stage_unlocked(0)), "first story stage is unlocked")
	h._check(not bool(Game.story_stage_unlocked(1)), "next story stage stays locked")
	Game.story_cleared["boot"] = true
	h._check(bool(Game.story_stage_unlocked(1)) and not bool(Game.story_stage_unlocked(2)), "clearing one stage unlocks only the next stage")
	Game.mode = "story"
	Game.state = Game.State.PLAYING
	var sp: Spawner = arena.spawner
	sp.stop()
	sp.debug_clear_encounter()
	for child in arena.enemy_container.get_children():
		child.queue_free()
	await h._ticks(2)
	var boot_stage: Dictionary = Game.story_stage_def(0)
	sp.start_story(arena, arena.enemy_container, boot_stage)
	h._check(bool(sp.get("story_mode")), "story spawner enters scripted mode")
	var fixed_queue: Array = sp.get("_queue")
	h._check(not fixed_queue.is_empty(), "story spawner loads a fixed queue")
	var fixed_only := true
	for kind in fixed_queue:
		if str(kind) != "drone":
			fixed_only = false
	h._check(fixed_only, "boot queue contains only its declared enemy type")
	sp.stop()
	sp.debug_clear_encounter()
	Game.mode = saved_mode
	Game.state = saved_state
	Game.story_stage_index = saved_stage
	Game.story_cleared = saved_cleared
	sp.start(arena, arena.enemy_container, 1)
	await h._ticks(3)

func _windows_test(arena: Arena) -> void:
	print("AT_STEP windows")
	var update_script: Script = load("res://src/enemies/update_loop.gd")
	var bloat_script: Script = load("res://src/enemies/bloatware.gd")
	var popup_script: Script = load("res://src/enemies/popup_orb.gd")
	var crt_script: Script = load("res://src/arena/crt_overlay.gd")
	h._check(update_script != null and bloat_script != null and popup_script != null, "Windows enemy scripts load")
	h._check(crt_script != null, "CRT overlay script loads")
	h._check(Game.STORY_DATA.act_stage_count("windows") == 3, "Story includes three Windows stages")
	var paths := ["C:\\98", "C:\\XP", "Win11"]
	for i in paths.size():
		var stage: Dictionary = Game.story_stage_def(6 + i)
		h._check(str(stage.get("path", "")) == paths[i], "Windows stage %d has the expected path" % (i + 1))
	h._check(str(Game.story_stage_def(6).get("theme", {}).get("grid_style", "")) == "crt_heavy", "C98 selects the heavy CRT profile")
	h._check(str(Game.story_stage_def(7).get("theme", {}).get("grid_style", "")) == "crt_soft", "CXP selects the soft CRT profile")
	h._check(str(Game.story_stage_def(8).get("theme", {}).get("grid_style", "")) == "clean", "Win11 disables the CRT profile")
	var sp: Spawner = arena.spawner
	var update_enemy = sp.call("_make_enemy", "update_loop")
	var bloat_enemy = sp.call("_make_enemy", "bloatware")
	h._check(update_enemy is UpdateLoopEnemy and bloat_enemy is BloatwareEnemy, "spawner creates the Windows enemy cast")
	if update_enemy != null:
		h._check(update_enemy.has_method("reinstall_duration"), "UPDATE_LOOP exposes reinstall behavior")
	if bloat_enemy != null:
		h._check(bloat_enemy.has_method("popup_count_on_death"), "BLOATWARE exposes popup drop behavior")
	if update_enemy is Node:
		update_enemy.free()
	if bloat_enemy is Node:
		bloat_enemy.free()
	h._check(arena.has_method("windows_stage_profile"), "arena exposes Windows stage profile")

## Onde a fase com este id está na corrente. -1 quando ela não existe.
func _stage_index_of(stage_id: String) -> int:
	for index in Game.story_stage_count():
		if Game.story_stage_id(index) == stage_id:
			return index
	return -1


func _temple_test(arena: Arena) -> void:
	print("AT_STEP temple")
	var god_script: Script = load("res://src/enemies/god_boss.gd")
	h._check(god_script != null, "GOD boss script loads")
	h._check(Game.STORY_DATA.act_stage_count("templeos") == 2, "Story includes two TempleOS stages")
	h._check(Game.STORY_DATA.act_stage_count("templeos") == 2, "TempleOS act exposes two stages")
	# Localizadas pelo ID, não pelo índice: inserir um ato antes do bônus
	# reprovava sete asserções que não tinham nada a ver com a mudança.
	var temple_index := _stage_index_of("temple_boot")
	var god_index := _stage_index_of("temple_god")
	var paths := ["TempleOS::BOOT", "TempleOS::GOD"]
	for i in paths.size():
		var stage: Dictionary = Game.story_stage_def(temple_index + i)
		h._check(str(stage.get("path", "")) == paths[i], "TempleOS stage %d has the expected path" % (i + 1))
	var temple_stage := Game.story_stage_def(temple_index)
	var god_stage := Game.story_stage_def(god_index)
	h._check(str(temple_stage.get("theme", {}).get("grid_style", "")) == "holy", "TempleOS uses the holy CRT profile")
	Sfx.set_music_variant("holy")
	h._check(Sfx.music_variant == "holy", "templeos holy music variant is recognized")
	Sfx.set_music_variant("normal")
	h._check(Sfx.music_variant == "normal", "music variant returns to normal")
	h._check(temple_stage.get("arena_size", Vector2.ZERO) == Vector2(640.0, 640.0), "TempleOS shrinks the arena to 640x640")
	h._check(str(god_stage.get("boss_kind", "")) == "god", "TempleOS final stage declares the GOD boss")
	var sp: Spawner = arena.spawner
	var god_enemy = sp.call("_make_enemy", "god")
	h._check(god_enemy is GodBoss, "spawner creates the GOD boss")
	if god_enemy is GodBoss:
		h._check(god_enemy.has_method("roll_oracle_attack"), "GOD exposes oracle attack selection")
		var old_seed := Game.rng.seed
		Game.rng.seed = 90210
		var oracle_a := str(god_enemy.call("roll_oracle_attack"))
		Game.rng.seed = 90210
		var oracle_b := str(god_enemy.call("roll_oracle_attack"))
		Game.rng.seed = old_seed
		h._check(oracle_a == oracle_b and not oracle_a.is_empty(), "GOD oracle attacks follow the gameplay RNG")
		h._check(god_enemy.has_method("oracle_interval_for_phase"), "GOD exposes a pure phase cadence contract")
		if god_enemy.has_method("oracle_interval_for_phase"):
			var p1 := float(god_enemy.call("oracle_interval_for_phase", 1))
			var p2 := float(god_enemy.call("oracle_interval_for_phase", 2))
			var p3 := float(god_enemy.call("oracle_interval_for_phase", 3))
			h._check(p1 > p2 and p2 > p3, "GOD pressure rises monotonically P1 > P2 > P3")
			h._check(p1 <= 2.5 and p3 >= 1.0, "GOD cadence stays in the readable band")
	if god_enemy is Node:
		god_enemy.free()
	h._check(arena.has_method("temple_stage_profile"), "arena exposes TempleOS stage profile")
	var old_size := Balance.arena_rect().size
	Balance.set_arena_size_override(Vector2(640.0, 640.0))
	h._check(Balance.arena_rect().size == Vector2(640.0, 640.0), "arena override changes only the active combat rectangle")
	Balance.clear_arena_size_override()
	h._check(Balance.arena_rect().size == old_size, "arena override restores the default rectangle")

func _glyph_lib_test() -> void:
	print("AT_STEP glyph_lib")
	var glyph_script: Script = load("res://src/ui/glyph_lib.gd")
	var glyph = glyph_script.new() if glyph_script != null else null
	h._check(glyph != null and glyph.has_method("draw_glyph") and glyph.has_method("glyph_kinds") and glyph.has_method("era_mix"), "glyph library exposes draw_glyph, glyph_kinds, and era_mix")
	if glyph == null or not glyph.has_method("draw_glyph"):
		return
	var required := ["drone", "lancer", "spewer", "splitter", "bulwark", "trojan", "oom", "recursor", "firewall", "bloatware", "update_loop", "page", "root", "boss", "segfault", "bluescreen", "pagefault", "god", "kernel", "daemon", "rootlet"]
	var kinds: Array = glyph.call("glyph_kinds")
	var missing := false
	for kind in required:
		if not kinds.has(kind):
			missing = true
	h._check(not missing, "glyph library covers every enemy and program kind")
	var seed_before := Game.rng.seed
	for kind in required:
		glyph.call("draw_glyph", null, kind, Vector2.ZERO, 4.0, Color.CYAN, 0.0)
		glyph.call("draw_glyph", null, kind, Vector2.ZERO, 64.0, Color.CYAN, 1.0)
	h._check(Game.rng.seed == seed_before, "glyph drawing never advances the gameplay rng")
	var mixed: Color = glyph.call("era_mix", Color.RED, Color.CYAN, 0.25)
	h._check(not mixed.is_equal_approx(Color.RED) and not mixed.is_equal_approx(Color.CYAN), "era_mix blends identity colors toward the era accent")
	# Comportamento, não texto-fonte. A versão anterior afirmava que os painéis
	# continham a string literal "GlyphLib.draw_glyph" e quebrou ao renomear o
	# ponto de entrada para draw_portrait — sem regressão nenhuma. O que o
	# teste quer garantir é que os painéis reusam a biblioteca em vez de
	# reimplementar desenho, e que os dois pontos de entrada funcionam.
	# Era texto-fonte: procurava "GlyphLib.draw_" nos dois arquivos. Quebrou
	# assim que o desenho saiu do painel para um construtor compartilhado
	# (`ScreenKit.glyph`), sem nenhuma regressão. O contrato real é que cada
	# silhueta que a tela mostra seja um tipo que a biblioteca sabe desenhar.
	for panel_path in ["res://src/ui/bestiary_panel.gd", "res://src/ui/program_panel.gd"]:
		var kinds_probe = load(panel_path).new()
		var shown: Array = kinds_probe.call("glyph_kinds") if kinds_probe.has_method("glyph_kinds") else []
		h._check(not shown.is_empty(), "%s lists the silhouettes it shows" % panel_path.get_file())
		var kinds_seed: int = Game.rng.seed
		for kind in shown:
			glyph.call("draw_glyph", null, str(kind), Vector2.ZERO, 16.0, Color.CYAN, 0.0)
			glyph.call("draw_portrait", null, str(kind), Vector2.ZERO, 48.0, Color.CYAN, 0.0)
		h._check(Game.rng.seed == kinds_seed,
			"%s silhouettes draw without touching the gameplay rng" % panel_path.get_file())
		kinds_probe.free()
	var portrait_seed := Game.rng.seed
	var portrait_ok := true
	for kind in required:
		if not glyph.has_method("draw_portrait"):
			portrait_ok = false
			break
		glyph.call("draw_portrait", null, kind, Vector2.ZERO, 48.0, Color.CYAN, 0.0)
	h._check(portrait_ok, "glyph library exposes the large-portrait entry point")
	h._check(Game.rng.seed == portrait_seed, "portrait drawing never advances the gameplay rng")
	# A arena precisa ficar no caminho desenhado em código: é o que preserva a
	# animação das 10 entidades que usam `t` e a nitidez no tamanho real.
	# Decisão da autora 2026-09-11, ver specs/2026-09-11-brief-sprites.md.
	# split()[1] travaria sem fonte: só avalia com source disponível.
	if h._source_available:
		var glyph_source := str(load("res://src/ui/glyph_lib.gd").source_code)
		var draw_glyph_body := glyph_source.split("static func draw_glyph")[1].split("static func ")[0]
		h._check(not draw_glyph_body.contains("EntitySprite.draw_entity"),
			"arena glyph path stays code-drawn (sprites only via draw_portrait)")
	else:
		print("AT_SKIP source-only check needs script text: arena glyph path stays code-drawn")

## B4/B7/B8 — três achados da auditoria de 2026-09-11.
func _audit_fixes_test() -> void:
	print("AT_STEP audit_fixes")

	# B7: "SWIPE TO SCROLL" era string fixa em story/bestiary/program e vazava
	# no build de desktop, onde não existe swipe.
	h._check(Design.scroll_hint(true) != Design.scroll_hint(false),
		"scroll hint differs between touch and pointer input")
	h._check(not Design.scroll_hint(false).contains("SWIPE"),
		"desktop scroll hint does not mention swiping")
	# Comportamento: cada painel expõe a dica, e ela acompanha o dispositivo.
	for panel_path in ["res://src/ui/bestiary_panel.gd", "res://src/ui/story_panel.gd", "res://src/ui/program_panel.gd"]:
		var panel_script: Script = load(panel_path)
		var probe = panel_script.new()
		var has_hint: bool = probe.has_method("scroll_hint_text")
		h._check(has_hint, "%s exposes its scroll hint" % panel_path.get_file())
		if has_hint:
			h._check(str(probe.call("scroll_hint_text")) == Design.scroll_hint(Design.touch_input()),
				"%s routes its scroll hint through the design system" % panel_path.get_file())
		probe.free()

	# O bestiário existe para reconhecimento: se ele desenha uma forma e a arena
	# desenha outra, ele ensina errado. O redesenho de silhuetas deixou 19 dos
	# 20 sprites raster defasados, então o caminho de retrato tem de cair no
	# mesmo desenho em código que a arena usa.
	h._check(not GlyphLib.USE_RASTER_PORTRAITS,
		"portrait path draws the same silhouettes as the arena")

	# B8: o bestiário abria com "root" selecionado — última entrada da lista,
	# fora da área visível. O painel de detalhe mostrava uma entrada que a lista
	# não destacava em lugar nenhum.
	var bestiary_script: Script = load("res://src/ui/bestiary_panel.gd")
	var bestiary = bestiary_script.new()
	var first_id := str(BestiaryPanel.ENTRIES[0]["id"])
	h._check(str(bestiary.get("_selected_id")) == first_id,
		"bestiary opens on the first listed entry, not one scrolled out of view")
	bestiary.free()


## i18n — decisão da autora 2026-09-11: extrair strings conforme as telas são
## reconstruídas, com PT-BR e EN, em vez de varrer a UI inteira duas vezes.
func _i18n_test() -> void:
	print("AT_STEP i18n")
	var sample := ["PAUSE_TITLE", "OVER_TITLE", "STAT_ACCURACY", "AWARDS_HEADER"]
	# Sweep limitado da 3.0: chrome player-facing não pode voltar a literal.
	var sweep := ["PATCH_RARITY_STANDARD", "PATCH_RARITY_RARE", "PATCH_RARITY_LEGENDARY", "PATCH_LEVEL_UP", "PATCH_NEW", "PATCH_SELECT_ONE", "SUMMARY_BEST", "SUMMARY_SEED", "BUILD_NO_PATCHES", "SET_TRANSFER_HEAD", "SET_BOUND_TO", "SET_LANGUAGE", "SET_LANG_ENGLISH", "SET_LANG_PORTUGUESE", "TERMINAL_TYPE_HELP", "TERM_LINK", "TERM_STATE_STABLE", "TERM_STATE_FROZEN", "TERM_STATE_STANDBY", "TERM_CMD_INDEX", "TERM_DESC_HELP", "TERM_DESC_TOP", "TERM_DESC_DMESG", "TERM_DESC_MAN", "TERM_DESC_SUDO", "TERM_DESC_RM", "TERM_SYSSTATUS", "TERM_CLOSE", "TERM_RUN", "TERM_RUN_SHORT", "TERM_PLACEHOLDER", "TERM_SHORTCUTS", "TERM_READY", "TERM_HINT", "TERM_PAUSED", "TERM_INPUT", "TERM_READY_STATE", "TERM_PROMPT", "TERM_ACTIVE", "TERM_COMMANDS", "TERM_CYCLE", "TERM_MAN_BUGS", "TERM_MAN_THREAT"]
	var previous := TranslationServer.get_locale()

	for locale in ["en", "pt_BR"]:
		TranslationServer.set_locale(locale)
		var all_translated := true
		for key in sample:
			# Chave ausente volta como a própria chave: é o sinal de que a
			# entrada não existe no CSV.
			if tr(key) == key:
				all_translated = false
		h._check(all_translated, "every sampled string resolves in %s" % locale)
		var sweep_ok := true
		for key in sweep:
			if tr(key) == key:
				sweep_ok = false
		h._check(sweep_ok, "bounded 3.0 sweep resolves in %s" % locale)

	TranslationServer.set_locale("en")
	var english := tr("OVER_TITLE")
	TranslationServer.set_locale("pt_BR")
	h._check(tr("OVER_TITLE") != english, "locales actually differ, not just fall back")
	# Runtime do Story segue o idioma: título/intro/klog/ato de todas as fases
	# mais o chrome de onda, sem chave crua em nenhum idioma.
	var story_ok := true
	var titles_en: Array = []
	var titles_pt: Array = []
	for stage_id in StoryData.stage_ids():
		TranslationServer.set_locale("en")
		var title_en := StoryData.localized_title(stage_id)
		var intro_en := StoryData.localized_intro(stage_id)
		var klog_en := StoryData.localized_klog(stage_id, 0)
		TranslationServer.set_locale("pt_BR")
		var title_pt := StoryData.localized_title(stage_id)
		var intro_pt := StoryData.localized_intro(stage_id)
		var klog_pt := StoryData.localized_klog(stage_id, 0)
		titles_en.append(title_en)
		titles_pt.append(title_pt)
		for text in [title_en, intro_en, klog_en, title_pt, intro_pt, klog_pt]:
			if text.is_empty() or str(text).begins_with("STORY_"):
				story_ok = false
	h._check(story_ok, "story title, intro and klog resolve in en and pt_BR")
	h._check(titles_en != titles_pt, "story titles are actually translated")
	var chrome_ok := true
	for locale in ["en", "pt_BR"]:
		TranslationServer.set_locale(locale)
		for key in ["STORY_CHROME_WAVE", "STORY_CHROME_FINAL_WAVE", "STORY_CHROME_CLEAR", "STORY_CHROME_FALLBACK", "STORY_CHROME_KLOG", 		"STORY_RAINBOW_UNLOCKED", "STORY_HINT_DISMISS", "STORY_WATERMARK", "STORY_ACT_UNIX", "STORY_ACT_WINDOWS", "STORY_ACT_TEMPLEOS", "STORY_TAB_UNIX", "STORY_TAB_WINDOWS", "STORY_TAB_TEMPLEOS"]:
			if tr(key) == key:
				chrome_ok = false
	h._check(chrome_ok, "story runtime chrome resolves in en and pt_BR")

	h._check(Game.has_method("set_language") and Game.has_method("language"),
		"game owns the language setting")
	if Game.has_method("set_language"):
		Game.set_language("pt_BR")
		h._check(Game.language() == "pt_BR" and TranslationServer.get_locale().begins_with("pt"),
			"setting the language moves the TranslationServer locale")
		Game.set_language("en")
	TranslationServer.set_locale(previous)


## As telas de SELEÇÃO falam a mesma língua das telas de estado.
##
## A autora apontou em 2026-09-12 que story/program/bestiary/patch_card eram um
## segundo design system rodando ao lado do primeiro: Orbitron 13-21 contra
## grotesca 26-76, moldura por elemento contra régua e ar, seis acentos
## simultâneos contra um, e offset absoluto de um palco de 1280x720 contra
## container. Zero das quatro usavam um token de `Design` além de scroll_hint.
##
## Estas asserções fixam o CONTRATO do porte, não a aparência: o painel usa o
## tema compartilhado, é dono do próprio cabeçalho (antes o título vinha
## injetado por menu.gd com Orbitron cru e offset fixo), cabe no viewport nos
## quatro degraus, e a cor de identidade fica restrita ao marcador.
func _editorial_screens_test() -> void:
	print("AT_STEP editorial_screens")
	var script: Script = load("res://src/ui/program_panel.gd")
	var panel: Control = script.new()
	h.get_tree().current_scene.add_child(panel)
	await h._ticks(2)

	h._check(panel.theme == UiTheme.shared(), "program selector uses the shared design theme")
	h._check(panel.has_method("title_text") and str(panel.call("title_text")) == tr("PROGRAM_TITLE"),
		"program selector owns its masthead title")
	h._check(panel.has_method("content_rects"), "program selector exposes its content rects")

	if panel.has_method("content_rects"):
		for viewport_size in [Vector2(1920, 1080), Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			panel.size = viewport_size
			await h._ticks(2)
			var label := "%dx%d" % [int(viewport_size.x), int(viewport_size.y)]
			var screen_rect := Rect2(Vector2.ZERO, viewport_size)
			var inside := true
			for content in panel.call("content_rects"):
				if not screen_rect.encloses(content):
					inside = false
			h._check(inside, "program selector content stays inside the screen at %s" % label)

	# Decisão de 2026-09-12: a cor de identidade É informação — o ciano do
	# KERNEL no seletor é o ciano do KERNEL na arena — então ela não some, ela
	# desce a MARCADOR. O texto do card fica em tinta neutra; apagar a cor
	# quebraria o reconhecimento, mantê-la no texto traz o arco-íris de volta.
	h._check(panel.has_method("card_ink"), "program cards expose their ink roles")
	if panel.has_method("card_ink"):
		var ink: Dictionary = panel.call("card_ink", "kernel")
		var identity: Color = Game.PROGRAM_DEFS["kernel"]["visual"]["color"]
		h._check(ink.get("title", Color.BLACK) == Design.TEXT_PRIMARY,
			"program card title uses neutral ink, not the identity colour")
		h._check(ink.get("marker", Color.BLACK) == identity,
			"program card keeps the identity colour as a marker")
		h._check(ink.get("body", Color.BLACK) != identity,
			"program card body text is not tinted by identity")

	# Sem Orbitron: a grotesca editorial é o que separa as duas linguagens.
	h._check(panel.has_method("title_font_size") and int(panel.call("title_font_size")) >= Design.TEXT_HEADING,
		"program selector title uses the display end of the type scale")

	panel.queue_free()
	await h._ticks(2)

	# ── bestiário ─────────────────────────────────────────────────────
	var bestiary_script: Script = load("res://src/ui/bestiary_panel.gd")
	var bestiary: Control = bestiary_script.new()
	h.get_tree().current_scene.add_child(bestiary)
	await h._ticks(2)

	h._check(bestiary.theme == UiTheme.shared(), "bestiary uses the shared design theme")
	h._check(bestiary.has_method("title_text") and str(bestiary.call("title_text")) == tr("BESTIARY_TITLE"),
		"bestiary owns its masthead title")
	h._check(bestiary.has_method("title_font_size") and int(bestiary.call("title_font_size")) >= Design.TEXT_HEADING,
		"bestiary title uses the display end of the type scale")
	h._check(bestiary.has_signal("back_pressed"), "bestiary owns its back action")
	h._check(bestiary.has_method("content_rects"), "bestiary exposes live content rects")

	if bestiary.has_method("content_rects"):
		for viewport_size in [Vector2(1920, 1080), Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			bestiary.size = viewport_size
			await h._ticks(2)
			var bestiary_label := "%dx%d" % [int(viewport_size.x), int(viewport_size.y)]
			var bestiary_screen := Rect2(Vector2.ZERO, viewport_size)
			var bestiary_inside := true
			for content in bestiary.call("content_rects"):
				if not bestiary_screen.encloses(content):
					bestiary_inside = false
			h._check(bestiary_inside, "bestiary content stays inside the screen at %s" % bestiary_label)

	h._check(bestiary.has_method("entry_ink"), "bestiary entries expose semantic ink roles")
	if bestiary.has_method("entry_ink"):
		var entry_id := str(BestiaryPanel.ENTRIES[0]["id"])
		var bestiary_ink: Dictionary = bestiary.call("entry_ink", entry_id)
		var entry_identity := BestiaryPanel.entry_color(entry_id)
		h._check(bestiary_ink.get("title", Color.BLACK) in [Design.TEXT_PRIMARY, Design.TEXT_FAINT],
			"bestiary entry title uses neutral ink")
		h._check(bestiary_ink.get("marker", Color.BLACK) == entry_identity,
			"bestiary keeps entity identity colour as a marker")
		h._check(bestiary_ink.get("body", Color.BLACK) != entry_identity,
			"bestiary body text is not tinted by entity identity")

	var saved_assist := Sfx.color_assist
	Sfx.color_assist = true
	bestiary.call("select_entry", "splitter")
	await h._ticks(2)
	var assist_label = bestiary.get("_detail_assist_label")
	h._check(assist_label is Label and assist_label.is_visible_in_tree() and assist_label.text == "SPLIT",
		"bestiary visibly carries the Splitter assist marker when color assist is enabled")
	Sfx.color_assist = saved_assist

	# O porte trocou hit-testing desenhado à mão por Buttons transparentes. Teste
	# o caminho REAL de clique para não repetir o buraco que a revisão encontrou
	# no primeiro porte do PatchCard (API verde, interação quebrável sem alarme).
	var bestiary_rows: Dictionary = bestiary.get("_rows")
	var click_id := str(BestiaryPanel.ENTRIES[1]["id"])
	var click_row: Control = bestiary_rows.get(click_id)
	var click_buttons := click_row.find_children("*", "Button", true, false) if click_row != null else []
	h._check(not click_buttons.is_empty(), "bestiary row exposes a real interactive hit target")
	if not click_buttons.is_empty():
		(click_buttons[0] as Button).pressed.emit()
		h._check(bestiary.call("detail_entry_id") == click_id,
			"bestiary row click selects the corresponding field entry")

	var back_events: Array = []
	bestiary.back_pressed.connect(func() -> void: back_events.append(true))
	var back_block = bestiary.get("_back_block")
	var back_hit = back_block.get_meta("hit") if back_block is PanelContainer and back_block.has_meta("hit") else null
	h._check(back_hit is Button, "bestiary back action exposes a real interactive hit target")
	if back_hit is Button:
		back_hit.pressed.emit()
		h._check(back_events.size() == 1, "bestiary back action emits back_pressed")

	bestiary.queue_free()
	await h._ticks(2)

	# ── conquistas ────────────────────────────────────────────────────
	var awards_script: Script = load("res://src/ui/achievements_panel.gd")
	var awards: Control = awards_script.new()
	h.get_tree().current_scene.add_child(awards)
	await h._ticks(2)

	h._check(awards.theme == UiTheme.shared(), "achievements uses the shared design theme")
	h._check(awards.has_method("title_text") and str(awards.call("title_text")) == tr("AWARDS_TITLE"),
		"achievements owns its editorial title")
	h._check(awards.has_method("title_font_size") and int(awards.call("title_font_size")) >= Design.TEXT_HEADING,
		"achievements title uses the display end of the type scale")
	h._check(awards.has_signal("back_pressed"), "achievements owns its back action")
	h._check(awards.has_method("content_rects"), "achievements exposes live content rects")
	if awards.has_method("content_rects"):
		for viewport_size in [Vector2(1920, 1080), Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			awards.size = viewport_size
			await h._ticks(2)
			var awards_label := "%dx%d" % [int(viewport_size.x), int(viewport_size.y)]
			var awards_screen := Rect2(Vector2.ZERO, viewport_size)
			var awards_inside := true
			for content in awards.call("content_rects"):
				if not awards_screen.encloses(content):
					awards_inside = false
			h._check(awards_inside, "achievements content stays inside the screen at %s" % awards_label)

	h._check(awards.has_method("row_ink"), "achievement rows expose semantic ink roles")
	if awards.has_method("row_ink"):
		var saved_awards: Dictionary = Game.achievements.duplicate(true)
		Game.achievements = {"first_blood": true}
		var unlocked_ink: Dictionary = awards.call("row_ink", "first_blood")
		var locked_ink: Dictionary = awards.call("row_ink", "boss_purge")
		h._check(unlocked_ink.get("title", Color.BLACK) == Design.TEXT_PRIMARY,
			"unlocked achievement title stays neutral")
		h._check(unlocked_ink.get("marker", Color.BLACK) == Design.SUCCESS,
			"unlocked achievement keeps success green as a marker")
		h._check(locked_ink.get("title", Color.BLACK) in [Design.TEXT_SECONDARY, Design.TEXT_FAINT],
			"locked achievement title stays neutral instead of cyan")
		h._check(locked_ink.get("body", Color.BLACK) != Design.ACCENT,
			"locked achievement hint is not tinted by the global accent")
		Game.achievements = saved_awards

	var awards_back_events: Array = []
	awards.back_pressed.connect(func() -> void: awards_back_events.append(true))
	var awards_back = awards.get("_back_block")
	var awards_back_hit = awards_back.get_meta("hit") if awards_back is PanelContainer and awards_back.has_meta("hit") else null
	h._check(awards_back_hit is Button, "achievements back action exposes a real interactive hit target")
	if awards_back_hit is Button:
		awards_back_hit.pressed.emit()
		h._check(awards_back_events.size() == 1, "achievements back action emits back_pressed")

	# Prova o caminho vivo signal -> refresh. `progress_header()` sozinho lê Game
	# diretamente e passaria mesmo se `_on_achievement_unlocked()` parasse de
	# reconstruir a tela; aqui verificamos o Label e a linha já montados.
	var live_saved_awards: Dictionary = Game.achievements.duplicate(true)
	Game.achievements = {}
	awards.refresh()
	Game.achievements["first_blood"] = true
	Game.achievement_unlocked.emit("first_blood", str(Game.ACHIEVEMENT_DEFS["first_blood"]))
	await h._ticks(2)
	var live_header = awards.get("_header")
	h._check(live_header is Label and (live_header as Label).text.contains("1 / %d" % Game.ACHIEVEMENT_DEFS.size()),
		"achievement unlock refreshes the live awards progress header")
	var live_first_row_unlocked := false
	for raw_row in awards.get("_row_controls"):
		if raw_row is Control and str(raw_row.get_meta("id", "")) == "first_blood":
			var status = raw_row.get_meta("status", null)
			live_first_row_unlocked = status is Label and (status as Label).text == tr("AWARDS_UNLOCKED")
			break
	h._check(live_first_row_unlocked, "achievement unlock refreshes the live awards row state")
	Game.achievements = live_saved_awards
	awards.refresh()

	awards.queue_free()
	await h._ticks(2)

	# ── seletor de fase ───────────────────────────────────────────────
	var story_script: Script = load("res://src/ui/story_panel.gd")
	var story: Control = story_script.new()
	h.get_tree().current_scene.add_child(story)
	await h._ticks(2)

	h._check(story.theme == UiTheme.shared(), "story selector uses the shared design theme")
	h._check(story.has_method("title_text") and str(story.call("title_text")) == tr("STORY_TITLE"),
		"story selector owns its masthead title")

	if story.has_method("content_rects"):
		for viewport_size in [Vector2(1920, 1080), Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
				story.size = viewport_size
				await h._ticks(2)
				var story_label := "%dx%d" % [int(viewport_size.x), int(viewport_size.y)]
				var story_screen := Rect2(Vector2.ZERO, viewport_size)
				var story_inside := true
				for content in story.call("content_rects"):
					if not story_screen.encloses(content):
						story_inside = false
						print("AT_DEBUG story overflow at %s: %s" % [story_label, str(content)])
				h._check(story_inside, "story selector content stays inside the screen at %s" % story_label)

	# Selecionar DESTACA; montar é o segundo passo. Antes `stage_selected` ia
	# direto em `_start_story`, então o painel de detalhe era inalcançável: o
	# clique que o preencheria já iniciava a fase.
	var mounted: Array = []
	story.connect("stage_mounted", func(index: int) -> void: mounted.append(index))
	h._check(bool(story.call("select_stage", 0)), "story selector selects the first stage")
	h._check(mounted.is_empty(), "selecting a stage does not start the run")
	story.call("_mount")
	h._check(mounted == [0], "mounting the highlighted stage starts it")

	story.queue_free()
	await h._ticks(2)


## Dois avisos flutuantes simultâneos não podem cair um sobre o outro.
##
## Capturado em 2026-09-12 com `KP_SHOT=game KP_WAVE=7`: "NEW DATA: X LOGGED" e
## "NEW DATA: Y LOGGED" desenhados no mesmo pixel, nenhum dos dois legível.
## A causa é `Fx.text`, que posiciona tudo em `player.global_position` com
## apenas `randf_range(-8, 8)` de dispersão — e uma onda que estreia dois tipos
## de inimigo ao mesmo tempo é o caso NORMAL, não a exceção.
func _float_text_collision_test() -> void:
	print("AT_STEP float_text_collision")
	h._check(Fx.has_method("live_text_rects"), "fx exposes the live floating-text rects")
	if not Fx.has_method("live_text_rects"):
		return
	var origin := Vector2(480.0, 300.0)
	for label in ["NEW DATA: DRONE LOGGED", "NEW DATA: LANCER LOGGED", "NEW DATA: SPEWER LOGGED"]:
		Fx.text(origin, str(label), Color.WHITE, 12)
	await h._ticks(1)
	var rects: Array[Rect2] = Fx.live_text_rects()
	h._check(rects.size() >= 3, "three simultaneous notices all spawn")
	var disjoint := true
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				disjoint = false
	h._check(disjoint, "simultaneous floating notices never overlap each other")


## O campo da arena não pode competir com as entidades.
##
## Capturado em 2026-09-12 com `KP_SHOT=game KP_WAVE=7`: os setores corrompidos
## do fundo eram vermelho ACESO, cobrindo ~24% da tela, na mesma faixa de matiz
## dos inimigos — e o campo virava ruído onde o jogador precisa ler formas.
##
## A regra que isto fixa é a de legibilidade de arena: o fundo nunca fica mais
## claro que a entidade mais escura. Corrupção passa a ser ausência de luz na
## grade, não luz somada.
func _arena_field_test() -> void:
	print("AT_STEP arena_field")
	# `Balance` resolve como CLASSE, não instância — `has_method` não se aplica.
	var corruption: Color = Balance.background_corruption_color()
	h._check(corruption == Balance.BG_CORRUPTION_COL, "balance owns the background corruption tint")
	var entities := [Balance.COL_DRONE, Balance.COL_LANCER, Balance.COL_SPEWER,
		Balance.COL_SPLITTER, Balance.COL_BULWARK, Balance.COL_MOTE, Balance.COL_PLAYER]
	var dimmest := 1.0
	for entity in entities:
		var entity_color: Color = entity
		dimmest = minf(dimmest, entity_color.get_luminance())
	h._check(corruption.get_luminance() < dimmest,
		"corrupted background sectors stay darker than the dimmest entity")
	h._check(corruption.get_luminance() <= Balance.COL_GRID.get_luminance(),
		"corruption reads as damage to the grid, not as added light")
	h._check(Balance.BG_CORRUPTION_COVERAGE <= 0.15,
		"corrupted sectors stay a minority of the field")
	h._check(Balance.BG_SUBGRID_WEIGHT <= 0.12,
		"the secondary grid stays a texture instead of a second ruling")

	# A mesma regra vale para a GRADE, não só para os setores corrompidos.
	# Três das cinco cores de era são literalmente cores de inimigo (`ff9a3d` é
	# o LANCER, `b46bff` o SPEWER, `ff2a4d` o DANGER), então com mistura alta o
	# campo passava cinco ondas inteiras vestido de ameaça.
	var dimmest_entity: float = Balance.dimmest_entity_luminance()
	for era in Balance.ERA_TINTS:
		var era_tint: Color = era
		var peak: Color = Balance.field_peak_color(era_tint, Balance.ERA_MIX_ENDLESS)
		h._check(peak.get_luminance() < dimmest_entity,
			"the %s era field stays darker than the dimmest entity" % era_tint.to_html(false))
	h._check(Balance.ERA_MIX_STORY <= Balance.ERA_MIX_ENDLESS,
		"story keeps the calmer field of the two")

	# Até aqui a regra de campo só media o ENDLESS: `field_peak_color()` tinha
	# base, grade e brilho fixos, então nenhum tema de fase do Story passava por
	# nenhuma asserção. Foi assim que o `Win11` chegou ao 3.0 com
	# `base_col #dfe9f2` e um centro de arena em (1.67, 1.89, 2.06) — branco
	# estourado nos três canais.
	#
	# Os atos PODEM saturar um canal: é o vermelho do TempleOS e o azul do XP,
	# escolha de identidade. O que nenhum deles pode é saturar os três juntos,
	# porque aí o campo perde o matiz e vira luz branca; nem pode brilhar mais
	# que a coisa mais clara que anda em cima dele.
	var brightest_entity: float = Balance.brightest_entity_luminance()
	for raw_stage in StoryData.STAGES:
		var stage: Dictionary = raw_stage
		var stage_id := str(stage.get("id", ""))
		var stage_peak: Color = Balance.story_field_peak_color(stage.get("theme", {}))
		h._check(not Balance.field_whites_out(stage_peak),
			"the %s field never washes out to white" % stage_id)
		h._check(Balance.field_display_color(stage_peak).get_luminance() <= brightest_entity,
			"the %s field never out-glows the brightest entity" % stage_id)


## A matemática da prova de silhueta, testada sem GPU.
##
## A varredura de calibração de 2026-09-12 descobriu que dilatar a máscara
## DESTRÓI a capacidade de separar formas: o segundo colocado subiu de 0.336
## para 0.892 conforme o raio crescia. Este teste prende essa propriedade em
## duas formas construídas à mão, para que ninguém volte a dilatar a prova de
## inimigo achando que está ganhando sensibilidade.
func _silhouette_metric_test() -> void:
	var proof: Script = load("res://src/ui/design/glyph_proof.gd")
	h._check(proof != null, "glyph proof script loads for metric checks")
	if proof == null:
		return
	var box := 16
	var left := []
	var right := []
	for y in box:
		for x in box:
			# dois quadrados 4x4 que NÃO se tocam: interseção zero, união cheia
			left.append(x >= 2 and x < 6 and y >= 6 and y < 10)
			right.append(x >= 10 and x < 14 and y >= 6 and y < 10)
	var threshold: float = proof.SILHOUETTE_MAX
	h._check(is_equal_approx(threshold, 0.55), "silhouette proof publishes its validated threshold")
	var same: float = proof._iou(left, left)
	h._check(is_equal_approx(same, 1.0), "identical masks score a perfect one")
	var apart: float = proof._iou(left, right)
	h._check(is_equal_approx(apart, 0.0), "disjoint masks score zero")
	var prev: float = proof._iou(left, right)
	var climbed := false
	for radius in [1, 2, 3, 4]:
		var score: float = proof._iou(
			proof._dilate(left, box, int(radius)),
			proof._dilate(right, box, int(radius)))
		if score > prev:
			climbed = true
		prev = score
	h._check(climbed, "dilation drives distinct shapes together, so the silhouette proof compares raw masks")
	# medido: dois quadrados que não compartilham UM pixel chegam a 0.250 sob
	# raio 4. A dilatação não revela semelhança, ela fabrica semelhança.
	h._check(prev >= 0.24, "heavy dilation manufactures overlap between shapes that share no pixel")


func _icon_quality_test() -> void:
	print("AT_STEP icon_quality")
	var icon_script: Script = load("res://src/ui/tactical_icon.gd")
	var icon = icon_script.new() if icon_script != null else null
	h._check(icon != null and icon.has_method("icon_kinds") and icon.has_method("icon_metrics") and icon.has_method("icon_bounds"), "tactical icon exposes icon_kinds, icon_metrics, and icon_bounds")
	if icon == null or not icon.has_method("icon_kinds"):
		if icon != null:
			icon.free()
		return
	var icon_src := str(icon_script.source_code)
	var kinds: Array = icon.call("icon_kinds")
	for kind in ["settings", "bestiary", "dash", "back", "resume", "restart", "terminal", "audio", "music", "warning", "awards", "check"]:
		h._check(kinds.has(kind), "tactical icon covers the %s kind" % kind)
		h._check_source(icon_src.contains("\t\t\"%s\":" % kind), "%s icon resolves to a non-empty drawing routine" % kind)
		var metrics: Dictionary = icon.call("icon_metrics", str(kind))
		h._check(bool(metrics.get("covered", false)), "%s icon has documented quality metrics" % kind)
		h._check(float(metrics.get("min_stroke", 0.0)) >= 1.5, "%s icon documents a minimum stroke of at least 1.5" % kind)
		h._check(float(metrics.get("contrast", 0.0)) >= 0.55, "%s icon documents panel contrast of at least 0.55" % kind)
		var bounds: Rect2 = icon.call("icon_bounds", str(kind))
		for side in [24.0, 52.0]:
			var abs_bounds := Rect2(bounds.position * side, bounds.size * side)
			h._check(Rect2(Vector2.ZERO, Vector2(side, side)).encloses(abs_bounds.grow(-0.5)), "%s icon silhouette stays contained at %.0fpx" % [kind, side])
	icon.free()
	var patch_script: Script = load("res://src/ui/patch_card.gd")
	h._check(patch_script != null and patch_script.has_method("patch_icon_family") and patch_script.has_method("patch_icon_metrics"), "patch card exposes patch_icon_family and patch_icon_metrics")
	if patch_script == null or not patch_script.has_method("patch_icon_family"):
		return
	var patch_src := str(patch_script.source_code)
	for family in ["_draw_damage_glyph", "_draw_fire_glyph", "_draw_defense_glyph", "_draw_utility_glyph", "_draw_movement_glyph", "_draw_economy_glyph"]:
		h._check_source(patch_src.contains("func %s" % family), "patch card draws the %s family" % family.trim_prefix("_draw_").trim_suffix("_glyph"))
	for id in Game.PATCH_CODES:
		var family: String = patch_script.call("patch_icon_family", str(id))
		h._check(["damage", "fire", "defense", "utility", "movement", "economy"].has(family), "%s patch icon belongs to a documented family" % str(id))
		var pmetrics: Dictionary = patch_script.call("patch_icon_metrics", str(id))
		h._check(bool(pmetrics.get("covered", false)), "%s patch icon resolves to a non-empty drawing routine" % str(id))
		h._check(float(pmetrics.get("min_stroke", 0.0)) >= 2.0, "%s patch icon documents a minimum stroke of at least 2.0" % str(id))
		h._check(float(pmetrics.get("contrast", 0.0)) >= 0.55, "%s patch icon documents panel contrast of at least 0.55" % str(id))
		h._check(icon_script.has_method("raster_path") and patch_script.has_method("patch_raster_path"), "icon raster registries keep the code-drawn fallback")
	var probe_path: String = icon_script.call("raster_path", "resume")
	h._check(probe_path.is_empty() or ResourceLoader.exists(probe_path), "raster registry only resolves existing assets")

func _raster_trial_test() -> void:
	print("AT_STEP raster_trial")
	var icon_script: Script = load("res://src/ui/tactical_icon.gd")
	var patch_script: Script = load("res://src/ui/patch_card.gd")
	h._check(icon_script != null and icon_script.has_method("raster_path"), "tactical icon exposes the raster registry")
	h._check(patch_script != null and patch_script.has_method("patch_raster_path"), "patch card exposes the raster registry")
	if icon_script == null or patch_script == null or not icon_script.has_method("raster_path") or not patch_script.has_method("patch_raster_path"):
		return
	var icon_resolved := 0
	var icon_fallback := 0
	for kind in icon_script.call("icon_kinds"):
		var path: String = icon_script.call("raster_path", str(kind))
		if path.is_empty():
			icon_fallback += 1
			continue
		icon_resolved += 1
		var tex: Texture2D = load(path)
		h._check(tex != null, "%s raster resolves to a loadable texture" % str(kind))
	h._check(icon_resolved > 0, "generated ui icon rasters resolve through the registry when the asset exists")
	h._check(icon_fallback > 0, "ui icon kinds without a generated asset keep the code-drawn fallback")
	var patch_resolved := 0
	var patch_fallback := 0
	for id in Game.PATCH_CODES:
		var path: String = patch_script.call("patch_raster_asset", str(id))
		if path.is_empty():
			patch_fallback += 1
			continue
		patch_resolved += 1
		var tex: Texture2D = load(path)
		h._check(tex != null, "patch %s raster resolves to a loadable texture" % str(id))
	h._check(patch_resolved >= 6, "the six generated patch-family rasters resolve through the registry")
	h._check(patch_fallback > 0, "most patch ids never had a generated asset")
	# Seis dos 26 patches tinham raster e vinte não. Os seis desenhavam insígnia
	# hexagonal chapada em cinza, os vinte desenhavam o símbolo de família
	# tingido pelo acento da carta — duas linguagens visuais na MESMA fileira de
	# três cartas. Agora TODOS desenham em código.
	h._check(not PatchCard.USE_RASTER_PATCH_ICONS, "every patch card draws its symbol in code")
	var uniform := true
	for id in Game.PATCH_CODES:
		if not str(patch_script.call("patch_raster_path", str(id))).is_empty():
			uniform = false
	h._check(uniform, "no patch card takes the raster path any more")
	h._check_source(str(icon_script.source_code).contains("match _kind"), "tactical icon keeps the code-drawn draw dispatch")
	# Era texto-fonte: procurava `match patch_icon_family` DENTRO do arquivo, e
	# quebrou ao mover o match para `draw_family_glyph()` — um ponto de entrada
	# estático que existe para a folha de prova medir o MESMO desenho que o card
	# usa. Nenhuma regressão. O contrato real é que cada família tenha desenho
	# próprio, e que desenhar não toque a rng de gameplay.
	# `PatchCard` resolve como CLASSE — `has_method` é de instância.
	h._check(patch_script.has_method("draw_family_glyph"),
		"patch card exposes one entry point for the family symbol")
	var family_seed: int = Game.rng.seed
	# Desenhar fora de `_draw` loga ERROR do engine: a probe desenha DENTRO
	# do próprio `_draw`, que é o único contexto válido de CanvasItem.
	var family_probe := GlyphDrawProbe.new()
	family_probe.draw_fn = func(canvas: Control) -> void:
		for family in ["damage", "fire", "defense", "utility", "movement", "economy"]:
			PatchCard.draw_family_glyph(canvas, str(family), Vector2(24, 24), Color.WHITE)
	family_probe.size = Vector2(48, 48)
	h.get_tree().current_scene.add_child(family_probe)
	await h._ticks(2)
	h._check(Game.rng.seed == family_seed, "patch family symbols draw without touching the gameplay rng")
	family_probe.queue_free()
	h._check_source(str(icon_script.source_code).contains("framed: bool = false"), "tactical icon configure exposes the framed overlay switch (default off)")

func _terminal_history_test(arena: Arena) -> void:
	print("AT_STEP terminal_history")
	var tp: TerminalPanel = arena.get("_terminal_panel")
	h._check(tp != null and is_instance_valid(tp), "arena exposes the live terminal panel")
	if tp == null or not is_instance_valid(tp):
		return
	tp.submit_command("help")
	tp.submit_command("top")
	tp._input.text = ""
	h._check(tp._history_step(-1) and tp._input.text == "top", "terminal UP recalls the last command")
	h._check(tp._history_step(-1) and tp._input.text == "help", "terminal UP walks further back")
	h._check(tp._history_step(1) and tp._input.text == "top", "terminal DOWN walks forward")
	var up_key := InputEventKey.new()
	up_key.pressed = true
	up_key.keycode = KEY_UP
	tp._input.text = ""
	tp._on_input_gui(up_key)
	h._check(tp._input.text == "help", "terminal UP key event recalls history")
	tp._input.text = "su"
	h._check(tp._history_complete() and tp._input.text == "sudo heal", "terminal TAB completes a unique prefix")
	tp._input.text = "m"
	h._check(tp._history_complete() and tp._input.text == "man ", "terminal TAB completes man with room for the target")
	tp._input.text = ""
	h._check(not tp._history_complete(), "terminal TAB on empty input keeps focus navigation")
	tp._input.text = "zzz"
	h._check(not tp._history_complete() and tp._input.text == "zzz", "terminal TAB without matches changes nothing")

func _charm_terminal_test(arena: Arena) -> void:
	print("AT_STEP charm_terminal")
	var terminal_script: Script = load("res://src/ui/terminal_panel.gd")
	h._check(terminal_script != null, "pause terminal script loads")
	h._check(Game.has_method("log_event") and Game.has_method("dmesg_lines"), "game exposes run event log")
	h._check(Game.has_method("consume_terminal_heal"), "game exposes one-use terminal heal")
	h._check(arena.has_method("execute_terminal_command"), "arena exposes terminal command router")
	# A pausa virou PausePanel: a entrada do terminal é uma das ações da fileira.
	var terminal_button_found: bool = arena._pause_screen != null \
		and arena._pause_screen.action_labels().has(tr("PAUSE_TERMINAL"))
	h._check(terminal_button_found and arena.get("_terminal_panel") != null, "pause exposes the terminal entry point")
	if terminal_script == null or not arena.has_method("execute_terminal_command"):
		return
	var saved_mode := Game.mode
	var saved_state := Game.state
	var saved_stats: Dictionary = Game.stats.duplicate(true)
	var saved_events: Array = Game.event_log.duplicate(true) if Game.get("event_log") is Array else []
	var saved_terminal_heal_used := bool(Game.get("terminal_heal_used"))
	var saved_patch_levels: Dictionary = Game.patch_levels.duplicate(true)
	Game.mode = "classic"
	Game.state = Game.State.PLAYING
	Game.wave = 3
	Game.stats = {"time": 12.5, "kills": 4, "shots": 10, "hits": 6, "damage": 1, "wave": 3, "boss_kills": 0, "heals": {}}
	Game.event_log = []
	Game.terminal_heal_used = false
	Game.log_event("TEST EVENT")
	var dmesg: Array = Game.dmesg_lines(4)
	h._check(dmesg.size() == 1 and str(dmesg[0]).contains("TEST EVENT"), "dmesg formats the current run event log")
	h._check(str(arena.execute_terminal_command("help")).contains("sudo heal"), "terminal help lists recovery command")
	h._check(str(arena.execute_terminal_command("top")).contains("CYCLE 03"), "terminal top reports current cycle")
	h._check(str(arena.execute_terminal_command("man drone")).contains("DRONE"), "terminal man returns a bestiary entry")
	h._check(str(arena.execute_terminal_command("dmesg")).contains("TEST EVENT"), "terminal dmesg returns run events")
	if arena.player != null and is_instance_valid(arena.player):
		var old_hp := arena.player.hp
		arena.player.hp = maxi(1, arena.player.max_hp - 1)
		var heal_result := str(arena.execute_terminal_command("sudo heal"))
		h._check(heal_result.contains("granted") and arena.player.hp == old_hp, "sudo heal restores one integrity")
		var second_heal := str(arena.execute_terminal_command("sudo heal"))
		h._check(second_heal.contains("PERMISSION DENIED"), "sudo heal is limited to once per run")
		Game.mode = "onehp"
		Game.terminal_heal_used = false
		arena.player.hp = 1
		h._check(str(arena.execute_terminal_command("sudo heal")).contains("PERMISSION DENIED"), "one hp mode rejects terminal healing")
		arena.player.hp = arena.player.max_hp
	Game.mode = saved_mode
	Game.state = saved_state
	Game.wave = int(saved_stats.get("wave", Game.wave))
	Game.stats = saved_stats
	Game.event_log = saved_events
	Game.terminal_heal_used = saved_terminal_heal_used
	Game.patch_levels = saved_patch_levels

func _charm_speedrun_test(arena: Arena) -> void:
	print("AT_STEP charm_speedrun")
	h._check(Game.has_method("unlock_achievement") and Game.has_method("core_dump_text"), "game exposes achievements and core dump data")
	h._check(Game.has_method("run_seed_text"), "game exposes visible run seed")
	h._check(arena.hud != null and arena.hud.has_method("run_info_text"), "hud exposes speedrun info text")
	h._check(arena.has_method("background_corruption_for_wave"), "arena exposes permanent grid corruption curve")
	h._check(arena.has_method("restart_hold_duration"), "arena exposes hold-to-restart timing")
	if not Game.has_method("unlock_achievement"):
		return
	var achievement_disk: Dictionary = h._config_section_snapshot("achievements")
	var saved_achievements: Dictionary = Game.achievements.duplicate(true) if Game.get("achievements") is Dictionary else {}
	var saved_stats: Dictionary = Game.stats.duplicate(true)
	var saved_events: Array = Game.event_log.duplicate(true) if Game.get("event_log") is Array else []
	var saved_seed := Game.run_seed
	Game.achievements = {}
	Game.stats = {"time": 42.25, "kills": 1, "shots": 8, "hits": 4, "damage": 2, "wave": 4, "boss_kills": 0, "heals": {}}
	Game.event_log = []
	Game.run_seed = 123456
	# `_achievement_t` era comparado com o valor de ANTES e exigido maior. O
	# contador satura em 4.0 e decai com o tempo: se um aviso anterior ainda não
	# tinha decaído, reiniciá-lo dava 4.0 > 4.0 = falso, e a asserção acusava
	# regressão por causa do relógio. O contrato real é que o aviso fique ARMADO
	# no topo e carregue o rótulo certo.
	arena.hud.set("_achievement_t", 0.0)
	var unlocked := bool(Game.unlock_achievement("first_blood"))
	h._check(unlocked and Game.achievements.has("first_blood"), "first achievement unlocks once")
	var live_toast: Label = arena.hud.get("_achievement_label")
	h._check(float(arena.hud.get("_achievement_t")) >= 4.0 and live_toast != null and live_toast.text.contains("FIRST_BLOOD"),
		"live achievement signal immediately surfaces the unlocked label in the HUD")
	h._check(not bool(Game.unlock_achievement("first_blood")), "duplicate achievement stays silent")
	h._check(str(Game.dmesg_lines(8)).contains("achievement: FIRST_BLOOD enabled"), "achievement is recorded in dmesg")
	h._check(str(Game.core_dump_text()).contains("SEGFAULT AT player.hp=0") and str(Game.core_dump_text()).contains("123456"), "core dump includes death marker and build seed")
	h._check(Game.run_seed_text() == "SEED 123456", "run seed has compact HUD text")
	var old_info: bool = bool(Sfx.show_run_info)
	Sfx.show_run_info = true
	h._check(str(arena.hud.run_info_text()).contains("SEED 123456") and str(arena.hud.run_info_text()).contains("00:42"), "speedrun HUD exposes seed and timer")
	Sfx.show_run_info = old_info
	h._check(float(arena.call("background_corruption_for_wave", 1)) == 0.0, "grid starts uncorrupted")
	h._check(float(arena.call("background_corruption_for_wave", 20)) > 0.0, "grid corruption advances with waves")
	h._check(float(arena.call("restart_hold_duration")) > 0.0, "hold-to-restart uses a positive safety delay")
	Game.achievements = saved_achievements
	Game.stats = saved_stats
	Game.event_log = saved_events
	Game.run_seed = saved_seed
	h._restore_config_section("achievements", achievement_disk)
