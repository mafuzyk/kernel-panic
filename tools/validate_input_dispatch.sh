#!/usr/bin/env bash
## Accumulated validation entry point (R01-R08/R18/B1-B5 and vNext slices).
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
run_headless_probe "probe-vnext-patch-surface" "VNext patch decision surface" "res://tools/vnext_patch_probe.tscn"
run_headless_probe_with_env "KP_VNEXT_PATCH" "probe-vnext-patch-arena" "VNext patch Arena adapter" "res://tools/vnext_patch_arena_probe.tscn"
run_headless_probe_with_env "KP_VNEXT_HUD" "probe-vnext-combat-hud" "VNext combat HUD Arena adapter" "res://tools/vnext_combat_hud_probe.tscn"
run_headless_probe_with_env "KP_VNEXT_U4" "probe-vnext-state-surfaces" "VNext pause, terminal and game-over surfaces" "res://tools/vnext_state_surfaces_probe.tscn"
run_headless_probe_with_env "KP_VNEXT_SETTINGS" "probe-vnext-accessibility" "VNext settings and accessibility surface" "res://tools/vnext_accessibility_probe.tscn"
run_headless_probe_with_env "KP_VNEXT_U6" "probe-vnext-state-surface" "VNext shared state surface" "res://tools/vnext_state_surface_probe.tscn"

if command -v xvfb-run >/dev/null 2>&1; then
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/input_dispatch_probe.tscn > "$LOG_DIR/probe-xvfb.log" 2>&1
	report_case "input probe xvfb (desktop debug)" "$LOG_DIR/probe-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker' \
		'^PROBE_INFO debug_controls_enabled=true$:::debug_controls_enabled=true (desktop debug active)'
	report_errors "input probe xvfb" "$LOG_DIR/probe-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/g2_display_settings_probe.tscn > "$LOG_DIR/probe-g2-display-settings-xvfb.log" 2>&1
	report_case "G2 display settings xvfb" "$LOG_DIR/probe-g2-display-settings-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "G2 display settings xvfb" "$LOG_DIR/probe-g2-display-settings-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env KP_VNEXT_U4=1 XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/vnext_state_surfaces_probe.tscn > "$LOG_DIR/probe-vnext-state-surfaces-xvfb.log" 2>&1
	report_case "VNext state surfaces xvfb" "$LOG_DIR/probe-vnext-state-surfaces-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "VNext state surfaces xvfb" "$LOG_DIR/probe-vnext-state-surfaces-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env KP_VNEXT_SETTINGS=1 XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/vnext_accessibility_probe.tscn > "$LOG_DIR/probe-vnext-accessibility-xvfb.log" 2>&1
	report_case "VNext accessibility xvfb" "$LOG_DIR/probe-vnext-accessibility-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "VNext accessibility xvfb" "$LOG_DIR/probe-vnext-accessibility-xvfb.log"
	timeout --kill-after="${VALIDATION_KILL_GRACE_SECONDS}s" "${VALIDATION_TIMEOUT_SECONDS}s" env KP_VNEXT_U6=1 XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/vnext_state_surface_probe.tscn > "$LOG_DIR/probe-vnext-state-surface-xvfb.log" 2>&1
	report_case "VNext shared state surface xvfb" "$LOG_DIR/probe-vnext-state-surface-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "VNext shared state surface xvfb" "$LOG_DIR/probe-vnext-state-surface-xvfb.log"
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
