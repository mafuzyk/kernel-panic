extends RefCounted

## Regression probes for bugs that cross gameplay boundaries.  These are kept
## separate from the older batch-named sections so a failure names the system
## it protects.

var h: Node

func _init(harness: Node) -> void:
	h = harness

func _enemy_death_idempotency_test() -> void:
	print("AT_STEP deep_death_idempotency")
	var drone := DroneEnemy.new()
	var drone_deaths: Array = []
	drone.died.connect(func(_enemy: EnemyBase) -> void: drone_deaths.append(true))
	h.add_child(drone)
	await h._ticks(2)
	drone.take_hit(999, Vector2.LEFT)
	drone.take_hit(999, Vector2.LEFT)
	h._check(drone_deaths.size() == 1, "enemy death emits exactly once under duplicate hits")
	drone.queue_free()

	var bulwark := BulwarkEnemy.new()
	var bulwark_deaths: Array = []
	bulwark.died.connect(func(_enemy: EnemyBase) -> void: bulwark_deaths.append(true))
	h.add_child(bulwark)
	await h._ticks(2)
	bulwark.die()
	bulwark.die()
	h._check(bulwark_deaths.size() == 1, "bulwark death emits exactly once")
	bulwark.queue_free()
	await h._ticks(2)

func _rootlet_shield_recharge_test() -> void:
	print("AT_STEP deep_rootlet_shield_recharge")
	var saved_program := Game.program
	var saved_mode := Game.mode
	Game.mode = "classic"
	Game.program = "rootlet"
	var rootlet := Player.new()
	h.add_child(rootlet)
	await h._ticks(2)
	rootlet.shield_meter = Balance.OC_METER_MAX
	rootlet.shield_ready = true
	rootlet.invuln = 0.0
	rootlet.take_damage(rootlet.global_position + Vector2(10, 0), "DEEP TEST")
	rootlet.invuln = 0.0
	rootlet.meter = 0.0
	rootlet.oc_ready = false
	rootlet.collect_mote()
	h._check(rootlet.shield_meter > 0.0 and is_zero_approx(rootlet.meter) and not rootlet.oc_ready,
		"rootlet refills shield after shield breaks")
	rootlet.queue_free()
	Game.program = saved_program
	Game.mode = saved_mode
	await h._ticks(2)

func _splitshot_rotation_test(arena: Arena) -> void:
	print("AT_STEP deep_splitshot_rotation")
	var saved_patches: Dictionary = Game.patch_levels.duplicate(true)
	Game.patch_levels = {"splitshot": 1}
	var player := arena.player
	player.rotation = 0.0
	player.fire_cd = 0.0
	player._shoot()
	await h._ticks(1)
	var bullets: Array[PlayerBullet] = []
	for child in arena.get_children():
		if child is PlayerBullet:
			bullets.append(child)
	var aligned := bullets.size() == 2
	for bullet in bullets:
		aligned = aligned and absf(wrapf(bullet.rotation - bullet.vel.angle(), -PI, PI)) < 0.02
	h._check(aligned, "splitshot projectile rotation matches its trajectory")
	for bullet in bullets:
		if is_instance_valid(bullet):
			bullet.queue_free()
	Game.patch_levels = saved_patches
	await h._ticks(2)

func _deferred_orb_cap_test(arena: Arena) -> void:
	print("AT_STEP deep_orb_cap")
	for orb in h.get_tree().get_nodes_in_group("enemy_orbs"):
		if is_instance_valid(orb):
			orb.queue_free()
	await h._ticks(3)
	var boss := RootBoss.new()
	boss.boss_index = 1
	boss.configure(1.0, false)
	boss.player = h.get_tree().get_first_node_in_group("player")
	arena.enemy_container.add_child(boss)
	await h._ticks(2)
	var orb_origin := Vector2(420.0, 220.0)
	for i in 39:
		var existing := EnemyOrb.new()
		existing.setup(orb_origin + Vector2(float(i % 8) * 8.0, float(i / 8) * 6.0), Vector2.ZERO, 0.0, Color.RED)
		existing.life = 100.0
		arena.enemy_container.add_child(existing)
	await h._ticks(2)
	var before_burst := h.get_tree().get_nodes_in_group("enemy_orbs").size()
	h._check(before_burst == 39, "orb cap probe installs 39 live orbs")
	boss._do_burst(14, 100.0)
	await h._ticks(3)
	var count := h.get_tree().get_nodes_in_group("enemy_orbs").size()
	h._check(count <= 40, "deferred orb bursts respect the global cap (%d)" % count)
	for orb in h.get_tree().get_nodes_in_group("enemy_orbs"):
		if is_instance_valid(orb):
			orb.queue_free()
	boss.queue_free()
	await h._ticks(3)

func _stage_by_id(stage_id: String) -> Dictionary:
	for index in Game.story_stage_count():
		if Game.story_stage_id(index) == stage_id:
			return Game.story_stage_def(index)
	return {}


func _temple_god_spawn_test() -> void:
	print("AT_STEP deep_temple_god_spawn")
	var arena_stub := Node2D.new()
	var container := Node2D.new()
	var spawner := Spawner.new()
	# Pelo ID: o índice mudou quando o ato macOS entrou antes do bônus.
	var stage := _stage_by_id("temple_god")
	stage["waves"] = [["god"]]
	h.add_child(arena_stub)
	h.add_child(container)
	h.add_child(spawner)
	var started := spawner.start_story(arena_stub, container, stage)
	h._check(started, "TempleOS GOD stage starts scripted spawning")
	await h._ticks(110)
	var boss := spawner._boss
	h._check(boss is GodBoss, "TempleOS GOD stage spawns the GOD boss")
	spawner.stop()
	for child in container.get_children():
		if is_instance_valid(child):
			child.queue_free()
	spawner.queue_free()
	container.queue_free()
	arena_stub.queue_free()
	await h._ticks(3)

## O boss do ato macOS nasce do `boss_kind` da fase, como o GOD.
func _kernel_task_spawn_test() -> void:
	print("AT_STEP deep_kernel_task_spawn")
	var arena_stub := Node2D.new()
	var container := Node2D.new()
	var spawner := Spawner.new()
	var stage := _stage_by_id("mac_kernel_task")
	h._check(not stage.is_empty(), "the macOS act ends on a stage with its own boss")
	if stage.is_empty():
		arena_stub.free()
		container.free()
		spawner.free()
		return
	stage["waves"] = [["kernel_task"]]
	h.add_child(arena_stub)
	h.add_child(container)
	h.add_child(spawner)
	var started := spawner.start_story(arena_stub, container, stage)
	h._check(started, "the KERNEL_TASK stage starts scripted spawning")
	await h._ticks(110)
	var boss := spawner._boss
	h._check(boss is KernelTaskBoss, "the macOS final stage spawns KERNEL_TASK, not ROOT.exe")
	if boss is KernelTaskBoss:
		var panic_boss: KernelTaskBoss = boss
		h._check(not panic_boss.in_panic(), "KERNEL_TASK opens in its reporting state")
		h._check(panic_boss.trace_interval_for_phase(3) < panic_boss.trace_interval_for_phase(1),
			"the stack dump tightens as it loses integrity")
		panic_boss.call("_flip_mode")
		h._check(panic_boss.in_panic() and panic_boss.panics_triggered == 1,
			"flipping the mode enters panic and counts it")
		panic_boss.call("_flip_mode")
		h._check(not panic_boss.in_panic(), "panic ends on its own instead of latching")
	spawner.stop()
	for child in container.get_children():
		if is_instance_valid(child):
			child.queue_free()
	spawner.queue_free()
	container.queue_free()
	arena_stub.queue_free()
	await h._ticks(3)

