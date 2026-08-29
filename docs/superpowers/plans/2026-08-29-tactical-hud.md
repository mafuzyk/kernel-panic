# Tactical HUD Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the combat HUD to closely match the approved Tactical Kernel mock while creating reusable responsive drawing primitives for later UI screens.

**Architecture:** Add one stateless `TacticalUI` helper containing semantic tokens, responsive metrics, and angular geometry. Keep gameplay state collection in `Hud`; split its rendering into framed regions whose rectangles are exposed for deterministic harness tests. Reuse the existing `Game.event_log`, boss-fragment state, fonts, and input behavior without changing gameplay.

**Tech Stack:** Godot 4.7.2, GDScript, `CanvasItem` drawing APIs, existing `DevHarness` autotests.

**Spec:** `docs/superpowers/specs/2026-08-29-ui-overhaul-design.md`

## Global Constraints

- Match the approved 1366×768 HUD reference as closely as possible.
- Preserve gameplay behavior, touch controls, Weekly determinism, and all existing HUD APIs.
- Cosmetic animation must never consume `Game.rng`.
- Stateful UI remains code-drawn and uses Orbitron plus Share Tech Mono.
- Layouts must fit 1366×768, 720×720, 540×720, and 432×720 without clipping.
- The event log shows at most four current-run entries and collapses before essential combat information.
- Generated raster assets are accepted only after same-size fullscreen, narrow-window, and mobile comparison; this HUD block requires none initially.
- After every task run `godot --headless --path . -- --autotest` and require `AUTOTEST_ALL_PASS` with zero `AT_FAIL`.

---

### Task 1: Tactical UI geometry and responsive metrics

**Files:**
- Create: `src/ui/tactical_ui.gd`
- Modify: `src/autoload/dev_harness.gd`

**Interfaces:**
- Produces: `TacticalUI.layout(viewport: Vector2) -> Dictionary`
- Produces: `TacticalUI.angular_points(rect: Rect2, cut: float = 12.0) -> PackedVector2Array`
- Produces: `TacticalUI.segment_rects(rect: Rect2, count: int, gap: float = 2.0) -> Array[Rect2]`
- Produces: semantic constants `BG`, `PANEL`, `CYAN`, `TEXT`, `MUTED`, `MAGENTA`, `LIME`, and `AMBER`

- [ ] **Step 1: Add failing geometry checks to `_task9_test`**

Insert after `print("AT_STEP task9")`:

```gdscript
	var tactical_script = load("res://src/ui/tactical_ui.gd")
	_check(tactical_script != null, "tactical UI helper loads")
	if tactical_script != null:
		var full: Dictionary = tactical_script.layout(Vector2(1366, 768))
		var narrow: Dictionary = tactical_script.layout(Vector2(432, 720))
		_check(not bool(full["compact"]) and bool(narrow["compact"]), "tactical layout selects compact breakpoint")
		for key in ["integrity", "encounter", "score", "dash", "patches", "boss"]:
			var full_rect: Rect2 = full[key]
			var narrow_rect: Rect2 = narrow[key]
			_check(Rect2(Vector2.ZERO, Vector2(1366, 768)).encloses(full_rect), "full tactical region fits: %s" % key)
			_check(Rect2(Vector2.ZERO, Vector2(432, 720)).encloses(narrow_rect), "compact tactical region fits: %s" % key)
		var angular: PackedVector2Array = tactical_script.angular_points(Rect2(10, 20, 100, 50), 10.0)
		_check(angular.size() == 8 and angular[0] == Vector2(20, 20), "angular frame returns stable clipped corners")
		var segments: Array[Rect2] = tactical_script.segment_rects(Rect2(0, 0, 100, 10), 5, 2.0)
		_check(segments.size() == 5 and segments[4].end.x <= 100.01, "segmented meter geometry stays inside bounds")
```

- [ ] **Step 2: Run the autotest and observe the expected failure**

Run: `godot --headless --path . -- --autotest`

Expected: `AT_FAIL tactical UI helper loads` because `src/ui/tactical_ui.gd` does not exist.

- [ ] **Step 3: Implement `TacticalUI`**

Create `src/ui/tactical_ui.gd`:

