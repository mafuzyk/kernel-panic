#!/usr/bin/env bash
## Lote 1 (R01-R03/T01) validation entry point.
##
## Runs the full DevHarness autotest, the accumulated headless gameplay probes,
## and the input-dispatch probe in headless and Xvfb desktop-debug modes.
## Failures (AT_FAIL / PROBE_FAIL) and engine/script ERROR lines are reported in
## SEPARATE sections. Runtime/script errors gate the exit code; known teardown
## resource/RID diagnostics remain visible but non-gating until their ownership
## is isolated.
##
## Usage: tools/validate_input_dispatch.sh
## Logs land in .godot/codex-review-lote-1/ (gitignored runtime artifacts).

set -u
cd "$(dirname "$0")/.."

LOG_DIR="${KP_VALIDATION_LOGS:-.godot/codex-review-lote-1}"
XDG="$LOG_DIR/xdg"
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
	XDG_DATA_HOME="$XDG" godot --audio-driver Dummy --headless --path . "$scene" > "$log" 2>&1
	report_case "$name" "$log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "$name" "$log"
	echo
}

run_headless_probe_with_env() {
	local env_name="$1" slug="$2" name="$3" scene="$4"
	local log="$LOG_DIR/$slug.log"
	env "$env_name=1" XDG_DATA_HOME="$XDG" godot --audio-driver Dummy --headless --path . "$scene" > "$log" 2>&1
	report_case "$name" "$log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
	report_errors "$name" "$log"
	echo
}

echo "--- suite headless ---"
XDG_DATA_HOME="$XDG" godot --audio-driver Dummy --headless --path . -- --autotest > "$LOG_DIR/suite-headless.log" 2>&1
report_case "suite headless (--autotest)" "$LOG_DIR/suite-headless.log" "$?" "AT_PASS" "AT_FAIL" \
	'^AUTOTEST_ALL_PASS$:::AUTOTEST_ALL_PASS marker'
report_errors "suite headless" "$LOG_DIR/suite-headless.log"
echo

echo "--- input dispatch probe ---"
XDG_DATA_HOME="$XDG" godot --audio-driver Dummy --headless --path . res://tools/input_dispatch_probe.tscn > "$LOG_DIR/probe-headless.log" 2>&1
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
run_headless_probe "probe-vnext-patch-surface" "VNext patch decision surface" "res://tools/vnext_patch_probe.tscn"
run_headless_probe_with_env "KP_VNEXT_PATCH" "probe-vnext-patch-arena" "VNext patch Arena adapter" "res://tools/vnext_patch_arena_probe.tscn"
run_headless_probe_with_env "KP_VNEXT_HUD" "probe-vnext-combat-hud" "VNext combat HUD Arena adapter" "res://tools/vnext_combat_hud_probe.tscn"

if command -v xvfb-run >/dev/null 2>&1; then
	XDG_DATA_HOME="$XDG" xvfb-run -a godot --audio-driver Dummy --path . res://tools/input_dispatch_probe.tscn > "$LOG_DIR/probe-xvfb.log" 2>&1
	report_case "input probe xvfb (desktop debug)" "$LOG_DIR/probe-xvfb.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
		'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker' \
		'^PROBE_INFO debug_controls_enabled=true$:::debug_controls_enabled=true (desktop debug active)'
	report_errors "input probe xvfb" "$LOG_DIR/probe-xvfb.log"
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