func _absorb_arms_overclock_test() -> void:
	print("AT_STEP deep_absorb_overclock")
	var saved_program := Game.program
	var saved_mode := Game.mode
	Game.mode = "classic"
	Game.program = "kernel"
	var p := Player.new()
	h.add_child(p)
	await h._ticks(2)
	p.absorb_charges = 2
	p.shield_charges = 0
	p.meter = Balance.OC_METER_MAX - Balance.MOTE_VALUE * 0.5
	p.oc_ready = false
	p.overclock_active = false
	p.invuln = 0.0
	p.take_damage(p.global_position + Vector2(10, 0), "DEEP TEST")
	h._check(p.oc_ready, "absorbed damage completing the meter arms overclock")
	p.try_overclock()
	h._check(p.overclock_active, "armed overclock actually fires after absorb")
	p.queue_free()
	Game.program = saved_program
	Game.mode = saved_mode
	await h._ticks(2)

func _story_hold_restart_test() -> void:
	print("AT_STEP deep_story_hold_restart")
	_sterilize_arena()
	var saved_stage := Game.story_stage_index
	h._check(Game.start_story(0), "story stage 0 starts for hold-restart probe")
	var pre_id := h.get_tree().current_scene.get_instance_id() if h.get_tree().current_scene != null else 0
	var entered: bool = await h._until(func() -> bool:
		var cur := h.get_tree().current_scene
		return cur != null and cur.name == "Arena" and Game.mode == "story" and cur.get_instance_id() != pre_id, 8.0, "story arena")
	if not entered:
		Game.story_stage_index = saved_stage
		return
	await h._ticks(10)
	var arena: Arena = h.get_tree().current_scene
	var old_arena_id := arena.get_instance_id()
	Input.action_press("restart")
	for i in 120:
		await h.get_tree().process_frame
		var cur := h.get_tree().current_scene
		if cur != null and cur.name == "Arena" and cur.get_instance_id() != old_arena_id:
			break
	Input.action_release("restart")
	h._check(Game.mode == "story", "hold restart during story stays in story")
	h._check(Game.story_stage_index == 0, "hold restart replays the same story stage")
	var back: bool = await h._until(func() -> bool:
		return h.get_tree().current_scene != null and h.get_tree().current_scene.name == "Arena", 8.0, "restarted story arena")
	h._check(back, "hold restart reloads the story arena")
	Game.story_stage_index = saved_stage
	await h._ticks(5)

## `rm -rf /` mata a run de DENTRO do terminal, e o terminal só existe com a
## árvore congelada. O defeito era terminar congelado: ninguém despausava, e
## `_on_player_died` fechava o terminal antes de `_state` virar "dead", o que
## fazia o painel de pause voltar por cima da tela de fim.
func _terminal_rm_rf_test() -> void:
	print("AT_STEP deep_terminal_rm_rf")
	_sterilize_arena()
	var saved_mode := Game.mode
	Game.mode = "classic"
	Game.start_run()
	var entered: bool = await h._until(func() -> bool:
		var cur := h.get_tree().current_scene
		return cur != null and cur.name == "Arena" and cur.get("player") != null, 8.0, "rm -rf arena")
	if not entered:
		Game.mode = saved_mode
		return
	await h._ticks(6)
	var arena: Arena = h.get_tree().current_scene
	if arena.spawner != null and is_instance_valid(arena.spawner):
		arena.spawner.stop()
	arena._set_paused(true)
	await h._ticks(3)
	arena.call("_open_terminal")
	await h._ticks(3)
	var terminal: Control = arena.get("_terminal_panel")
	var pause_screen: Control = arena.get("_pause_screen")
	h._check(terminal != null and terminal.visible and h.get_tree().paused,
		"terminal opens over a frozen run")
	if terminal == null:
		Game.mode = saved_mode
		return
	var result := str(terminal.call("submit_command", "rm -rf /"))
	h._check(result.contains("KERNEL PANIC"), "rm -rf / answers with the panic")
	await h._ticks(4)
	h._check(not h.get_tree().paused, "rm -rf / leaves the tree running")
	h._check(not terminal.visible, "rm -rf / closes the terminal it was typed in")
	h._check(pause_screen != null and not pause_screen.visible,
		"rm -rf / does not resurrect the pause panel over the ending")
	h._check(str(arena.get("_state")) == "dead", "rm -rf / ends the run")
	h._check(str(Game.stats.get("killer", "")) == "RM -RF /", "the run records rm -rf / as its killer")
	var summary_shown: bool = await h._until(func() -> bool:
		var panel: Control = arena.get("_run_summary")
		return panel != null and is_instance_valid(panel) and panel.visible, 6.0, "rm -rf run summary")
	h._check(summary_shown, "rm -rf / reaches the run summary")
	h._check(not h.get_tree().paused, "the run summary is reachable without a frozen tree")
	Game.mode = saved_mode
	await h._ticks(3)

## A coordenação de ataque e a antecipação de mira.
##
## Antes disto cada inimigo decidia atacar olhando só para o próprio relógio, e
## todo mundo contornava o jogador pelo mesmo lado com a mesma curvatura: a onda
## virava fila indiana e as investidas chegavam todas no mesmo instante.
func _enemy_ai_test(arena: Arena) -> void:
	print("AT_STEP deep_enemy_ai")
	var saved_mode := Game.mode
	var saved_difficulty := Game.difficulty
	Game.mode = "classic"
	Game.difficulty = "normal"
	# Os inimigos-sonda são REAIS e ficam vivos entre os `await`. Sem blindar o
	# jogador, este teste sangra integridade para dentro dos testes seguintes,
	# que assumem uma run intacta.
	var ai_saved_hp: int = arena.player.hp
	var ai_saved_invuln: float = arena.player.invuln
	arena.player.invuln = 9999.0

	# Teto de atacantes simultâneos: cresce com a onda, com a dificuldade, e tem
	# piso e teto para nunca virar "nenhum ataca" nem "todos atacam".
	h._check(Balance.attack_slot_limit(1) == Balance.ATTACK_SLOTS_BASE,
		"wave 1 opens with the base number of attack slots")
	h._check(Balance.attack_slot_limit(20) > Balance.attack_slot_limit(1),
		"later waves let more enemies commit at once")
	h._check(Balance.attack_slot_limit(999) <= Balance.ATTACK_SLOTS_CAP,
		"the attack slot count stays capped")
	Game.difficulty = "hard"
	var hard_slots := Balance.attack_slot_limit(10)
	Game.difficulty = "easy"
	var easy_slots := Balance.attack_slot_limit(10)
	Game.difficulty = "normal"
	h._check(hard_slots > easy_slots, "hard commits more attackers at once than easy")
	h._check(Balance.attack_slot_limit(1) >= 1, "at least one enemy can always attack")

	# Antecipação de mira: zero no começo, sobe, e para de subir.
	h._check(Balance.aim_lead_factor(1) == 0.0, "the first waves do not lead their shots")
	h._check(Balance.aim_lead_factor(12) > Balance.aim_lead_factor(4),
		"later waves lead the player more")
	h._check(Balance.aim_lead_factor(999) <= Balance.AIM_LEAD_CAP,
		"aim lead stays under the cap that keeps dodging possible")

	# As vagas em si.
	var claimants: Array = []
	for _slot_index in Balance.ATTACK_SLOTS_CAP + 3:
		var claimant := DroneEnemy.new()
		arena.enemy_container.add_child(claimant)
		claimants.append(claimant)
	await h._ticks(2)
	# Sem `await` daqui até a contagem: o `_physics_process` da arena reescreve
	# `attack_slot_limit` pela onda corrente a cada quadro.
	EnemyBase.reset_attack_slots()
	EnemyBase.tick_attack_slots(0.0, 1)
	var limit: int = EnemyBase.attack_slot_limit
	var granted := 0
	for raw_claimant in claimants:
		if raw_claimant.claim_attack_slot(1.0):
			granted += 1
	h._check(granted == limit, "only as many enemies commit as there are slots (%d of %d asked)" % [granted, claimants.size()])
	h._check(claimants[0].claim_attack_slot(1.0), "an enemy that holds a slot can renew it")
	claimants[0].release_attack_slot()
	h._check(claimants[limit].claim_attack_slot(1.0), "releasing a slot hands it to whoever was waiting")
	EnemyBase.tick_attack_slots(5.0, 1)
	h._check(EnemyBase.attack_slots.is_empty(), "slots expire on their own, so a stuck attacker never holds one forever")
	# Morrer devolve a vaga: sem isso um id morto seguraria o teto para sempre.
	var dying: EnemyBase = claimants[1]
	h._check(dying.claim_attack_slot(9.0), "the probe enemy takes a slot before dying")
	dying.die()
	h._check(not EnemyBase.attack_slots.has(dying.get_instance_id()), "dying returns the attack slot")
	for raw_claimant in claimants:
		if is_instance_valid(raw_claimant):
			raw_claimant.queue_free()
	EnemyBase.reset_attack_slots()
	await h._ticks(2)

	# Variedade de flanco: `configure()` sorteia lado e curvatura por inimigo.
	var signs := {}
	var weights := {}
	for _flank_index in 24:
		var probe := DroneEnemy.new()
		probe.configure(1.0, false)
		signs[probe.flank_sign] = true
		weights[snappedf(probe.flank_weight, 0.01)] = true
		probe.free()
	h._check(signs.size() == 2, "enemies do not all orbit the player on the same side")
	h._check(weights.size() > 4, "enemies do not all orbit with the same curvature")

	arena.player.hp = ai_saved_hp
	arena.player.invuln = ai_saved_invuln
	Game.mode = saved_mode
	Game.difficulty = saved_difficulty