```gdscript
class_name TacticalUI
extends RefCounted

const BG := Color("050914")
const PANEL := Color(0.015, 0.035, 0.07, 0.90)
const CYAN := Color("28e7ff")
const TEXT := Color("d9efff")
const MUTED := Color(0.68, 0.78, 0.88, 0.62)
const MAGENTA := Color("ff386f")
const LIME := Color("9dff72")
const AMBER := Color("ffd24f")

static func angular_points(rect: Rect2, cut: float = 12.0) -> PackedVector2Array:
	var c := clampf(cut, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	return PackedVector2Array([
		rect.position + Vector2(c, 0), Vector2(rect.end.x - c, rect.position.y),
		Vector2(rect.end.x, rect.position.y + c), Vector2(rect.end.x, rect.end.y - c),
		Vector2(rect.end.x - c, rect.end.y), Vector2(rect.position.x + c, rect.end.y),
		Vector2(rect.position.x, rect.end.y - c), Vector2(rect.position.x, rect.position.y + c),
	])

static func segment_rects(rect: Rect2, count: int, gap: float = 2.0) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if count <= 0:
		return result
	var width := maxf((rect.size.x - gap * float(count - 1)) / float(count), 0.0)
	for index in count:
		result.append(Rect2(rect.position + Vector2(float(index) * (width + gap), 0), Vector2(width, rect.size.y)))
	return result

static func layout(viewport: Vector2) -> Dictionary:
	var compact := viewport.x < 760.0
	var side := clampf(viewport.x * 0.012, 8.0, 16.0)
	var top := clampf(viewport.y * 0.025, 12.0, 20.0)
	var bottom := viewport.y - clampf(viewport.y * 0.025, 12.0, 20.0)
	var corner_w := minf(245.0, viewport.x * (0.46 if compact else 0.19))
	var center_w := minf(460.0, viewport.x - side * 2.0)
	var encounter_h := 76.0 if not compact else 58.0
	return {
		"compact": compact,
		"integrity": Rect2(side, top, corner_w, 112.0 if not compact else 92.0),
		"encounter": Rect2((viewport.x - center_w) * 0.5, top, center_w, encounter_h),
		"score": Rect2(viewport.x - side - corner_w, top, corner_w, 120.0 if not compact else 92.0),
		"dash": Rect2(side, bottom - 76.0, minf(225.0, viewport.x * 0.45), 76.0),
		"patches": Rect2(viewport.x - side - minf(330.0, viewport.x * 0.48), bottom - 76.0, minf(330.0, viewport.x * 0.48), 76.0),
		"boss": Rect2((viewport.x - center_w) * 0.5, bottom - 88.0, center_w, 64.0),
	}
```

- [ ] **Step 4: Run the autotest and require a pass**

Run: `godot --headless --path . -- --autotest`

Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`.

- [ ] **Step 5: Commit**

```bash
git add src/ui/tactical_ui.gd src/autoload/dev_harness.gd
git commit -m "feat: add tactical UI layout foundation"
```

### Task 2: Framed HUD regions and event log

**Files:**
- Modify: `src/ui/hud.gd`
- Modify: `src/autoload/dev_harness.gd`

**Interfaces:**
- Consumes: `TacticalUI.layout`, `TacticalUI.angular_points`
- Produces: `Hud.layout_snapshot(viewport: Vector2 = size) -> Dictionary`
- Produces: `Hud.visible_event_lines(limit: int = 4) -> Array[String]`
- Produces: `Hud.event_log_visible(viewport: Vector2 = size) -> bool`

- [ ] **Step 1: Add failing HUD API checks to `_task9_test`**

```gdscript
	var hud_layout_ready := hud.has_method("layout_snapshot") and hud.has_method("visible_event_lines") and hud.has_method("event_log_visible")
	_check(hud_layout_ready, "HUD exposes tactical layout and event log APIs")
	if hud_layout_ready:
		Game.event_log = [
			{"time": 1.0, "text": "ONE"}, {"time": 2.0, "text": "TWO"},
			{"time": 3.0, "text": "THREE"}, {"time": 4.0, "text": "FOUR"},
			{"time": 5.0, "text": "FIVE"},
		]
		var lines: Array[String] = hud.visible_event_lines()
		_check(lines.size() == 4 and lines[0].contains("TWO") and lines[3].contains("FIVE"), "HUD event log keeps the newest four entries")
		_check(hud.event_log_visible(Vector2(1366, 768)), "event log is visible in full layout")
		_check(not hud.event_log_visible(Vector2(540, 720)), "event log collapses in compact layout")
```

- [ ] **Step 2: Run the autotest and observe failure**

Run: `godot --headless --path . -- --autotest`

Expected: `AT_FAIL HUD exposes tactical layout and event log APIs`.

- [ ] **Step 3: Implement layout APIs and framed drawing**

In `hud.gd`, add helpers that call `TacticalUI.layout`, format the last four `Game.event_log` entries as `[%05.1f] TEXT`, and return false for the event log when `layout["compact"]` is true. Add `_draw_angular_panel(rect, color, fill_alpha)` using `draw_colored_polygon` plus a closed polyline. Draw the integrity, encounter, score, dash, patches, and boss frames before their contents. The encounter frame displays `CYCLE %02d` and the current boss title or `PROCESS PURGE`; the score frame owns score, combo, and event log.

Use these exact signatures:

```gdscript
func layout_snapshot(viewport: Vector2 = size) -> Dictionary:
	return TacticalUI.layout(viewport)

