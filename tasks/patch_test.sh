#!/bin/sh
# stagehand::patch test harness (999.12-01-PLAN.md Task 2). Follows
# recert_test.sh's env -i invocation pattern; patch.json's input_method is
# "environment" (PT_security_only / PT_reboot), so params are fed via PT_*
# env vars, not stdin JSON. patch.sh had zero test coverage before this
# phase — it was ported byte-identical from puppet-console's
# adapters/stagehand/tasks/patch.sh, but the reconciliation adds the first
# behavioural test for it.
#
# Cases (see 999.12-01-PLAN.md Task 2 <action>, "cover at minimum"):
#   (1) apt branch selected when only an apt stub is on PATH, all-updates
#       mode (PT_security_only unset) -> applied "all", exit 0.
#   (2) security-only branch selected when PT_security_only=true and
#       unattended-upgrade is on PATH -> applied "security", exit 0.
#   (3) a stub returning non-zero (apt-get update failing) produces the
#       script's die() error path on stderr and exit 1, not a silent
#       success -- no JSON on stdout.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
TARGET_SH="$SCRIPT_DIR/patch.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
info() { printf '>>> %s\n' "$*"; }

[ -f "$TARGET_SH" ] || fail "patch.sh not found at $TARGET_SH"
command -v jq >/dev/null 2>&1 || fail "jq is required to run this test harness"

WORK=$(mktemp -d) || fail "mktemp -d failed"
trap 'rm -rf "$WORK"' EXIT

SHIMDIR="$WORK/shims"
mkdir -p "$SHIMDIR" || fail "could not create shim dir"

# write_apt_stub UPDATE_RC DIST_UPGRADE_RC
# Writes a PATH shim named "apt-get" that answers the two invocations
# patch.sh's apt branch makes for the all-updates path: `-qq update` and
# `-y dist-upgrade`. Any other invocation (e.g. -s dist-upgrade, used only
# by the security-fallback branch this test does not exercise) fails loudly
# so an unexpected code path is never mistaken for a passing test.
write_apt_stub() {
  update_rc="$1"
  dist_upgrade_rc="$2"
  cat > "$SHIMDIR/apt-get" <<SHIM
#!/bin/sh
case "\$*" in
  "-qq update") exit $update_rc ;;
  "-y dist-upgrade") exit $dist_upgrade_rc ;;
  *) printf 'STUB: unhandled apt-get invocation: %s\n' "\$*" >&2; exit 99 ;;
esac
SHIM
  chmod +x "$SHIMDIR/apt-get"
}

write_unattended_upgrade_stub() {
  rc="$1"
  cat > "$SHIMDIR/unattended-upgrade" <<SHIM
#!/bin/sh
exit $rc
SHIM
  chmod +x "$SHIMDIR/unattended-upgrade"
}

# Only $SHIMDIR is on PATH (plus the minimal set needed by patch.sh's own
# shell builtins/printf/command). No real system package manager is ever
# on PATH here, so an unstubbed apt-get/dnf/yum cannot leak through.
TEST_PATH="$SHIMDIR:/usr/bin:/bin"

run_patch() {
  # shellcheck disable=SC2086
  env -i \
    PATH="$TEST_PATH" \
    HOME="$HOME" \
    ${PT_security_only:+PT_security_only="$PT_security_only"} \
    ${PT_reboot:+PT_reboot="$PT_reboot"} \
    sh "$TARGET_SH"
}

reset() {
  unset PT_security_only PT_reboot
  rm -f "$SHIMDIR"/*
}

# --- Case 1: apt branch, all-updates mode -> applied "all", exit 0. -------
reset
write_apt_stub 0 0
OUT=$(run_patch 2>"$WORK/stderr.1")
RC=$?
[ "$RC" -eq 0 ] || fail "case 1 (apt all-updates): expected exit 0, got $RC. stderr: $(cat "$WORK/stderr.1"). stdout: $OUT"
STATUS1=$(printf '%s' "$OUT" | jq -er '.status' 2>/dev/null) \
  || fail "case 1 (apt all-updates): output is not valid JSON: $OUT"
APPLIED1=$(printf '%s' "$OUT" | jq -r '.applied' 2>/dev/null)
[ "$STATUS1" = "patched" ] || fail "case 1 (apt all-updates): expected status 'patched', got: $STATUS1. stdout: $OUT"
[ "$APPLIED1" = "all" ] || fail "case 1 (apt all-updates): expected applied 'all', got: $APPLIED1. stdout: $OUT"
info "case 1 (apt all-updates): OK (apt branch selected, applied=all, exit 0)"

# --- Case 2: security-only branch via unattended-upgrade -> applied "security". ---
reset
write_apt_stub 0 0
write_unattended_upgrade_stub 0
PT_security_only=true
OUT=$(run_patch 2>"$WORK/stderr.2")
RC=$?
[ "$RC" -eq 0 ] || fail "case 2 (security-only): expected exit 0, got $RC. stderr: $(cat "$WORK/stderr.2"). stdout: $OUT"
STATUS2=$(printf '%s' "$OUT" | jq -er '.status' 2>/dev/null) \
  || fail "case 2 (security-only): output is not valid JSON: $OUT"
APPLIED2=$(printf '%s' "$OUT" | jq -r '.applied' 2>/dev/null)
[ "$STATUS2" = "patched" ] || fail "case 2 (security-only): expected status 'patched', got: $STATUS2. stdout: $OUT"
[ "$APPLIED2" = "security" ] || fail "case 2 (security-only): expected applied 'security' (unattended-upgrade path), got: $APPLIED2. stdout: $OUT"
info "case 2 (security-only): OK (unattended-upgrade branch selected, applied=security, exit 0)"

# --- Case 3: apt-get update failing -> die() error path, not silent success. ---
reset
write_apt_stub 1 0
OUT=$(run_patch 2>"$WORK/stderr.3")
RC=$?
STDERR3=$(cat "$WORK/stderr.3")
[ "$RC" -eq 1 ] || fail "case 3 (apt-get update fails): expected exit 1, got $RC. stdout: $OUT"
[ -z "$OUT" ] || fail "case 3 (apt-get update fails): expected no stdout JSON on the error path, got: $OUT"
case "$STDERR3" in
  *'apt-get update failed'*) : ;;
  *) fail "case 3 (apt-get update fails): expected stderr to contain 'apt-get update failed', got: $STDERR3" ;;
esac
info "case 3 (apt-get update fails): OK (die() error path, exit 1, no silent success)"

info "all patch.sh safety cases PASSED"
exit 0