## Antecipação e corte de saída medidos sobre um jogador de verdade.
func _enemy_aim_test(arena: Arena) -> void:
	print("AT_STEP deep_enemy_aim")
	var player: Player = arena.player
	if player == null or not is_instance_valid(player):
		return
	var saved_mode := Game.mode
	var saved_wave := Game.wave
	Game.mode = "classic"
	var probe := DroneEnemy.new()
	arena.enemy_container.add_child(probe)
	await h._ticks(2)
	probe.threat_wave = 20
	probe.player = player
	var saved_velocity := player.vel
	var saved_position := player.global_position
	var arena_rect := Balance.arena_rect()
	player.global_position = arena_rect.get_center()
	player.vel = Vector2(300.0, 0.0)
	probe.global_position = arena_rect.get_center() + Vector2(0.0, -260.0)
	var predicted := probe.predict_player_position(0.6)
	h._check(predicted.x > player.global_position.x + 40.0,
		"a moving player is aimed ahead of, not at, where they stand")
	h._check(arena_rect.grow(-3.0).has_point(predicted),
		"the predicted point never leaves the arena")
	player.vel = Vector2.ZERO
	h._check(probe.predict_player_position(0.6).is_equal_approx(player.global_position),
		"a still player is aimed exactly at")

	# Corte de saída: com o jogador na parede esquerda, o inimigo contorna pelo
	# lado que fecha a fuga em vez de empurrá-lo para o campo aberto.
	# O inimigo vem de cima; o campo aberto está à direita. Os dois flancos têm
	# de convergir para o mesmo lado — o que fecha a fuga.
	player.global_position = Vector2(arena_rect.position.x + 30.0, arena_rect.get_center().y)
	probe.global_position = player.global_position + Vector2(0.0, -200.0)
	probe.flank_sign = 1.0
	var sign_a := probe.cutoff_sign()
	probe.flank_sign = -1.0
	var sign_b := probe.cutoff_sign()
	h._check(sign_a == sign_b and not is_zero_approx(sign_a),
		"a cornered player gets the same cutting side from every attacker")
	# De frente para o campo aberto nenhum lado corta melhor, e aí o inimigo
	# não deve fingir que corta: mantém o próprio flanco.
	probe.global_position = player.global_position + Vector2(200.0, 0.0)
	probe.flank_sign = -1.0
	h._check(probe.cutoff_sign() == -1.0,
		"an attacker already between the player and open field keeps its flank")
	player.global_position = arena_rect.get_center()
	probe.flank_sign = -1.0
	h._check(probe.cutoff_sign() == -1.0,
		"in open field the enemy keeps its own flank instead of forcing one")
	player.vel = saved_velocity
	player.global_position = saved_position
	probe.queue_free()
	Game.mode = saved_mode
	Game.wave = saved_wave
	await h._ticks(2)

## O elenco de 3.1. Cada um muda uma REGRA da arena, e é a regra que o teste
## afirma — não a animação.
func _new_cast_test(arena: Arena) -> void:
	print("AT_STEP deep_new_cast")
	var saved_mode := Game.mode
	var saved_difficulty := Game.difficulty
	Game.mode = "classic"
	Game.difficulty = "normal"
	# Mesma regra do teste de IA: sondas vivas não podem cobrar integridade de
	# quem vem depois.
	var cast_saved_hp: int = arena.player.hp
	var cast_saved_invuln: float = arena.player.invuln
	arena.player.invuln = 9999.0

	# ZOMBIE: a primeira morte não é morte.
	var zombie := ZombieEnemy.new()
	arena.enemy_container.add_child(zombie)
	await h._ticks(2)
	zombie.configure(1.0, false)
	h._check(not zombie.defunct and not zombie.dead, "a zombie starts as a live process")
	zombie.die()
	h._check(zombie.defunct and not zombie.dead and is_instance_valid(zombie),
		"killing a zombie leaves a defunct husk instead of removing it")
	h._check(zombie.hp == 1, "the husk takes exactly one more shot to reap")
	h._check(zombie.revive_hp() >= 1 and zombie.revive_hp() < zombie.max_hp,
		"an unreaped zombie returns weaker than it was")
	# Deixar a janela fechar traz ele de volta.
	zombie.reap_t = 0.0
	zombie._move(0.016)
	h._check(not zombie.defunct and zombie.revivals() == 1 and zombie.hp == zombie.revive_hp(),
		"letting the reap window close brings the zombie back")
	# Colher dentro da janela mata de verdade.
	zombie.die()
	h._check(zombie.defunct, "the revived zombie can go defunct again")
	zombie.die()
	h._check(zombie.dead, "a second shot inside the window reaps the zombie for good")
	if is_instance_valid(zombie):
		zombie.queue_free()

	# CRON: relógio visível, cadência ligada à dificuldade, e nunca enche o campo.
	var cron := CronEnemy.new()
	arena.enemy_container.add_child(cron)
	await h._ticks(2)
	cron.threat_wave = 20
	h._check(cron.period() > 0.0 and cron.period() <= CronEnemy.PERIOD,
		"the cron period never grows past its base")
	cron.tick_t = cron.period()
	h._check(is_zero_approx(cron.schedule_fraction()), "a fresh cron reads as zero on its clock")
	cron.tick_t = 0.0
	h._check(cron.schedule_fraction() >= 0.999, "a cron about to fire reads as full on its clock")
	h._check(cron.jobs_run() == 0, "a cron that never ticked ran no jobs")
	cron.queue_free()

	# SWAP: o poço cai com a distância e some na borda do raio.
	var swap := SwapEnemy.new()
	arena.enemy_container.add_child(swap)
	await h._ticks(2)
	swap.global_position = Vector2.ZERO
	var near_pull := swap.pull_at(Vector2(40.0, 0.0))
	var far_pull := swap.pull_at(Vector2(260.0, 0.0))
	h._check(near_pull.length() > far_pull.length(), "the swap well pulls harder up close")
	h._check(near_pull.normalized().is_equal_approx(Vector2.LEFT),
		"the pull points at the well, not away from it")
	h._check(swap.pull_at(Vector2(SwapEnemy.PULL_RADIUS + 1.0, 0.0)) == Vector2.ZERO,
		"outside the radius the swap does nothing at all")
	h._check(swap.pull_at(Vector2.ZERO) == Vector2.ZERO, "the well never divides by zero at its own centre")
	swap.queue_free()

	# BEACHBALL: a roda não machuca, ela atrasa — e tem teto.
	var zone := SpinnerZone.new()
	arena.add_child(zone)
	await h._ticks(2)
	zone.global_position = Vector2.ZERO
	h._check(zone.covers(Vector2(10.0, 0.0)) and not zone.covers(Vector2(zone.radius + 5.0, 0.0)),
		"the spinning wheel covers a disc and nothing outside it")
	h._check(not zone.is_in_group("corruption"),
		"the spinning wheel is not a damage pool — it costs time, not integrity")
	var beachball := BeachballEnemy.new()
	arena.enemy_container.add_child(beachball)
	await h._ticks(2)
	h._check(not beachball.zones_at_cap(), "one wheel on the field is under the cap")
	var extra_zones: Array = []
	for _zone_index in BeachballEnemy.ZONE_CAP:
		var filler := SpinnerZone.new()
		arena.add_child(filler)
		extra_zones.append(filler)
	await h._ticks(2)
	h._check(beachball.zones_at_cap(), "the wheels stop stacking once the field is covered")
	for filler in extra_zones:
		if is_instance_valid(filler):
			filler.queue_free()
	zone.queue_free()
	beachball.queue_free()

	# GENIUS: só pisca quando o jogador realmente saiu da linha.
	var genius := GeniusEnemy.new()
	arena.enemy_container.add_child(genius)
	await h._ticks(2)
	genius.configure(1.0, false)
	genius.player = arena.player
	h._check(not genius.aim_has_drifted(Vector2.RIGHT, Vector2.RIGHT),
		"a player still on the line does not earn a blink")
	h._check(genius.aim_has_drifted(Vector2.RIGHT, Vector2(1.0, 1.0)),
		"a player who left the line does")
	h._check(genius.can_blink(), "a fresh lunge has its blink available")
	var destination := genius.blink_destination()
	h._check(Balance.arena_rect().grow(-2.0).has_point(destination),
		"the blink never lands outside the arena")
	genius.queue_free()

	arena.player.hp = cast_saved_hp
	arena.player.invuln = cast_saved_invuln
	Game.mode = saved_mode
	Game.difficulty = saved_difficulty
	await h._ticks(3)

