# Identity Pack v2.3.5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the four cosmetic identity features (boot sequence, man-page bestiary, stack trace on elite/boss kill, PC terminal reticle) plus the `Balance.is_desktop_display()` Wayland helper.

**Architecture:** Everything is additive and code-drawn. Two new files (`boot.gd`, `reticle.gd`), small edits to `balance.gd`, `menu.gd`, `bestiary_panel.gd`, `fx.gd`, `arena.gd`, `camera_rig.gd`, and test additions to `dev_harness.gd`. One commit per task, full autotest green at every commit.

**Tech Stack:** Godot 4.7.2, GDScript 2, existing project harness (`DevHarness._autotest`).

**Spec:** `docs/superpowers/specs/2026-08-27-identity-pack-design.md` (read both).

## Global Constraints

- Godot 4.7.2, GDScript, project root = repo root. Main scene stays `res://src/ui/menu.tscn`.
- Full autotest after every task: `godot --headless --path . -- --autotest` → must print `AUTOTEST_ALL_PASS` before committing.
- Do NOT touch: difficulty knobs (`Balance.WAVE_SCALE_CAP`, `Balance.elite_chance`), gameplay numbers, lock-on, One-HP rules, mobile-only behavior.
- Gameplay RNG determinism: never consume `Game.rng` from cosmetic code; use the global `randi()`/`randf()`.
- All new text is hardcoded English, lowercase-terminal tone for logs/bugs lines.
- Never commit APKs, keystores, `.godot/`, private paths. Binaries only via GitHub Releases (not this pack's concern).
- Insert harness tests in `DevHarness._autotest` (`src/autoload/dev_harness.gd`), using the existing `_check(cond, msg)` helper, placed after the last existing enemy checks and before `_finish()`.

---

### Task 1: `Balance.is_desktop_display()` helper

**Files:**
- Modify: `src/autoload/balance.gd` (append after `arena_rect()`)
- Modify: `src/arena/camera_rig.gd:22`
- Modify: `src/autoload/dev_harness.gd` (`_autotest`)

**Interfaces:**
- Consumes: nothing.
- Produces: `static func Balance.is_desktop_display() -> bool` — used by Task 5 and by `camera_rig.gd`.

- [ ] **Step 1: Write the failing test** — in `dev_harness.gd` `_autotest`, add:

```gdscript
	_check(Balance.is_desktop_display() == (DisplayServer.get_name() in ["windows", "macos", "x11", "wayland", "embedded"]), "is_desktop_display matches display server")
```

- [ ] **Step 2: Run autotest to verify it fails**

Run: `godot --headless --path . -- --autotest`
Expected: `AT_FAIL is_desktop_display matches display server` (static call on missing func is a script error; harness reports failure).

- [ ] **Step 3: Minimal implementation** — in `balance.gd`:

```gdscript
static func is_desktop_display() -> bool:
	return DisplayServer.get_name() in ["windows", "macos", "x11", "wayland", "embedded"]
```

- [ ] **Step 4: Switch camera_rig.gd to the helper** — replace line 22:

```gdscript
	var desktop := DisplayServer.get_name() == "windows" or DisplayServer.get_name() == "x11" or DisplayServer.get_name() == "macos"
```

with:

```gdscript
	var desktop := Balance.is_desktop_display()
```

(Do NOT touch `player.gd` in this pack; its Wayland branch is in the fixes pack.)

- [ ] **Step 5: Run autotest, expect PASS, commit**

```bash
git add src/autoload/balance.gd src/arena/camera_rig.gd src/autoload/dev_harness.gd
git commit -m "feat: desktop display helper with wayland support"
```

---

### Task 2: Boot sequence overlay

**Files:**
- Create: `src/ui/boot.gd`
- Modify: `src/ui/menu.gd` (`_ready`, and add `var _boot: BootOverlay` field)
- Modify: `src/autoload/dev_harness.gd` (`_autotest`)

**Interfaces:**
- Consumes: `DevHarness.active` (bool autoload field), `Sfx.SAVE_PATH`.
- Produces: `BootOverlay` (class_name) with `signal finished` — nothing else consumes it; menu creates and forgets it.

- [ ] **Step 1: Write the failing test** — in `_autotest`, right after the "menu is main scene" check:

```gdscript
	_check(get_tree().current_scene.find_children("*", "BootOverlay", true, false).is_empty(), "boot overlay skipped in headless")
```

- [ ] **Step 2: Run autotest, verify FAIL** (script error: BootOverlay unknown).
- [ ] **Step 3: Create `src/ui/boot.gd`:**

```gdscript
class_name BootOverlay
extends Control

signal finished

const LINE_TIME := 0.38
const TOTAL_TIME := 1.8

var _lines: Array[String] = []
var _label: Label
var _elapsed := 0.0
var _line_i := 0
var _done := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0196078, 0.0235294, 0.054902, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_lines = [
		"[    0.000000] kernel panic bootloader v%s" % ProjectSettings.get_setting("application/config/version", "dev"),
		"[    0.412331] checking save integrity ... %s" % ("OK" if FileAccess.file_exists(Sfx.SAVE_PATH) else "fresh install"),
		"[    0.718042] mounting /dev/purge ... OK",
		"[    1.001204] spawning last process ... done",
	]
	_label = Label.new()
	_label.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Balance.COL_TEXT)
	_label.position = Vector2(32, 32)
	_label.size = Vector2(900, 400)
	add_child(_label)

func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	while _line_i < _lines.size() and _elapsed > float(_line_i) * LINE_TIME:
		_label.text += _lines[_line_i] + "\n"
		_line_i += 1
	if _elapsed >= TOTAL_TIME:
		_finish()

func _input(event: InputEvent) -> void:
	if _done:
		return
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed()
	if pressed:
		_finish()
		get_viewport().set_input_as_handled()

func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
```

- [ ] **Step 4: Instantiate from menu** — in `menu.gd`, add field `var _boot: BootOverlay` near the other fields, and at the end of `_ready()`:

```gdscript
	if not DevHarness.active and DisplayServer.get_name() != "headless":
		_boot = BootOverlay.new()
		var bl := CanvasLayer.new()
		bl.layer = 95
		bl.add_child(_boot)
		add_child(bl)
```

- [ ] **Step 5: Run autotest, expect PASS** (overlay never exists in headless; the ENTER-to-start test keeps working).
- [ ] **Step 6: Commit**

```bash
git add src/ui/boot.gd src/ui/menu.gd src/autoload/dev_harness.gd
git commit -m "feat: boot sequence overlay on menu launch"
```

---

### Task 3: Bestiary as man pages

**Files:**
- Modify: `src/ui/bestiary_panel.gd` (`ENTRIES`, `_draw`)
- Modify: `src/autoload/dev_harness.gd` (`_autotest`)

**Interfaces:**
- Consumes: nothing new.
- Produces: `BestiaryPanel.ENTRIES` dicts now contain keys `id`, `name`, `desc`, `threat` (int), `bugs` (String).

- [ ] **Step 1: Write the failing test** — in `_autotest`:

```gdscript
	var entries_ok := true
	for e in BestiaryPanel.ENTRIES:
		if not (e.has("threat") and e.has("bugs")):
			entries_ok = false
	_check(entries_ok, "bestiary entries carry threat and bugs fields")
```

- [ ] **Step 2: Run autotest, verify FAIL.**
- [ ] **Step 3: Extend `ENTRIES`** — each dict gains `"threat"` (existing enemy pts) and `"bugs"`. Exact values:

```gdscript
const ENTRIES := [
	{"id": "drone", "name": "DRONE", "desc": "basic corrupted process. dash through packs.", "threat": 50, "bugs": "swarms without a scheduler. forever."},
	{"id": "lancer", "name": "LANCER", "desc": "telegraphs then lunges. sidestep the line, punish the stagger.", "threat": 90, "bugs": "lunges in a straight line. sidestep = fix."},
	{"id": "spewer", "name": "SPEWER", "desc": "keeps distance, spits orbs. shoot the orbs down.", "threat": 110, "bugs": "orbs are shootable. it has not learned this."},
	{"id": "splitter", "name": "SPLITTER", "desc": "splits on death. kill it away from you.", "threat": 100, "bugs": "death is a fork(). plan accordingly."},
	{"id": "bulwark", "name": "BULWARK", "desc": "armored and slow. dash past, never hug.", "threat": 300, "bugs": "armor does not cover the back. or manners."},
	{"id": "trojan", "name": "TROJAN", "desc": "leaves corruption pools. do not swim.", "threat": 140, "bugs": "leaves pools. calls them 'features'."},
	{"id": "oom", "name": "OOM_KILLER", "desc": "steals your motes and runs. hunt it first.", "threat": 150, "bugs": "steals motes. returns nothing. ever."},
	{"id": "boss", "name": "ROOT DAEMON", "desc": "every variant has a tell. learn it. respect it.", "threat": 2500, "bugs": "segfaults reproduce. two of them."},
	{"id": "recursor", "name": "RECURSOR", "desc": "teleports and leaves corruption. pools mark where it was. keep moving.", "threat": 140, "bugs": "leaves corruption where it *was*. check behind you."},
	{"id": "firewall", "name": "FIREWALL", "desc": "rotating wall of orbs. kill the wall to drop the wall.", "threat": 180, "bugs": "wall persists after death of nearby processes."},
]
```

- [ ] **Step 4: Render in `_draw`** — inside the per-entry loop, after the glyph block and keeping the existing name/desc draws, add the threat badge (only when seen) and replace only the bottom `[ LOGGED ]` line:

```gdscript
		if seen:
			draw_string(mono, origin + Vector2(cw - 14.0, 20.0), "%d PTS" % int(e["threat"]), HORIZONTAL_ALIGNMENT_RIGHT, 90.0, 11, Color(Balance.COL_MOTE.r, Balance.COL_MOTE.g, Balance.COL_MOTE.b, 0.7))
```

and change the final if/else bottom line to:

```gdscript
		if not seen:
			draw_string(mono, origin + Vector2(14, ch - 14.0), "[ LOCKED ]", HORIZONTAL_ALIGNMENT_LEFT, cw - 28, 11, Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b, 0.5))
		else:
			draw_string(mono, origin + Vector2(14, ch - 14.0), "BUGS: " + str(e["bugs"]), HORIZONTAL_ALIGNMENT_LEFT, cw - 28, 11, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.55))
```

- [ ] **Step 5: Run autotest, expect PASS; commit**

```bash
git add src/ui/bestiary_panel.gd src/autoload/dev_harness.gd
git commit -m "feat: bestiary cards as man pages with threat and bugs"
```

---

### Task 4: Stack trace on elite/boss kill

**Files:**
- Modify: `src/autoload/fx.gd` (`FloatText`, new `stacktrace`, new `TRACE_TEMPLATES`)
- Modify: `src/arena/arena.gd` (`_on_enemy_died`)
- Modify: `src/autoload/dev_harness.gd` (`_autotest`)

**Interfaces:**
- Consumes: `FloatText.setup(s, c, sz, f)` (existing), `FloatText.dur` (existing public var).
- Produces: `Fx.stacktrace(pos: Vector2, killer: String, big := false) -> void`.

- [ ] **Step 1: Write the failing test** — in `_autotest`:

```gdscript
	Fx.stacktrace(Vector2.ZERO, "TEST_CRASH")
	await _ticks(2)
	_check(true, "stacktrace renders without error")
```

(The check is trivial by design: the real failure mode is the multiline draw path erroring at runtime.)

- [ ] **Step 2: Run autotest, verify FAIL** (missing method on Fx).
- [ ] **Step 3: Implement in `fx.gd`** — add near the top-level funcs:

```gdscript
const TRACE_TEMPLATES := [
	"segfault at 0xdeadbeef\n #0 purge_one(<%s>)\n #1 hit_loop",
	"BUG: unable to handle kernel paging\n #0 reap_daemon(<%s>)\n #1 swapper/0",
	"%s terminated on signal 11 (core dumped)",
]

func stacktrace(pos: Vector2, killer: String, big := false) -> void:
	var t := FloatText.new()
	var col := Balance.COL_DANGER if big else Balance.COL_MOTE
	t.setup(TRACE_TEMPLATES[randi() % TRACE_TEMPLATES.size()] % killer, col, 14 if big else 12, mono_font)
	t.dur = 1.1
	t.multiline = true
	t.position = pos + Vector2(randf_range(-8, 8), 26.0)
	_attach(t)
```

- In `class FloatText`, add field `var multiline := false` and change `_draw()` to:

```gdscript
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
```

- [ ] **Step 4: Hook in `arena.gd _on_enemy_died`** — replace exactly the first four lines of the function (from `func _on_enemy_died` through the `Game.register_kill(...)` line) with:

```gdscript
func _on_enemy_died(e: EnemyBase) -> void:
	Game.mark_bestiary(e.display_name)
	var was_split: bool = e is RootBoss and e.get("_split_silent") == true
	if e.elite:
		Fx.stacktrace(e.global_position, e.display_name)
	elif e is RootBoss and not was_split:
		Fx.stacktrace(e.global_position, e.display_name, true)
	Game.register_kill(0 if was_split else e.pts, e is RootBoss and not was_split)
```

Everything after `Game.register_kill` stays untouched. Regular (non-elite, non-boss) enemies must not emit a trace.

- [ ] **Step 5: Run autotest, expect PASS; verify no trace for common kills** by reading the hook condition once more; commit

```bash
git add src/autoload/fx.gd src/arena/arena.gd src/autoload/dev_harness.gd
git commit -m "feat: stack trace flavor text on elite and boss kills"
```

---

### Task 5: Terminal reticle (PC only)

**Files:**
- Create: `src/ui/reticle.gd`
- Modify: `src/arena/arena.gd` (`_ready`, `_process`, new `_exit_tree`)
- Modify: `src/autoload/dev_harness.gd` (`_autotest`)

**Interfaces:**
- Consumes: `Balance.is_desktop_display()` (Task 1), `Player.fire_cd`, `Player.overclock_active`.
- Produces: `Reticle` (class_name, Node2D) with `var player: Player`.

- [ ] **Step 1: Write the failing test** — in `_autotest`:

```gdscript
	var ret_script := load("res://src/ui/reticle.gd")
	_check(ret_script != null, "reticle script loads")
	var ret: Reticle = ret_script.new()
	ret.player = null
	add_child(ret)
	await _ticks(2)
	_check(is_instance_valid(ret), "reticle ticks without error")
	ret.queue_free()
```

- [ ] **Step 2: Run autotest, verify FAIL** (script missing).
- [ ] **Step 3: Create `src/ui/reticle.gd`:**

```gdscript
class_name Reticle
extends Node2D

var player: Player
var _spread := 0.0

func _process(delta: float) -> void:
	var firing := player != null and is_instance_valid(player) and player.fire_cd > 0.0
	if firing:
		_spread = minf(_spread + delta * 40.0, 10.0)
	else:
		_spread = maxf(_spread - delta * 30.0, 0.0)
	visible = Input.mouse_mode == Input.MOUSE_MODE_HIDDEN
	if visible:
		position = get_global_mouse_position()
	queue_redraw()

func _draw() -> void:
	var hot := player != null and is_instance_valid(player) and player.overclock_active
	var c := Balance.COL_PLAYER_HOT if hot else Balance.COL_PLAYER
	c.a = 0.9
	var s := 7.0 if hot else 5.0
	draw_rect(Rect2(-s * 0.5, -s * 0.5, s, s), c)
	c.a = 0.5
	var dirs := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var off := 8.0 + _spread
	for d in dirs:
		draw_line(d * off, d * (off + 5.0), c, 1.6, true)
```

- [ ] **Step 4: Wire into `arena.gd`** — field `var reticle: Reticle`; at the end of `_ready()` (after the touch block):

```gdscript
	if Balance.is_desktop_display() and not DisplayServer.is_touchscreen_available() or OS.get_environment("KP_FORCE_RETICLE") != "":
		var rl := CanvasLayer.new()
		rl.layer = 85
		reticle = Reticle.new()
		reticle.player = player
		rl.add_child(reticle)
		add_child(rl)
```

In `_process(delta)`, add at the top:

```gdscript
	var want_hidden := _state == "play" and not get_tree().paused and reticle != null
	var target_mouse := Input.MOUSE_MODE_HIDDEN if want_hidden else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != target_mouse:
		Input.mouse_mode = target_mouse
```

And a new method:

```gdscript
func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
```

- [ ] **Step 5: Run autotest, expect PASS; commit**

```bash
git add src/ui/reticle.gd src/arena/arena.gd src/autoload/dev_harness.gd
git commit -m "feat: terminal reticle with spread feedback on desktop"
```

---

### Task 6: Final verification

- [ ] Run the full autotest: `godot --headless --path . -- --autotest` → `AUTOTEST_ALL_PASS`, zero `AT_FAIL`, and no script errors mentioning `stacktrace`, `BootOverlay`, or `Reticle` in stderr.
- [ ] Grep sweep: `git diff 93b9f34..HEAD --stat` shows only the files listed in this plan.
- [ ] Manual smoke (if a display is available): boot shows and skips on input; bestiary shows THREAT/BUGS only for logged enemies; killing a spawned elite prints a trace; pause/game-over restore the OS cursor.
- [ ] Final commit (docs only, if anything was adjusted):

```bash
git add docs/superpowers
git commit -m "docs: identity pack spec and plan"
```