func event_log_visible(viewport: Vector2 = size) -> bool:
	return not bool(layout_snapshot(viewport)["compact"])

func visible_event_lines(limit: int = 4) -> Array[String]:
	var result: Array[String] = []
	var start := maxi(Game.event_log.size() - maxi(limit, 1), 0)
	for index in range(start, Game.event_log.size()):
		var entry: Dictionary = Game.event_log[index]
		result.append("[%05.1f] %s" % [float(entry.get("time", 0.0)), str(entry.get("text", ""))])
	return result
```

- [ ] **Step 4: Run the autotest and require a pass**

Run: `godot --headless --path . -- --autotest`

Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`.

- [ ] **Step 5: Commit**

```bash
git add src/ui/hud.gd src/autoload/dev_harness.gd
git commit -m "feat: frame combat HUD and add event log"
```

### Task 3: Tactical vitals, core meter, dash, and patch dock

**Files:**
- Modify: `src/ui/hud.gd`
- Modify: `src/autoload/dev_harness.gd`

**Interfaces:**
- Consumes: `Hud.layout_snapshot`, `TacticalUI.segment_rects`
- Preserves: `patch_chip_rect`, `patch_tooltip_visible`, `patch_tooltip_snapshot`
- Produces: `Hud.patch_dock_rects(viewport: Vector2 = size) -> Dictionary`

- [ ] **Step 1: Add failing layout assertions**

```gdscript
	var dock_ready := hud.has_method("patch_dock_rects")
	_check(dock_ready, "HUD exposes responsive patch dock geometry")
	if dock_ready:
		for viewport in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			var dock: Dictionary = hud.patch_dock_rects(viewport)
			for patch_id in dock:
				_check(Rect2(Vector2.ZERO, viewport).encloses(dock[patch_id]), "patch dock chip fits %dx%d" % [int(viewport.x), int(viewport.y)])
```

- [ ] **Step 2: Run the autotest and observe failure**

Run: `godot --headless --path . -- --autotest`

Expected: `AT_FAIL HUD exposes responsive patch dock geometry`.

- [ ] **Step 3: Rebuild the four combat status groups**

Move HP diamonds and the segmented integrity meter into the upper-left frame. Label ROOTLET's meter `SHIELD` and KERNEL/DAEMON's meter `OVERCLOCK`. Render dash as a lower-left status module with charge count and cooldown fill. Move patch chips into the lower-right frame, right-align them, preserve pointer hover and touch-hold hit rectangles, and collapse to compact code-only chips at widths below 760.

Implement `patch_dock_rects` by computing chip rectangles from `TacticalUI.layout(viewport)["patches"]`, right to left, using 58×42 full chips and 36×30 compact chips. `_update_patch_chip_rects()` must assign `_patch_chip_rects = patch_dock_rects(size)` so input and drawing use identical geometry.

- [ ] **Step 4: Run the autotest and require a pass**

Run: `godot --headless --path . -- --autotest`

Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`.

- [ ] **Step 5: Commit**

```bash
git add src/ui/hud.gd src/autoload/dev_harness.gd
git commit -m "feat: rebuild tactical combat status modules"
```

### Task 4: Boss encounter frame and split ROOT bars

**Files:**
- Modify: `src/ui/hud.gd`
- Modify: `src/autoload/dev_harness.gd`

**Interfaces:**
- Consumes: existing `set_boss_fragments(minis: Array)` and `clear_boss_encounter()`
- Produces: `Hud.boss_bar_rects(viewport: Vector2 = size, split: bool = _boss_split) -> Array[Rect2]`

- [ ] **Step 1: Add failing boss geometry checks**

```gdscript
	var boss_geometry_ready := hud.has_method("boss_bar_rects")
	_check(boss_geometry_ready, "HUD exposes boss bar geometry")
	if boss_geometry_ready:
		for viewport in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			var normal_rows: Array[Rect2] = hud.boss_bar_rects(viewport, false)
			var split_rows: Array[Rect2] = hud.boss_bar_rects(viewport, true)
			_check(normal_rows.size() == 1 and split_rows.size() == 2, "boss geometry exposes one or two combined rows")
			for row in split_rows:
				_check(Rect2(Vector2.ZERO, viewport).encloses(row), "split boss row fits %dx%d" % [int(viewport.x), int(viewport.y)])
```

- [ ] **Step 2: Run the autotest and observe failure**

Run: `godot --headless --path . -- --autotest`

Expected: `AT_FAIL HUD exposes boss bar geometry`.

- [ ] **Step 3: Implement the encounter treatment**

Use the bottom-center boss region from `TacticalUI.layout`. Draw an angular magenta container, boss title above it, and twenty code-drawn health segments. Normal bosses use one row; split ROOT uses two equal rows in the same container labeled `MINI-A` and `MINI-B`. Missing or dead fragments leave an empty row rather than shifting the surviving fragment. Keep the arena center clear and keep all rows above the safe bottom margin.

- [ ] **Step 4: Run the autotest and require a pass**

Run: `godot --headless --path . -- --autotest`

Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`.