## A inversão de campo do KERNEL_TASK: troca o MATIZ, não acende a luz.
func _field_inversion_test() -> void:
	print("AT_STEP deep_field_inversion")
	var brightest: float = Balance.brightest_entity_luminance()
	for raw_stage in StoryData.STAGES:
		var stage: Dictionary = raw_stage
		var theme: Dictionary = stage.get("theme", {})
		if theme.is_empty():
			continue
		var flipped: Dictionary = Balance.invert_field_theme(theme)
		var stage_id := str(stage.get("id", ""))
		var hue_moved := false
		for key in Balance.FIELD_INVERT_KEYS:
			if not theme.has(key):
				continue
			var before: Color = theme[key]
			var after: Color = flipped[key]
			if before.s >= 0.05 and absf(fposmod(after.h - before.h + 0.5, 1.0) - 0.5) > 0.02:
				hue_moved = true
		h._check(hue_moved, "inverting the %s field actually moves its hue" % stage_id)
		# A garantia é sobre o campo MONTADO, que é o que a tela mostra: o
		# pânico troca a cor e nunca acende a luz. Medir cor a cor não bastaria,
		# porque girar o matiz troca qual canal satura no framebuffer.
		var peak: Color = Balance.story_field_peak_color(flipped)
		var reference: float = Balance.field_display_color(Balance.story_field_peak_color(theme)).get_luminance()
		h._check(Balance.field_display_color(peak).get_luminance() <= reference + 0.002,
			"the panic never brightens the %s field, only recolours it" % stage_id)
		h._check(not Balance.field_whites_out(peak),
			"the inverted %s field never washes out to white" % stage_id)
		h._check(Balance.field_display_color(peak).get_luminance() <= brightest,
			"the inverted %s field never out-glows the brightest entity" % stage_id)

## O Story deixou de ser uma lista de ondas: tem alvo, tem voz e tem paga.
func _story_substance_test() -> void:
	print("AT_STEP deep_story_substance")

	# Nota: o contrato anunciado na carta de intro é "sem dano E dentro do
	# tempo". Metade disso vale A; ter limpado vale B, e B nunca é um portão.
	h._check(Balance.story_rank(0, 50.0, 90.0) == "S", "no damage inside the target time is an S")
	h._check(Balance.story_rank(0, 200.0, 90.0) == "A", "no damage but slow is an A")
	h._check(Balance.story_rank(3, 50.0, 90.0) == "A", "fast but hurt is an A")
	h._check(Balance.story_rank(3, 200.0, 90.0) == "B", "hurt and slow still clears, as a B")
	h._check(Balance.story_rank(2, 999.0, 0.0) == "A", "a stage with no target time only grades damage")
	h._check(Balance.better_story_rank("B", "S") == "S" and Balance.better_story_rank("S", "B") == "S",
		"the better rank wins no matter which side it is on")
	h._check(Balance.better_story_rank("A", "") == "A", "an unranked stage is beaten by any rank")

	# Alvo de tempo: derivado das ondas, maior quando há boss, nunca zero.
	var lowest := 9999.0
	for stage_id in StoryData.stage_ids():
		var par: float = StoryData.stage_par_seconds(str(stage_id))
		lowest = minf(lowest, par)
	h._check(lowest > 0.0, "every stage publishes a target time")
	h._check(StoryData.stage_par_seconds("kernel") > StoryData.stage_par_seconds("boot"),
		"a boss stage gets more time than the tutorial")
	h._check(StoryData.stage_par_seconds("missing_stage") == 0.0, "an unknown stage has no target")

	# Fim de ato e recompensa.
	var finals: Array = []
	for stage_id in StoryData.stage_ids():
		if StoryData.is_act_final_stage(str(stage_id)):
			finals.append(str(stage_id))
	h._check(finals == ["kernel", "win11", "mac_kernel_task", "temple_god"],
		"each act ends on its own last stage (%s)" % ", ".join(finals))
	for act_id in StoryData.act_ids():
		h._check(StoryData.act_reward(str(act_id)) != "", "the %s act pays a field tint" % act_id)

	# Vozes: o contrato de CONTEÚDO. Uma fase sem falas é uma fase vazia, que é
	# exatamente o que o Story de 3.0 era.
	var previous_locale := TranslationServer.get_locale()
	for locale in ["en", "pt_BR"]:
		TranslationServer.set_locale(locale)
		var silent: Array[String] = []
		for stage_id in StoryData.stage_ids():
			for moment in StoryData.BEAT_MOMENTS:
				if StoryData.localized_beat(str(stage_id), str(moment)).strip_edges().is_empty():
					silent.append("%s/%s" % [stage_id, moment])
		h._check(silent.is_empty(), "every story stage speaks at every beat in %s (%s)" % [locale, ", ".join(silent)])
	TranslationServer.set_locale(previous_locale)
	h._check(StoryData.beat_wave_for_moment("boot", "OPEN") == 1, "the opening line lands on the first wave")
	h._check(StoryData.beat_wave_for_moment("boot", "MID") == 2, "the middle line lands mid-stage")
	h._check(StoryData.beat_wave_for_moment("boot", "CLEAR") == -1, "the closing line is not tied to a wave")

	# Tintas de campo: trancadas até o ato cair, e a escolha não aceita o que
	# não foi conquistado.
	var saved_rewards: Dictionary = Game.story_act_rewards.duplicate(true)
	var saved_tint := Game.field_tint
	Game.story_act_rewards = {}
	Game.field_tint = ""
	h._check(Game.unlocked_field_tints() == [""], "no act cleared means no tint to pick")
	h._check(not Game.field_tint_unlocked("aqua"), "a tint from an uncleared act stays locked")
	Game.set_field_tint("aqua")
	h._check(Game.field_tint == "", "setting a locked tint changes nothing")
	Game.story_act_rewards = {"macos": true}
	h._check(Game.field_tint_unlocked("aqua"), "clearing the act unlocks its tint")
	h._check(Game.unlocked_field_tints().has("aqua"), "the unlocked tint joins the pick list")
	h._check(Balance.field_tint_color("rainbow", 0.0) != Balance.field_tint_color("rainbow", 5.0),
		"the rainbow tint moves with the run clock")
	h._check(Balance.field_tint_color("aqua", 0.0) == Balance.field_tint_color("aqua", 5.0),
		"a fixed tint does not")
	Game.story_act_rewards = saved_rewards
	Game.field_tint = saved_tint

