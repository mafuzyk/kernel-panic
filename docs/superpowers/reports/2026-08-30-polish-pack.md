# Polish Pack Completion Report (2026-08-30)

> T13 finalized on 2026-08-30 on CachyOS (post Artix→CachyOS migration),
> branch `wip/polish-pack`. Captures re-taken on this machine; numbers below
> were measured here.

## Result
- Final autotest: **1415 AT_PASS / 0 AT_FAIL across 77 labels** (baseline was 1194 / 0 / 68). `AUTOTEST_ALL_PASS` in both the plain and `--verbose` runs.
- Every behavior task was test-first (red run recorded before its fix).
- Known flake (session handoff 2026-08-30): `rootlet has no overclock` failed 1x pre-migration under load; not reproduced in either T13 run. Stabilization still pending (low priority).

## Settings tabs (item 1)
- Five real sections, one visible at a time; ESC chain and difficulty placement unchanged; compact chips row below 760px (validated via the `apply_viewport` harness probe, `settings_chips` green).
- Notes: capture at real 432×720 portrait shows the sidebar (not the chips row) — **identical to the pre-migration preserved capture** (`media/captures/2026-08-30-polish-final/final_settings_432.png`), so this is pre-existing behavior, not a migration regression. Flagged for follow-up: reconcile the real-window portrait path with the probe-validated compact path.
- Observation: `RESET HIGH SCORE` lives in the settings footer row (`menu_settings_kit.gd:436`) and is visible in every tab; the spec mapping placed it in SAVE DATA. Author to decide: keep as always-visible footer action or move into the SAVE DATA section.

## Menu reflow (item 2)
- One layout dict; klog/title, controls/mode_info, and mode_info/footer disjoint at 1366x768, 1024x640, 760x720, 432x720 (verified in captures at 1366 and 432; no overlaps).
- AWARDS icon: code-drawn "awards" kind (verified: no `awards.png` raster in `assets/icons/generated/`; menu renders the code trophy via `_add_button_icon`); raster decision: Task 5/9 pipeline can generate it later if the author wants a raster — glyph kind shipped as the pack decision recorded in the spec.

## AWARDS chrome (item 3) / Bestiary glyph containment (item 4)
- Dim + framed chrome + card rows at both resolutions; unlocked rows lime check + label, locked rows muted + hint; scroll and ESC preserved (captured 1366 + 432).
- Glyph box fit with the 1.4 readability floor; PTS chip aligned (ROOT.exe detail glyph fully inside the rail at 1366x768).

## Icon optical pass (item 5)
- Padded rects + trimmed glow re-exports; author gate outcome: **PENDING** (Task 9 Step 5 left unticked by design — the old `/tmp/opencode/icons_trim_sbs.png` montage was lost in the OS migration; regenerate via the capture scripts below before deciding). RASTER_OPTOUT state: `{"music": [24]}` (39 rasters in `assets/icons/generated/`, none removed pending the gate).

## Story rail (item 6)
- Brackets, state rings (CLEARED/CURRENT/LOCKED), state labels; hit rects, scroll, and layout metrics frozen (capture shows the connected-node path on the UNIX act with all stages CLEARED).

## Teardown (item 7)
- Leak baseline N0: **~199 ObjectDB instances** (overnight review, pre-migration machine).
- Achieved N1: **198 (plain run) / 190 (verbose run)** measured 2026-08-30 on CachyOS. Caveat: the exact T11 N1 was recorded only in that session's /tmp (lost in migration) and never persisted before the park; the no-increase guard itself is green.
- Orphan-node guard constant: `LEAK_GUARD_MAX_ORPHANS := 40` (`dev_harness.gd:15`); measured `orphans=36 objects=1944` — `AT_PASS orphan node count stays under the recorded baseline (40)`.
- Owners freed: static raster caches (`Game._exit_tree`), Fx flash tween + layer validity, PatchCard/TacticalIcon cache teardown. RID lines at exit (TextServer 147, GodotArea2D 29, DummyTexture 14, Font 2) are engine-side noise within tolerance, unchanged between runs.

## Sprite trial (item 8)
- entity_sprite registry: **active on this branch only** with 20/21 entities (`assets/sprites/generated/`, 256px white-base); single switch in GlyphLib.draw_glyph; main keeps the glyph fallback (visual identical to pre-pack).
- Trial status: modulate tinting **confirmed working** in the game capture (bluescreen/spewer/lancer/drone sprites tint correctly, no artifacts seen at 1366). Author decision pending: keep active / activate per kind / revert to glyphs. Concept sheets preserved in `media/concepts/`.

## Captures (never committed)
- 2026-08-30 set (this machine): `/tmp/opencode/final_{menu,settings,awards}_{1366x768,432x720}.png`, `final_{bestiary,story,game}_1366x768.png` (9 files) + `game_f14.png` / `game_f120.png` (wave-announce fade artifact check) + `xvfb_test_menu.png`.
- Pre-migration acceptance set preserved in-repo: `media/captures/2026-08-30-polish-final/`.
- Capture methods (post-migration): (a) **Xvfb virtual display** — no visible window, exact resolution, immune to dwindle (`/tmp/opencode/capture_xvfb.sh <mode> <out> <WxH> [FLAGS]`); (b) windowed with Hyprland 0.56 Lua window-targeted pinning (`/tmp/opencode/capture.sh`, `hl.dsp.window.float/move/resize/pin` via `hyprctl eval`, window = `address:0x...`). Launches use `--audio-driver Dummy` (author request: no sound).

## Item 9
- Not implemented: the gameplay questionnaire is surfaced separately by the orchestrator (12 ideas, appendix of the spec; author answers pending).

## Mock comparison note (T13 Step 3)
- The approved mock files referenced by the plan (`~/.codex/generated_images/01a044e4-.../exec-*.png`) did not survive the OS migration — `~/.codex/` is empty on CachyOS. Visual gates were verified against the spec acceptance descriptions and the pre-migration preserved captures instead. If the author still has the mocks (cloud/backup), a re-comparison can be run on request.
