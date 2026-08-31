#!/usr/bin/env bash
## Lote 1 (R01-R03/T01) validation entry point.
##
## Runs the full DevHarness autotest headless plus the input-dispatch probe in
## headless and Xvfb desktop-debug modes. Failures (AT_FAIL / PROBE_FAIL) and
## engine/script ERROR lines are reported in SEPARATE sections: failures gate
## the exit code, ERRORs are reported as the pre-existing baseline (T02 is not
## part of this batch and must not be masked or silently green-lit).
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
	local errors
	errors=$(grep -cE "^(SCRIPT )?ERROR" "$log" || true)
	echo "== $name ERROR baseline (reported, non-gating): $errors"
	if [ "$errors" -gt 0 ]; then
		grep -E "^(SCRIPT )?ERROR" "$log" | sort -u | sed 's/^/   /'
	fi
}

echo "--- suite headless ---"
XDG_DATA_HOME="$XDG" godot --headless --path . -- --autotest > "$LOG_DIR/suite-headless.log" 2>&1
report_case "suite headless (--autotest)" "$LOG_DIR/suite-headless.log" "$?" "AT_PASS" "AT_FAIL" \
	'^AUTOTEST_ALL_PASS$:::AUTOTEST_ALL_PASS marker'
report_errors "suite headless" "$LOG_DIR/suite-headless.log"
echo

echo "--- input dispatch probe ---"
XDG_DATA_HOME="$XDG" godot --headless --path . res://tools/input_dispatch_probe.tscn > "$LOG_DIR/probe-headless.log" 2>&1
report_case "input probe headless" "$LOG_DIR/probe-headless.log" "$?" "PROBE_PASS" "PROBE_FAIL" \
	'^PROBE_DONE fails=0$:::PROBE_DONE fails=0 marker'
report_errors "input probe headless" "$LOG_DIR/probe-headless.log"
echo

if command -v xvfb-run >/dev/null 2>&1; then
	XDG_DATA_HOME="$XDG" xvfb-run -a godot --path . res://tools/input_dispatch_probe.tscn > "$LOG_DIR/probe-xvfb.log" 2>&1
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
	echo "VALIDATION OK (ERROR baseline above is pre-existing and non-gating)"
fi
exit "$overall"