## Limpar a última fase de um ato grava a nota e paga a tinta.
func _story_completion_test() -> void:
	print("AT_STEP deep_story_completion")
	var saved_mode := Game.mode
	var saved_state := Game.state
	var saved_index := Game.story_stage_index
	var saved_stats: Dictionary = Game.stats.duplicate(true)
	var saved_cleared: Dictionary = Game.story_cleared.duplicate(true)
	var saved_ranks: Dictionary = Game.story_ranks.duplicate(true)
	var saved_rewards: Dictionary = Game.story_act_rewards.duplicate(true)
	var saved_best: Dictionary = Game.story_best.duplicate(true)
	var disk: Dictionary = h._config_section_snapshot("story")

	Game.story_ranks = {}
	Game.story_act_rewards = {}
	var index := -1
	for candidate in Game.story_stage_count():
		if Game.story_stage_id(candidate) == "kernel":
			index = candidate
	h._check(index >= 0, "the UNIX act final stage is on the chain")
	if index >= 0:
		# Uma volta impecável: sem dano, dentro do tempo.
		Game.mode = "story"
		Game.state = Game.State.PLAYING
		Game.story_stage_index = index
		Game.stats = {"kills": 9, "shots": 9, "hits": 9, "damage": 0, "time": 10.0, "wave": 5, "boss_kills": 1, "heals": {}}
		h._check(Game.complete_story_stage(), "a cleared stage completes")
		h._check(Game.story_stage_rank("kernel") == "S", "a flawless fast clear records an S")
		h._check(bool(Game.story_act_rewards.get("unix", false)), "clearing the act's last stage pays its tint")
		h._check(Game.field_tint_unlocked(StoryData.act_reward("unix")), "and that tint becomes pickable")
		# Uma volta ruim depois NÃO rebaixa a nota.
		Game.mode = "story"
		Game.state = Game.State.PLAYING
		Game.story_stage_index = index
		Game.stats = {"kills": 9, "shots": 9, "hits": 9, "damage": 5, "time": 999.0, "wave": 5, "boss_kills": 1, "heals": {}}
		h._check(Game.complete_story_stage(), "the stage can be replayed")
		h._check(Game.story_stage_rank("kernel") == "S", "a worse run never downgrades a recorded rank")

	Game.mode = saved_mode
	Game.state = saved_state
	Game.story_stage_index = saved_index
	Game.stats = saved_stats
	Game.story_cleared = saved_cleared
	Game.story_ranks = saved_ranks
	Game.story_act_rewards = saved_rewards
	Game.story_best = saved_best
	h._restore_config_section("story", disk)
	await h._ticks(2)

## O elenco novo em MOVIMENTO, não parado.
##
## Os testes de regra acima são estáticos; este solta um de cada na arena real e
## deixa rodar. É o que pega erro de runtime que só aparece com um alvo vivo, um
## `get_parent()` nulo ou uma zona nascendo enquanto a onda troca.
##
## Roda no FIM do bloco da arena2 de propósito: ele esvazia o campo, e um campo
## vazio faz o spawner fechar a onda e abrir a próxima inteira de uma vez — o
## que cobrava integridade de todo teste que viesse depois.
func _new_cast_live_test(arena: Arena) -> void:
	print("AT_STEP deep_new_cast_live")
	# O teste POSSUI a arena por nove segundos e tem de devolvê-la intacta: o
	# resto da suíte continua na mesma cena, com o mesmo jogador e a mesma onda.
	var was_running: bool = arena.spawner.get("_running")
	var saved_hp: int = arena.player.hp
	var saved_invuln: float = arena.player.invuln
	arena.player.invuln = 9999.0
	arena.spawner.stop()
	for kind in ["zombie", "cron", "swap", "beachball", "genius"]:
		var member: EnemyBase = arena.spawner.call("_make_enemy", str(kind))
		if member == null:
			continue
		member.threat_wave = 14
		member.position = arena.player.global_position + Vector2.from_angle(Game.rng.randf() * TAU) * 260.0
		member.configure(1.3, false)
		arena.enemy_container.add_child(member)
	await h._ticks(2)
	var spawned := EnemyBase.shared_list.size()
	h._check(spawned >= 5, "the whole new cast reaches the arena (%d)" % spawned)
	# Tempo real de física com o jogador vivo: cada um exercita o próprio ciclo
	# completo, incluindo a agenda do CRON e a roda do BEACHBALL.
	await h._simulation_seconds(9.0)
	var alive := 0
	for member in EnemyBase.shared_list:
		if is_instance_valid(member):
			alive += 1
	h._check(alive > 0, "the cast survives nine seconds of live physics")
	h._check(arena.player != null and is_instance_valid(arena.player), "and so does the player they are chasing")
	for member in EnemyBase.shared_list.duplicate():
		if is_instance_valid(member):
			member.queue_free()
	for zone in h.get_tree().get_nodes_in_group("spinner_zone"):
		if is_instance_valid(zone):
			zone.queue_free()
	await h._ticks(3)
	EnemyBase.reset_attack_slots()
	arena.player.hp = saved_hp
	arena.player.invuln = saved_invuln
	# Religa o spawner onde ele estava em vez de chamar `start()`: um `start()`
	# recomeça a ONDA do zero, e reabrir uma onda 7 inteira em cima do jogador
	# cobrava integridade dos testes seguintes.
	arena.spawner.set("_running", was_running)
	await h._ticks(3)

