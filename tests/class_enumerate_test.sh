#!/bin/sh
# Behavior proof for class_enumerate.rb: reads classes.txt from statedir,
# never invokes a live catalog compile. POSIX sh, no bats dependency — follows
# discover_test.sh's mktemp-sandbox + curated-PATH structure.
#
# Cases:
#   (a) present    -> classes.txt with entries yields sorted, deduped,
#                      non-blank class names in the "classes" array.
#   (b) missing     -> no classes.txt yields {"classes": [], "note": "..."}
#                      and exit 0 (not a task failure).
#   (c) override    -> STAGEHAND_CLASS_ENUMERATE_STATEDIR_OVERRIDE is honored
#                      over the resolved/default statedir.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
TASK_RB="$SCRIPT_DIR/../tasks/class_enumerate.rb"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
info() { printf '>>> %s\n' "$*"; }

[ -f "$TASK_RB" ] || fail "class_enumerate.rb not found at $TASK_RB"
command -v ruby >/dev/null 2>&1 || fail "ruby not found on PATH"

WORK=$(mktemp -d) || fail "mktemp -d failed"
trap 'rm -rf "$WORK"' EXIT

run_task() {
  # $1 = statedir override
  STAGEHAND_CLASS_ENUMERATE_STATEDIR_OVERRIDE="$1" ruby "$TASK_RB"
}

# --- Case (a): classes.txt present, unsorted + duplicate + blank lines. ---
STATEDIR_A="$WORK/statedir_a"
mkdir -p "$STATEDIR_A"
printf 'profile::web\nprofile::base\n\nprofile::web\nprofile::db\n' > "$STATEDIR_A/classes.txt"
OUT=$(run_task "$STATEDIR_A")
RC=$?
[ "$RC" = "0" ] || fail "case (a) present: expected exit 0, got $RC. Output:
$OUT"
case "$OUT" in
  *'"classes":["profile::base","profile::db","profile::web"]'*) : ;;
  *) fail "case (a) present: expected sorted/deduped classes array, got:
$OUT" ;;
esac
info "case (a) present: OK (sorted, deduped, blank line dropped)"

# --- Case (b): no classes.txt at all. ---
STATEDIR_B="$WORK/statedir_b_empty"
mkdir -p "$STATEDIR_B"
OUT=$(run_task "$STATEDIR_B")
RC=$?
[ "$RC" = "0" ] || fail "case (b) missing: expected exit 0, got $RC. Output:
$OUT"
case "$OUT" in
  *'"classes":[]'*'"note"'*) : ;;
  *) fail "case (b) missing: expected empty classes array + note, got:
$OUT" ;;
esac
info "case (b) missing: OK (empty classes + note, exit 0)"

# --- Case (c): override actually wins over default/resolved statedir. ---
STATEDIR_C="$WORK/statedir_c"
mkdir -p "$STATEDIR_C"
printf 'role::override_proof\n' > "$STATEDIR_C/classes.txt"
OUT=$(run_task "$STATEDIR_C")
RC=$?
[ "$RC" = "0" ] || fail "case (c) override: expected exit 0, got $RC. Output:
$OUT"
case "$OUT" in
  *'role::override_proof'*) : ;;
  *) fail "case (c) override: expected override statedir's class to appear, got:
$OUT" ;;
esac
info "case (c) override: OK (STAGEHAND_CLASS_ENUMERATE_STATEDIR_OVERRIDE honored)"

info "all class_enumerate cases PASSED"
exit 0
