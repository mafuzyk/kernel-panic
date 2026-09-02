#!/usr/bin/env bash
## Accumulated validation entry point (R01-R08/R18/B1-B6 and vNext slices).
##
## Runs the full DevHarness autotest, the accumulated headless gameplay probes,
## and the input-dispatch probe in headless and Xvfb desktop-debug modes.
## Failures (AT_FAIL / PROBE_FAIL) and engine/script ERROR lines are reported in
## SEPARATE sections. Runtime/script errors gate the exit code; known teardown
## resource/RID diagnostics remain visible but non-gating until their ownership
## is isolated. Every invocation has a bounded timeout and a kill-after grace
## period; this is a containment aid, not a complete supervisor for arbitrary
## descendants spawned by a tool.
##
## Usage: tools/validate_input_dispatch.sh
## Logs land in .godot/codex-review-lote-1/ (gitignored runtime artifacts).

set -u
cd "$(dirname "$0")/.."

LOG_DIR="${KP_VALIDATION_LOGS:-.godot/codex-review-lote-1}"
XDG="$LOG_DIR/xdg"
VALIDATION_TIMEOUT_SECONDS="${KP_VALIDATION_TIMEOUT_SECONDS:-120}"
VALIDATION_KILL_GRACE_SECONDS="${KP_VALIDATION_KILL_GRACE_SECONDS:-5}"
if [[ "$LOG_DIR" != /* ]]; then
	LOG_DIR="$PWD/$LOG_DIR"
	XDG="$LOG_DIR/xdg"
fi
mkdir -p "$XDG"

overall=0

report_case() {
	# report_case NAME LOG CODE PASS_PATTERN FAIL_PATTERN [PATTERN:::LABEL...]
	# Required markers make empty/truncated runs fail even when the process
	# exits 0 with no counted failures.
	local name="$1" log="$2" code="$3" pass_pattern="$4" fail_pattern="$5"
	shift 5
	local passes fails
	passes=$(grep -c "$pass_pattern" "$log" || true)
	fails=$(grep -c "$fail_pattern" "$log" || true)
	echo "== $name: exit=$code passes=$passes fails=$fails"
	if [ "$fails" -gt 0 ]; then
		overall=1
		grep "$fail_pattern" "$log" | sed 's/^/   FAIL: /'
	fi
	if [ "$code" -ne 0 ]; then
		overall=1
		echo "   FAIL: non-zero exit code (inspect $log)"
	fi
	local spec pattern label
	for spec in "$@"; do
		pattern="${spec%%:::*}"
		label="${spec#*:::}"
		if ! grep -q "$pattern" "$log"; then
			overall=1
			echo "   FAIL: missing $label in $log (empty or truncated run)"
		fi
	done
}

report_errors() {
	local name="$1" log="$2"
	local runtime_errors teardown_errors
	runtime_errors=$(grep -E "^(SCRIPT )?ERROR" "$log" | grep -Ev '^ERROR: ([0-9]+ (RID allocations|resources still)|Texture with GL ID)' || true)
	teardown_errors=$(grep -E '^ERROR: ([0-9]+ (RID allocations|resources still)|Texture with GL ID)' "$log" || true)
	if [ -n "$runtime_errors" ]; then
		overall=1
		echo "== $name runtime ERRORs (gating):"
		printf '%s\n' "$runtime_errors" | sort -u | sed 's/^/   FAIL: /'
	else
		echo "== $name runtime ERRORs: 0"
	fi
	if [ -n "$teardown_errors" ]; then
		echo "== $name teardown diagnostics (reported, non-gating):"
		printf '%s\n' "$teardown_errors" | sort -u | sed 's/^/   /'
	else
		echo "== $name teardown diagnostics: 0"
	fi
}

run_headless_probe() {
	local slug="$1" name="$2" scene="$3"
	local log="$LOG_DIR/$slug.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" godot --audio-driver Dummy --headless --path . "$scene" > "$log" 2>&1
	report_case "$name" "$log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "$name" "$log"
	echo
}

run_headless_probe_with_env() {
	local env_name="$1" slug="$2" name="$3" scene="$4"
	local log="$LOG_DIR/$slug.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env "$env_name=1" XDG_DATA_HOME="$XDG" godot --audio-driver Dummy --headless --path . "$scene" > "$log" 2>&1
	report_case "$name" "$log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "$name" "$log"
	echo
}

echo "--- suite headless ---"
timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" godot --audio-driver Dummy --headless --path . -- --autotest > "$LOG_DIR/suite-headless.log" 2>&1
report_case "suite headless (--autotest)" "$LOG_DIR/suite-headless.log" "$?" "AT_PASS" "AT_FAIL" \
	'^AUTOTEST_ALL_PASS$:::AUTOTEST_ALL_PASS marker'
report_errors "suite headless" "$LOG_DIR/suite-headless.log"
echo

echo "--- input dispatch probe ---"
timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" godot --audio-driver Dummy --headless --path . res://tools/input_dispatch_probe.tscn > "$LOG_DIR/probe-headless.log" 2>&1
report_case "input probe headless" "$LOG_DIR/probe-headless.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
	'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
report_errors "input probe headless" "$LOG_DIR/probe-headless.log"
echo

echo "--- accumulated gameplay probes ---"
run_headless_probe "probe-r04-projectile" "R04 projectile probe" "res://tools/projectile_orphan_probe.tscn"
run_headless_probe "probe-r05-rootlet" "R05 rootlet probe" "res://tools/rootlet_shield_probe.tscn"
run_headless_probe "probe-r06-temple" "R06 temple boss probe" "res://tools/temple_god_boss_probe.tscn"
run_headless_probe "probe-r07-restart" "R07 story restart probe" "res://tools/story_restart_probe.tscn"
run_headless_probe "probe-r08-oom" "R08 OOM loot probe" "res://tools/oom_loot_probe.tscn"
run_headless_probe "probe-b1-menu-overlay" "B1 menu overlay input probe" "res://tools/menu_overlay_input_probe.tscn"
run_headless_probe "probe-b2-footer-actions" "B2 menu footer action probe" "res://tools/menu_footer_action_probe.tscn"
run_headless_probe "probe-b5-terminal-history" "B5 terminal history probe" "res://tools/terminal_history_probe.tscn"
run_headless_probe "probe-b6-menu-prompt" "B6 menu prompt probe" "res://tools/menu_prompt_probe.tscn"
run_headless_probe "probe-h1-hud-hierarchy" "H1 HUD banner hierarchy probe" "res://tools/hud_hierarchy_probe.tscn"
run_headless_probe "probe-h2-hud-legibility" "H2 HUD legibility probe" "res://tools/hud_legibility_probe.tscn"
run_headless_probe "probe-h3-hud-scale-matrix" "H3 HUD scale matrix probe" "res://tools/hud_scale_matrix_probe.tscn"
run_headless_probe "probe-h4-hud-state-signals" "H4 HUD state signal probe" "res://tools/hud_state_signal_probe.tscn"
run_headless_probe "probe-h5-hud-layout-collisions" "H5 HUD layout collision probe" "res://tools/hud_layout_collision_probe.tscn"
run_headless_probe "probe-h6-overlay-layers" "H6 overlay layer probe" "res://tools/overlay_layer_probe.tscn"
run_headless_probe "probe-h7-dead-widgets" "H7 dead widgets and affordances probe" "res://tools/hud_dead_widgets_probe.tscn"
run_headless_probe "probe-h8-legacy-hud-adaptive" "H8 legacy HUD physical-window reflow" "res://tools/legacy_hud_adaptive_probe.tscn"
run_headless_probe "probe-n1-state-panel-navigation" "N1 state-panel keyboard navigation probe" "res://tools/state_panel_navigation_probe.tscn"
run_headless_probe "probe-n2-overlay-back-layout" "N2 overlay back layout probe" "res://tools/overlay_back_layout_probe.tscn"
run_headless_probe "probe-n3-bestiary-scroll-visibility" "N3 Bestiary scroll visibility probe" "res://tools/bestiary_scroll_visibility_probe.tscn"
run_headless_probe "probe-n4-display-settings-surface" "N4 display settings surface probe" "res://tools/display_settings_surface_probe.tscn"
run_headless_probe "probe-r18-touch-multitouch" "R18 touch multitouch action probe" "res://tools/touch_multitouch_probe.tscn"
run_headless_probe "probe-vnext-primitives" "VNext code-drawn primitive contract" "res://tools/vnext_primitives_probe.tscn"
run_headless_probe "probe-vnext-entity-illustration" "VNext code-drawn entity illustration contract" "res://tools/vnext_entity_illustration_probe.tscn"
run_headless_probe "probe-e2-legacy-enemies" "E2 legacy enemy presentation contract" "res://tools/e2_legacy_enemy_probe.tscn"
run_headless_probe "probe-e3-program-identity" "E3 program identity presentation contract" "res://tools/e3_program_identity_probe.tscn"
run_headless_probe "probe-e4-zombie-process" "E4 ZOMBIE_PROCESS gameplay contract" "res://tools/e4_zombie_process_probe.tscn"
run_headless_probe "probe-e5-entity-quality" "E5 entity quality tier contract" "res://tools/e5_entity_quality_probe.tscn"
run_headless_probe "probe-g1-run-context" "G1 run context contract" "res://tools/g1_run_context_probe.tscn"
run_headless_probe "probe-g2-page-cache" "G2 Page Cache mechanic" "res://tools/g2_page_cache_probe.tscn"
run_headless_probe "probe-g2-ring0" "G2 Ring-0 double overclock" "res://tools/g2_ring0_probe.tscn"
run_headless_probe "probe-g2-display-settings" "G2 display settings contract" "res://tools/g2_display_settings_probe.tscn"
run_headless_probe "probe-g3-weekly-practice" "G3 Weekly and Practice contract" "res://tools/g3_weekly_practice_probe.tscn"
run_headless_probe "probe-g4-boss-desperation" "G4 boss desperation contract" "res://tools/g4_boss_desperation_probe.tscn"
run_headless_probe "probe-vnext-boot" "VNext reference-shell boot surface" "res://tools/vnext_boot_probe.tscn"
run_headless_probe "probe-vnext-selection" "VNext reference-shell program and story selection" "res://tools/vnext_selection_probe.tscn"
run_headless_probe "probe-vnext-bestiary" "VNext reference-shell bestiary surface" "res://tools/vnext_bestiary_probe.tscn"
run_headless_probe_with_env "KP_VNEXT_BOOT" "probe-vnext-menu-routes" "VNext menu route integration" "res://tools/vnext_menu_probe.tscn"
run_headless_probe "probe-vnext-patch-surface" "VNext patch decision surface" "res://tools/vnext_patch_probe.tscn"
run_headless_probe_with_env "KP_VNEXT_PATCH" "probe-vnext-patch-arena" "VNext patch Arena adapter" "res://tools/vnext_patch_arena_probe.tscn"
run_headless_probe_with_env "KP_VNEXT_HUD" "probe-vnext-combat-hud" "VNext combat HUD Arena adapter" "res://tools/vnext_combat_hud_probe.tscn"
run_headless_probe_with_env "KP_VNEXT_U4" "probe-vnext-state-surfaces" "VNext pause, terminal and game-over surfaces" "res://tools/vnext_state_surfaces_probe.tscn"
run_headless_probe_with_env "KP_VNEXT_SETTINGS" "probe-vnext-accessibility" "VNext settings and accessibility surface" "res://tools/vnext_accessibility_probe.tscn"
run_headless_probe_with_env "KP_VNEXT_U6" "probe-vnext-state-surface" "VNext shared state surface" "res://tools/vnext_state_surface_probe.tscn"
run_headless_probe "probe-macos-release-gate" "M5 macOS surface integration" "res://tools/macos_release_gate_probe.tscn"
run_headless_probe "probe-accessibility-profile" "A11/A14 accessibility effects and handed touch" "res://tools/accessibility_profile_probe.tscn"
run_headless_probe "probe-p1-layout-cache" "P1 layout cache and responsive relayout" "res://tools/layout_cache_probe.tscn"
run_headless_probe "probe-p3-tween-lifecycle" "P3 tween lifecycle" "res://tools/tween_lifecycle_probe.tscn"
run_headless_probe "probe-p4-boss-bar-identity" "P4 boss bar identity" "res://tools/boss_bar_identity_probe.tscn"
run_headless_probe "probe-performance-stress" "P1 deterministic performance stress profile" "res://tools/performance_stress_probe.tscn"

if command -v xvfb-run >/dev/null 2>&1; then
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/input_dispatch_probe.tscn > "$LOG_DIR/probe-xvfb.log" 2>&1
	report_case "input probe xvfb (desktop debug)" "$LOG_DIR/probe-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker' \
		'^PROBE_INFO debug_controls_enabled=true$:::debug_controls_enabled=true (desktop debug active)'
	report_errors "input probe xvfb" "$LOG_DIR/probe-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" xvfb-run -a -s '-screen 0 1920x1080x24' godot --audio-driver Dummy --path . res://tools/hud_scale_matrix_probe.tscn > "$LOG_DIR/probe-h3-hud-scale-matrix-xvfb.log" 2>&1
	report_case "H3 HUD scale matrix xvfb" "$LOG_DIR/probe-h3-hud-scale-matrix-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "H3 HUD scale matrix xvfb" "$LOG_DIR/probe-h3-hud-scale-matrix-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" xvfb-run -a -s '-screen 0 1920x1080x24' godot --audio-driver Dummy --path . res://tools/legacy_hud_adaptive_probe.tscn > "$LOG_DIR/probe-h8-legacy-hud-adaptive-xvfb.log" 2>&1
	report_case "H8 legacy HUD physical-window reflow xvfb" "$LOG_DIR/probe-h8-legacy-hud-adaptive-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "H8 legacy HUD physical-window reflow xvfb" "$LOG_DIR/probe-h8-legacy-hud-adaptive-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/g2_display_settings_probe.tscn > "$LOG_DIR/probe-g2-display-settings-xvfb.log" 2>&1
	report_case "G2 display settings xvfb" "$LOG_DIR/probe-g2-display-settings-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "G2 display settings xvfb" "$LOG_DIR/probe-g2-display-settings-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/display_settings_surface_probe.tscn > "$LOG_DIR/probe-n4-display-settings-xvfb.log" 2>&1
	report_case "N4 display settings surface xvfb" "$LOG_DIR/probe-n4-display-settings-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "N4 display settings surface xvfb" "$LOG_DIR/probe-n4-display-settings-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env KP_FORCE_TOUCH=1 XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/display_settings_surface_probe.tscn > "$LOG_DIR/probe-n4-display-settings-touch-xvfb.log" 2>&1
	report_case "N4 display settings touch scope xvfb" "$LOG_DIR/probe-n4-display-settings-touch-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "N4 display settings touch scope xvfb" "$LOG_DIR/probe-n4-display-settings-touch-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/g3_weekly_practice_probe.tscn > "$LOG_DIR/probe-g3-weekly-practice-xvfb.log" 2>&1
	report_case "G3 Weekly and Practice xvfb" "$LOG_DIR/probe-g3-weekly-practice-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "G3 Weekly and Practice xvfb" "$LOG_DIR/probe-g3-weekly-practice-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/g4_boss_desperation_probe.tscn > "$LOG_DIR/probe-g4-boss-desperation-xvfb.log" 2>&1
	report_case "G4 boss desperation xvfb" "$LOG_DIR/probe-g4-boss-desperation-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "G4 boss desperation xvfb" "$LOG_DIR/probe-g4-boss-desperation-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env KP_VNEXT_U4=1 XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/vnext_state_surfaces_probe.tscn > "$LOG_DIR/probe-vnext-state-surfaces-xvfb.log" 2>&1
	report_case "VNext state surfaces xvfb" "$LOG_DIR/probe-vnext-state-surfaces-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "VNext state surfaces xvfb" "$LOG_DIR/probe-vnext-state-surfaces-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env KP_VNEXT_BOOT=1 XDG_DATA_HOME="$XDG" xvfb-run -a -s '-screen 0 640x800x24' godot --audio-driver Dummy --path . res://tools/vnext_window_layout_probe.tscn > "$LOG_DIR/probe-vnext-window-layout-xvfb.log" 2>&1
	report_case "VNext physical window layout xvfb" "$LOG_DIR/probe-vnext-window-layout-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "VNext physical window layout xvfb" "$LOG_DIR/probe-vnext-window-layout-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env KP_VNEXT_U4=1 KP_VNEXT_PATCH=1 XDG_DATA_HOME="$XDG" xvfb-run -a -s '-screen 0 640x800x24' godot --audio-driver Dummy --path . res://tools/vnext_arena_window_layout_probe.tscn > "$LOG_DIR/probe-vnext-arena-window-layout-xvfb.log" 2>&1
	report_case "VNext Arena physical overlays xvfb" "$LOG_DIR/probe-vnext-arena-window-layout-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "VNext Arena physical overlays xvfb" "$LOG_DIR/probe-vnext-arena-window-layout-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env KP_VNEXT_SETTINGS=1 XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/vnext_accessibility_probe.tscn > "$LOG_DIR/probe-vnext-accessibility-xvfb.log" 2>&1
	report_case "VNext accessibility xvfb" "$LOG_DIR/probe-vnext-accessibility-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "VNext accessibility xvfb" "$LOG_DIR/probe-vnext-accessibility-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env KP_VNEXT_U6=1 XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/vnext_state_surface_probe.tscn > "$LOG_DIR/probe-vnext-state-surface-xvfb.log" 2>&1
	report_case "VNext shared state surface xvfb" "$LOG_DIR/probe-vnext-state-surface-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "VNext shared state surface xvfb" "$LOG_DIR/probe-vnext-state-surface-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/macos_release_gate_probe.tscn > "$LOG_DIR/probe-macos-release-gate-xvfb.log" 2>&1
	report_case "M5 macOS surface integration xvfb" "$LOG_DIR/probe-macos-release-gate-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "M5 macOS surface integration xvfb" "$LOG_DIR/probe-macos-release-gate-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/accessibility_profile_probe.tscn > "$LOG_DIR/probe-accessibility-profile-xvfb.log" 2>&1
	report_case "A11/A14 accessibility profile xvfb" "$LOG_DIR/probe-accessibility-profile-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "A11/A14 accessibility profile xvfb" "$LOG_DIR/probe-accessibility-profile-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/layout_cache_probe.tscn > "$LOG_DIR/probe-p1-layout-cache-xvfb.log" 2>&1
	report_case "P1 layout cache xvfb" "$LOG_DIR/probe-p1-layout-cache-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "P1 layout cache xvfb" "$LOG_DIR/probe-p1-layout-cache-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/tween_lifecycle_probe.tscn > "$LOG_DIR/probe-p3-tween-lifecycle-xvfb.log" 2>&1
	report_case "P3 tween lifecycle xvfb" "$LOG_DIR/probe-p3-tween-lifecycle-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "P3 tween lifecycle xvfb" "$LOG_DIR/probe-p3-tween-lifecycle-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/boss_bar_identity_probe.tscn > "$LOG_DIR/probe-p4-boss-bar-identity-xvfb.log" 2>&1
	report_case "P4 boss bar identity xvfb" "$LOG_DIR/probe-p4-boss-bar-identity-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "P4 boss bar identity xvfb" "$LOG_DIR/probe-p4-boss-bar-identity-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/performance_stress_probe.tscn > "$LOG_DIR/probe-performance-stress-xvfb.log" 2>&1
	report_case "P1 performance stress xvfb" "$LOG_DIR/probe-performance-stress-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "P1 performance stress xvfb" "$LOG_DIR/probe-performance-stress-xvfb.log"
else
	echo "== input probe xvfb: SKIP (xvfb-run not found; R03 desktop-debug coverage incomplete)"
	overall=1
fi
echo

if [ "$overall" -ne 0 ]; then
	echo "VALIDATION FAILED"
else
	echo "VALIDATION OK (teardown diagnostics above remain non-gating)"
fi
exit "$overall"