## Traits da semana. O contrato é: sorteio determinístico, e cada trait mordendo
## exatamente o botão que ele promete.
func _weekly_traits_test() -> void:
	print("AT_STEP deep_weekly_traits")
	var saved_mode := Game.mode
	var saved_difficulty := Game.difficulty
	Game.difficulty = "normal"

	# Determinismo: a mesma semana devolve o mesmo plano, sempre, e semanas
	# diferentes não devolvem todas a mesma coisa.
	var plan_a: Dictionary = Weekly.plan_for_week(2959)
	var plan_b: Dictionary = Weekly.plan_for_week(2959)
	h._check(plan_a == plan_b, "the same week always rolls the same plan")
	var seen_traits := {}
	var seen_rosters := {}
	for week in range(2900, 2960):
		var plan: Dictionary = Weekly.plan_for_week(week)
		var ids: Array = plan["traits"]
		h._check(ids.size() == Weekly.TRAIT_COUNT, "week %d rolls exactly %d traits" % [week, Weekly.TRAIT_COUNT])
		h._check(ids[0] != ids[1], "week %d rolls two different traits" % week)
		for id in ids:
			h._check(Weekly.TRAITS.has(str(id)), "week %d rolls a real trait (%s)" % [week, id])
			seen_traits[str(id)] = true
		h._check(Weekly.ROSTERS.has(str(plan["roster"])), "week %d rolls a real roster" % week)
		seen_rosters[str(plan["roster"])] = true
	h._check(seen_traits.size() >= 6, "sixty weeks visit most of the trait table (%d)" % seen_traits.size())
	h._check(seen_rosters.size() >= 3, "sixty weeks visit most of the roster table (%d)" % seen_rosters.size())

	# O sorteio NÃO pode consumir a sequência que compõe as ondas: a composição
	# semanal tem teste de determinismo em cima da `Game.rng`.
	var rng_before := Game.rng.state
	Weekly.plan_for_week(1234)
	h._check(Game.rng.state == rng_before, "rolling the week never touches the gameplay rng")

	# Fora do Weekly, tudo neutro.
	Game.mode = "classic"
	h._check(Weekly.active_traits().is_empty(), "classic runs carry no weekly traits")
	h._check(Weekly.roster_kinds().is_empty(), "classic runs carry no weekly roster")
	h._check(is_equal_approx(Weekly.factor("enemy_hp"), 1.0), "every factor is neutral outside the weekly")
	h._check(is_equal_approx(Weekly.factor("arena"), 1.0), "including the one that resizes the arena")
	var open_arena := Balance.arena_rect()

	# Cada trait, medido no botão que ele promete.
	Game.mode = "weekly"
	for trait_id in Weekly.TRAITS.keys():
		var id := str(trait_id)
		Weekly._cache_week = Game.week_number()
		Weekly._cache = {"traits": [id], "roster": "mixed"}
		match id:
			"swift":
				var fast := DroneEnemy.new()
				var base_speed: float = fast.speed
				fast.configure(1.0, false)
				h._check(fast.speed > base_speed, "swift makes enemies faster")
				fast.free()
			"armored":
				var tough := DroneEnemy.new()
				var base_hp: int = tough.hp
				tough.configure(1.0, false)
				h._check(tough.hp > base_hp and tough.max_hp == tough.hp,
					"armored raises enemy integrity before the bar is measured")
			"swarm":
				var frail := DroneEnemy.new()
				var frail_base: int = frail.hp
				frail.configure(1.0, false)
				h._check(frail.hp <= frail_base, "swarm makes each process frailer")
				frail.free()
			"cramped":
				h._check(Balance.arena_rect().size.x < open_arena.size.x, "cramped shrinks the field")
			"volatile":
				var popper := DroneEnemy.new()
				h._check(popper.volatile_burst_count() > 0, "volatile makes ordinary processes burst")
				popper.free()
			"frugal":
				h._check(not Game.should_offer_patch(Balance.BOSS_EVERY - 1),
					"frugal skips the patch the classic cadence would have offered")
			"elite":
				h._check(Balance.difficulty_elite_chance(20) > 0.0, "elite keeps a live elite chance")
	# Um trait sozinho não pode zerar o orçamento da onda.
	for trait_id in Weekly.TRAITS.keys():
		Weekly._cache_week = Game.week_number()
		Weekly._cache = {"traits": [str(trait_id)], "roster": "mixed"}
		h._check(Balance.difficulty_wave_budget(9) >= 1,
			"%s still leaves a wave worth spawning" % trait_id)

	# Todo roster tem de conseguir gastar o orçamento: sem unidade barata o
	# spawner gira em falso até o guard estourar.
	for roster_id in Weekly.ROSTERS.keys():
		var kinds: Array = Weekly.ROSTERS[roster_id]
		h._check(kinds.has("drone"), "roster %s keeps a cheap unit the budget can always afford" % roster_id)

	# O contrato que importa: a FILA da onda só contém o que o roster libera.
	# Sem isto o roster seria só uma etiqueta bonita no menu.
	var roster_probe := Spawner.new()
	h.add_child(roster_probe)
	for roster_id in Weekly.ROSTERS.keys():
		Weekly._cache_week = Game.week_number()
		Weekly._cache = {"traits": [], "roster": str(roster_id)}
		var allowed: Array = Weekly.ROSTERS[roster_id]
		var intruders := {}
		var produced := 0
		for wave_probe in [6, 10, 14]:
			roster_probe.wave = wave_probe
			roster_probe.wave_event = ""
			roster_probe.call("_build_queue")
			for kind in roster_probe._queue:
				produced += 1
				if not allowed.has(str(kind)):
					intruders[str(kind)] = true
		h._check(produced > 0, "roster %s still fills a wave" % roster_id)
		h._check(intruders.is_empty(),
			"roster %s spawns only what it allows (%s)" % [roster_id, ", ".join(intruders.keys())])
	# E sem semana ativa a fila volta a usar o elenco inteiro.
	Game.mode = "classic"
	var open_kinds := {}
	for wave_probe in [10, 14, 18]:
		roster_probe.wave = wave_probe
		roster_probe.wave_event = ""
		roster_probe.call("_build_queue")
		for kind in roster_probe._queue:
			open_kinds[str(kind)] = true
	h._check(open_kinds.size() > 4, "classic keeps the whole cast available (%d kinds)" % open_kinds.size())
	Game.mode = "weekly"
	roster_probe.queue_free()
	Weekly._cache_week = -1
	Game.mode = saved_mode
	Game.difficulty = saved_difficulty
	await h._ticks(2)