- [ ] **Step 5: Commit**

```bash
git add src/ui/hud.gd src/autoload/dev_harness.gd
git commit -m "feat: redesign tactical boss encounter HUD"
```

### Task 5: Visual comparison and responsive correction pass

**Files:**
- Modify: `src/ui/hud.gd`
- Modify: `src/ui/tactical_ui.gd`
- Modify: `docs/superpowers/specs/2026-08-29-ui-overhaul-design.md`

**Interfaces:**
- Consumes: all prior HUD APIs
- Produces: visually verified HUD at full, narrow, and mobile-shaped viewports

- [ ] **Step 1: Run the complete autotest before visual capture**

Run: `godot --headless --path . -- --autotest`

Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`.

- [ ] **Step 2: Capture representative gameplay states**

Create the output directory and capture normal plus ROOT states at the three target sizes; captures stay outside git:

```bash
mkdir -p /tmp/kernel-panic-ui-overhaul/data /tmp/kernel-panic-ui-overhaul/config
env XDG_DATA_HOME=/tmp/kernel-panic-ui-overhaul/data XDG_CONFIG_HOME=/tmp/kernel-panic-ui-overhaul/config KP_SHOT=game KP_SHOT_OUT=/tmp/kernel-panic-ui-overhaul/game-1366.png KP_SHOT_FRAMES=30 timeout 30s godot --path . --display-driver wayland --resolution 1366x768
env XDG_DATA_HOME=/tmp/kernel-panic-ui-overhaul/data XDG_CONFIG_HOME=/tmp/kernel-panic-ui-overhaul/config KP_SHOT=boss KP_SHOT_OUT=/tmp/kernel-panic-ui-overhaul/boss-1366.png KP_SHOT_FRAMES=30 timeout 30s godot --path . --display-driver wayland --resolution 1366x768
env XDG_DATA_HOME=/tmp/kernel-panic-ui-overhaul/data XDG_CONFIG_HOME=/tmp/kernel-panic-ui-overhaul/config KP_SHOT=boss KP_SHOT_OUT=/tmp/kernel-panic-ui-overhaul/boss-720.png KP_SHOT_FRAMES=30 timeout 30s godot --path . --display-driver wayland --resolution 720x720
env XDG_DATA_HOME=/tmp/kernel-panic-ui-overhaul/data XDG_CONFIG_HOME=/tmp/kernel-panic-ui-overhaul/config KP_SHOT=boss KP_SHOT_OUT=/tmp/kernel-panic-ui-overhaul/boss-432.png KP_SHOT_FRAMES=30 timeout 30s godot --path . --display-driver wayland --resolution 432x720
```

- [ ] **Step 3: Compare reference and implementation at the same size**

Use ImageMagick to resize the approved reference to each capture height and append it beside the implementation:

```bash
magick /home/mafu/.codex/generated_images/01a044e4-d316-7ef2-85d8-9aa85056ea3a/exec-10cafd61-702d-4c80-bb5e-20e90420d23c.png -resize 1366x768! /tmp/kernel-panic-ui-overhaul/reference-1366.png
magick /tmp/kernel-panic-ui-overhaul/reference-1366.png /tmp/kernel-panic-ui-overhaul/boss-1366.png +append /tmp/kernel-panic-ui-overhaul/compare-1366.png
```

Open `compare-1366.png` with the image viewer tool and inspect hierarchy, frame proportions, corner cuts, font sizes, baseline alignment, arena obstruction, contrast, and cropping. Inspect the 720×720 and 432×720 captures separately for collisions. Record only concrete mismatches in the spec under a `Visual correction pass` subsection.

- [ ] **Step 4: Correct every recorded mismatch**

Adjust only `tactical_ui.gd` metrics and HUD drawing/layout code. Remove the temporary mismatch subsection once every item is resolved. Do not compensate for layout defects with raster overlays.

- [ ] **Step 5: Recapture and verify**

Repeat the same-size side-by-side comparison. Require readable text, no clipped region, no overlap with boss bars or touch controls, and a clearly recognizable match to the approved mock.

- [ ] **Step 6: Run final verification**

Run: `godot --headless --path . -- --autotest`

Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`.

- [ ] **Step 7: Commit**

```bash
git add src/ui/hud.gd src/ui/tactical_ui.gd docs/superpowers/specs/2026-08-29-ui-overhaul-design.md
git commit -m "fix: align tactical HUD with approved visual target"
```