## Story vira set-piece, Endless continua o jogo de build.
##
## O que este teste afirma é a SEPARAÇÃO: a fase entrega ferramenta e impõe
## regra de campo; o endless sorteia a ferramenta e não impõe regra nenhuma.
func _story_setpiece_test() -> void:
	print("AT_STEP deep_story_setpiece")
	var hazard_script: Script = load("res://src/arena/hazard_kit.gd")
	h._check(hazard_script != null, "the hazard kit loads")
	if hazard_script == null:
		return

	# Toda fase declara as duas coisas, e nenhuma declara um perigo inventado.
	var known := ["none", "spill", "surge", "shrink", "no_heal", "haste"]
	var with_build := 0
	var with_hazard := 0
	for stage_id in StoryData.stage_ids():
		var id := str(stage_id)
		var hazard := StoryData.stage_hazard(id)
		h._check(known.has(hazard), "stage %s declares a real field rule (%s)" % [id, hazard])
		if hazard != "none":
			with_hazard += 1
		var build: Dictionary = StoryData.stage_build(id)
		if not build.is_empty():
			with_build += 1
		# Um build só pode entregar patches que existem, e dentro do teto deles.
		for patch_id in build:
			var found := false
			for definition in Game.PATCH_DEFS:
				if str(definition["id"]) == str(patch_id):
					found = true
					h._check(int(build[patch_id]) <= int(definition["max"]),
						"stage %s issues %s inside its cap" % [id, patch_id])
					break
			h._check(found, "stage %s issues a real patch (%s)" % [id, patch_id])
	h._check(with_build >= 10, "most stages issue a build of their own (%d)" % with_build)
	h._check(with_hazard >= 8, "most stages impose a field rule (%d)" % with_hazard)
	# O build tem de CRESCER dentro do ato: a fase 1 não pode entregar o mesmo
	# que a última.
	h._check(StoryData.stage_build("boot").is_empty(), "the tutorial stage starts bare on purpose")
	h._check(StoryData.stage_build("kernel").size() > StoryData.stage_build("var_log").size(),
		"the act's last stage issues more than its second")

	# O kit, medido sem arena: cada regra mexendo no que promete.
	#
	# `configure()` e `on_wave_started()` de `shrink` escrevem no override GLOBAL
	# do tamanho da arena. Sem devolver o valor, este teste deixava o campo
	# encolhido para todo mundo que viesse depois — e a jogadora dos testes
	# seguintes apanhava de um campo que ninguém pediu.
	var saved_override := Balance.arena_rect().size
	var kit = hazard_script.new(null)
	kit.configure({"hazard": "none"})
	h._check(not kit.active() and not kit.blocks_heal(), "a stage with no rule imposes nothing")
	h._check(is_equal_approx(kit.arena_scale(), 1.0) and is_equal_approx(kit.haste_factor(), 1.0),
		"and leaves the field and the cast alone")
	kit.configure({"hazard": "no_heal"})
	h._check(kit.blocks_heal(), "read-only refuses to give integrity back")
	kit.configure({"hazard": "shrink"})
	var wide: float = kit.arena_scale()
	kit.on_wave_started(6)
	h._check(kit.arena_scale() < wide, "memory pressure shrinks the field as waves pass")
	kit.on_wave_started(999)
	h._check(kit.arena_scale() >= hazard_script.SHRINK_FLOOR,
		"but never past the floor that would close it on the player")
	kit.configure({"hazard": "haste"})
	var calm: float = kit.haste_factor()
	kit.on_wave_started(5)
	h._check(kit.haste_factor() > calm, "thermal throttle speeds the cast up")
	kit.on_wave_started(999)
	h._check(kit.haste_factor() <= hazard_script.HASTE_CAP, "and stops at its cap")

	# A separação: o Story não oferece patch nenhum, o endless oferece.
	var saved_mode := Game.mode
	Game.mode = "story"
	var offers := 0
	for wave_probe in range(1, 30):
		if Game.should_offer_patch(wave_probe):
			offers += 1
	h._check(offers > 0, "the cadence helper itself still answers in story")
	Game.mode = saved_mode
	kit = null
	Balance.clear_arena_size_override()
	h._check(Balance.arena_rect().size == saved_override,
		"the hazard probe gives the field back exactly as it found it")
	await h._ticks(2)

## O build da fase chega MESMO na run, não só na tabela.
##
## Roda no FIM do bloco da arena2: `start_story()` troca de cena, e a arena que
## os testes seguintes recebem seria um objeto já liberado.
func _story_build_applied_test() -> void:
	print("AT_STEP deep_story_build_applied")
	var saved_mode := Game.mode
	var saved_state := Game.state
	var saved_index := Game.story_stage_index
	var saved_patches: Dictionary = Game.patch_levels.duplicate(true)
	var saved_cleared: Dictionary = Game.story_cleared.duplicate(true)
	var disk: Dictionary = h._config_section_snapshot("story")

	var index := -1
	for candidate in Game.story_stage_count():
		if Game.story_stage_id(candidate) == "kernel":
			index = candidate
	if index >= 0:
		Game.story_cleared = {}
		for unlock in index:
			Game.story_cleared[Game.story_stage_id(unlock)] = true
		Game.patch_levels = {"rapid": 99}
		h._check(Game.start_story(index), "the stage starts")
		var expected: Dictionary = StoryData.stage_build("kernel")
		h._check(Game.patch_levels == expected,
			"starting a stage installs exactly its issued build (%s)" % str(Game.patch_levels))
		h._check(not Game.patch_levels.has("rapid"),
			"and wipes whatever the previous run left behind")
		for patch_id in expected:
			h._check(Game.patch_level(str(patch_id)) == int(expected[patch_id]),
				"the run reports %s at the issued level" % patch_id)
	Game.mode = saved_mode
	Game.state = saved_state
	Game.story_stage_index = saved_index
	Game.patch_levels = saved_patches
	Game.story_cleared = saved_cleared
	h._restore_config_section("story", disk)
	# Deixa a troca de cena assentar antes de devolver o controle: sair daqui no
	# meio dela entrega uma árvore pela metade para o teste seguinte.
	await h._until(func() -> bool:
		return h.get_tree().current_scene != null and h.get_tree().current_scene.name == "Arena", 8.0, "story build arena")
	await h._ticks(4)

func _oom_ownership_test(arena: Arena) -> void:
	print("AT_STEP deep_oom_ownership")
	var mf: MoteField = arena.mote_field
	arena.spawner.stop()
	for node in h.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()
	await h._ticks(2)
	for i in range(mf.count() - 1, -1, -1):
		mf.kill_slot(i)
	var a_idx := mf.spawn(arena.player.global_position + Vector2(200, 0))
	var b_idx := mf.spawn(arena.player.global_position + Vector2(260, 0))
	var a_uid: int = mf.uid_of(a_idx)
	var b_uid: int = mf.uid_of(b_idx)
	var oom1: EnemyBase = arena.spawner._make_enemy("oom")
	var oom2: EnemyBase = arena.spawner._make_enemy("oom")
	oom1.position = arena.player.global_position + Vector2(340, 0)
	oom2.position = arena.player.global_position + Vector2(340, 80)
	arena.enemy_container.add_child(oom1)
	arena.enemy_container.add_child(oom2)
	await h._ticks(2)
	oom1._steal(a_idx, a_uid)
	oom2._steal(b_idx, b_uid)
	h._check(mf.is_stolen(a_idx) and mf.is_stolen(b_idx), "two ooms hold one mote each")
	oom1.die()
	await h._ticks(2)
	var a_back := mf.idx_of_uid(a_uid)
	h._check(a_back >= 0 and mf.alive_at(a_back) and not mf.is_stolen(a_back), "a dying oom releases only its own mote")
	h._check(mf.is_stolen(mf.idx_of_uid(b_uid)), "the surviving oom keeps its mote")
	oom2._escape()
	await h._ticks(2)
	h._check(mf.idx_of_uid(b_uid) < 0, "an escaping oom frees only its own mote")
	h._check(mf.idx_of_uid(a_uid) >= 0, "the released mote survives the other's escape")
	h._check(not a_uid in mf.stolen_ids() and not b_uid in mf.stolen_ids(), "stolen ids track live stolen motes by uid")

func _page_fault_cap_test(arena: Arena) -> void:
	print("AT_STEP deep_page_cap")
	arena.spawner.stop()
	for node in h.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()
	await h._ticks(2)
	var boss1 := RootBoss.new()
	boss1.boss_index = 1
	boss1.configure(1.0, false)
	boss1.position = arena.player.global_position + Vector2(360, 0)
	var boss2 := RootBoss.new()
	boss2.boss_index = 1
	boss2.configure(1.0, false)
	boss2.position = arena.player.global_position + Vector2(-360, 0)
	arena.enemy_container.add_child(boss1)
	arena.enemy_container.add_child(boss2)
	await h._ticks(2)
	boss1._do_pages()
	await h._ticks(3)
	h._check(boss1._pages_alive() == 4, "page fault fills exactly four pages")
	boss1._do_pages()
	await h._ticks(3)
	h._check(boss1._pages_alive() == 4, "page fault never exceeds four pages per boss")
	var killed := 0
	for p in h.get_tree().get_nodes_in_group("page"):
		if is_instance_valid(p) and p.get("boss") == boss1 and killed < 2:
			p.take_hit(999, boss1.global_position)
			killed += 1
	await h._ticks(3)
	h._check(boss1._pages_alive() == 2, "killing pages drops the owned count")
	boss1._do_pages()
	await h._ticks(3)
	h._check(boss1._pages_alive() == 4, "page fault refills only the deficit")
	boss2._do_pages()
	await h._ticks(3)
	h._check(boss2._pages_alive() == 4 and boss1._pages_alive() == 4, "two bosses cap pages independently")
	boss1.queue_free()
	boss2.queue_free()
	for p in h.get_tree().get_nodes_in_group("page"):
		if is_instance_valid(p):
			p.queue_free()
	await h._ticks(3)

func _dash_recharge_test() -> void:
	print("AT_STEP deep_dash_recharge")
	var saved_program := Game.program
	var saved_mode := Game.mode
	var saved_patches: Dictionary = Game.patch_levels.duplicate(true)
	Game.mode = "classic"
	Game.program = "daemon"
	Game.patch_levels = {"dash": 1}
	var p := Player.new()
	h.add_child(p)
	await h._ticks(2)
	h._check(p.dash_charges == 2 and p.available_dash_charges() == 2, "daemon starts with two dash charges")
	p.request_dash(Vector2.RIGHT)
	await h._ticks(2)
	h._check(p.available_dash_charges() == 1, "first dash spends one charge")
	p.dash_t = 0.0
	p.request_dash(Vector2.RIGHT)
	await h._ticks(2)
	h._check(p.available_dash_charges() == 0, "second dash spends the last charge")
	var single_interval := Balance.DASH_CD * 0.82
	var t0 := Time.get_ticks_msec()
	var one_back: bool = await h._until(func() -> bool: return p.available_dash_charges() >= 1, 8.0, "first charge returns")
	var t1 := Time.get_ticks_msec()
	h._check(one_back, "recharge returns 0 to 1")
	h._check(float(t1 - t0) < Balance.DASH_CD * 1000.0, "quick dash shortens each interval")
	var two_back: bool = await h._until(func() -> bool: return p.available_dash_charges() >= 2, 8.0, "second charge returns")
	h._check(two_back, "idle recharge returns 1 to 2")
	p.dash_recharge_t = 1.0
	p.notify_kill()
	h._check(p.dash_recharge_t < 1.0, "kill dash refund stays coherent")
	p.queue_free()
	Game.program = saved_program
	Game.mode = saved_mode
	Game.patch_levels = saved_patches
	await h._ticks(2)

func _heal_semantics_test() -> void:
	print("AT_STEP deep_heal_semantics")
	var saved_program := Game.program
	var saved_mode := Game.mode
	var saved_ach: Dictionary = Game.achievements.duplicate(true)
	var saved_ach_disk: Dictionary = h._config_snapshot("achievements", "unlocked", {})
	Game.mode = "classic"
	Game.program = "kernel"
	Game.achievements.erase("integrity_restored")
	var p := Player.new()
	h.add_child(p)
	await h._ticks(2)
	Game.stats["heals"] = {}
	Game._hp_lost_since_heal = false
	p.hp = p.max_hp
	var gained_full := p.heal(1, "cycle")
	h._check(gained_full == 0 and not Game.stats["heals"].has("cycle"), "healing at full hp records nothing")
	p.invuln = 0.0
	p.dash_t = 0.0
	p.take_damage(p.global_position + Vector2(10, 0), "DEEP TEST")
	var gained := p.heal(1, "cycle")
	h._check(gained == 1 and int(Game.stats["heals"].get("cycle", 0)) == 1, "real healing records telemetry")
	h._check(Game.achievements.has("integrity_restored"), "integrity_restored unlocks on real restore after loss")
	p.queue_free()
	Game.achievements = saved_ach
	h._restore_config_snapshot("achievements", "unlocked", saved_ach_disk)
	Game.program = saved_program
	Game.mode = saved_mode
	await h._ticks(2)

## Congela combate antes de trocar de cena no teste: player invencível,
## spawner parado, sem tiro. Mortes/Fx durante waits mascaravam a contagem
## de órfãos e poluíam o estado da arena seguinte.
func _sterilize_arena() -> void:
	var cur: Node = h.get_tree().current_scene
	if cur != null and is_instance_valid(cur) and cur.name == "Arena":
		if cur.get("player") != null and is_instance_valid(cur.get("player")):
			cur.get("player").invuln = 9999.0
		if cur.get("spawner") != null and is_instance_valid(cur.get("spawner")):
			cur.get("spawner").stop()
	Input.action_release("fire")

func _scene_swap_hygiene_test() -> void:
	print("AT_STEP deep_swap_hygiene")
	_sterilize_arena()
	var before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var pre_id := h.get_tree().current_scene.get_instance_id() if h.get_tree().current_scene != null else 0
	var pre_scene: Node = h.get_tree().current_scene
	Game.start_run()
	var ok: bool = await h._until(func() -> bool:
		var c := h.get_tree().current_scene
		return c != null and c.name == "Arena" and c.get_instance_id() != pre_id, 8.0, "sterile arena")
	h._check(ok, "sterile scene swap lands a fresh arena")
	await h._ticks(5)
	h._check(not is_instance_valid(pre_scene), "the previous scene is freed by the swap, not orphaned")
	var after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	h._check(after <= before, "a sterile scene swap leaks no orphans (%d -> %d)" % [before, after])
	Game.to_menu()
	var menu_ok: bool = await h._until(func() -> bool:
		var c := h.get_tree().current_scene
		return c != null and c.name == "Menu", 8.0, "sterile menu")
	h._check(menu_ok, "sterile swap returns to menu")
	await h._ticks(5)
	var after_menu := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	h._check(after_menu <= after, "menu build leaks no orphans (%d -> %d)" % [after, after_menu])

func _vampic_reset_test() -> void:
	print("AT_STEP deep_vampic_reset")
	_sterilize_arena()
	Game.vampic_cd = 5.0
	var pre_run_id := h.get_tree().current_scene.get_instance_id() if h.get_tree().current_scene != null else 0
	Game.start_run()
	h._check(Game.vampic_cd <= 0.0, "new run does not inherit vampic cooldown")
	# Por instance_id: o mode troca na hora mas a cena troca deferred; casar
	# só por nome/mode validava a arena VELHA e o teste seguinte herdava
	# uma cena já condenada (foi o que matava o reticle do teste modal).
	var ok: bool = await h._until(func() -> bool:
		var cur := h.get_tree().current_scene
		return cur != null and cur.name == "Arena" and cur.get_instance_id() != pre_run_id, 8.0, "fresh arena after cooldown reset")
	h._check(ok, "fresh arena loads after cooldown reset")
	Game.vampic_cd = 5.0
	var pre_story_id := h.get_tree().current_scene.get_instance_id() if h.get_tree().current_scene != null else 0
	h._check(Game.start_story(0), "story starts for cooldown probe")
	h._check(Game.vampic_cd <= 0.0, "new story does not inherit vampic cooldown")
	var ok2: bool = await h._until(func() -> bool:
		var cur := h.get_tree().current_scene
		return cur != null and cur.name == "Arena" and Game.mode == "story" and cur.get_instance_id() != pre_story_id, 8.0, "story arena after cooldown reset")
	h._check(ok2, "story arena loads after cooldown reset")

func _probe() -> void:
	h._watchdog(30.0)
	await h._ticks(20)
	Game.start_run()
	var ok: bool = await h._until(func() -> bool:
		return h.get_tree().current_scene != null and h.get_tree().current_scene.name == "Arena", 8.0, "deep probe arena")
	if not ok:
		h.get_tree().quit(1)
		return
	await h._ticks(10)
	var arena: Arena = h.get_tree().current_scene
	await _enemy_death_idempotency_test()
	await _rootlet_shield_recharge_test()
	await _absorb_arms_overclock_test()
	await _dash_recharge_test()
	await _heal_semantics_test()
	await _scene_swap_hygiene_test()
	await _oom_ownership_test(arena)
	await _page_fault_cap_test(arena)
	await _splitshot_rotation_test(arena)
	await _deferred_orb_cap_test(arena)
	await _temple_god_spawn_test()
	h._finish()
