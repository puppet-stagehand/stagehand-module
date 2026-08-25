#!/bin/sh
# Genuine-separation + fail-loud proof test for r10k_read_deploy_key.sh
# (D-19, 47-07-PLAN.md Task 1 <acceptance_criteria>).
#
# POSIX sh, no bats dependency -- mirrors r10k_detect_test.sh's structure:
# mktemp sandbox, PT_key_path env override (Bolt's own environment
# input_method convention -- never a script-only test hook, since this IS
# the task's one real parameter), exit-code/content assertions.
#
# Cases:
#   (a) present+readable -> stdout carries the exact expected JSON shape,
#                            exit 0.
#   (b) missing           -> die()s loudly (nonzero exit, ERROR: message on
#                            stderr), NEVER an empty/placeholder key and
#                            NEVER exit 0.
#   (c) unreadable (mode 000) -> same fail-loud contract as (b), a distinct
#                            real-world cause (permissions, not absence).

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
READ_KEY_SH="$SCRIPT_DIR/r10k_read_deploy_key.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
info() { printf '>>> %s\n' "$*"; }

[ -f "$READ_KEY_SH" ] || fail "r10k_read_deploy_key.sh not found at $READ_KEY_SH"

WORK=$(mktemp -d) || fail "mktemp -d failed"
trap 'rm -rf "$WORK"' EXIT

# --- Case (a): present and readable. ---
KEY_CONTENT='-----BEGIN OPENSSH PRIVATE KEY-----
FIXTURE-KEY-BODY-b17e
-----END OPENSSH PRIVATE KEY-----
'
printf '%s' "$KEY_CONTENT" >"$WORK/id_ed25519"
chmod 600 "$WORK/id_ed25519"

OUT=$(HOME="$WORK" PT_key_path="$WORK/id_ed25519" sh "$READ_KEY_SH") ||
  fail "case (a) present+readable: r10k_read_deploy_key.sh exited non-zero. Output:
$OUT"
case "$OUT" in
  *'"private_key"'*'FIXTURE-KEY-BODY-b17e'*) : ;;
  *) fail "case (a) present+readable: expected the fixture key's content verbatim in private_key, got:
$OUT" ;;
esac
case "$OUT" in
  *'"key_path":"'"$WORK"'/id_ed25519"'*) : ;;
  *) fail "case (a) present+readable: expected key_path to carry the resolved path, got:
$OUT" ;;
esac
info "case (a) present+readable: OK (expected JSON shape, exit 0)"

# --- Case (b): missing -- PT_key_path points at a path that does not
# exist, and no conventional default location exists in this sandboxed
# HOME either, so the task must fail loudly, never return an empty/success
# response. ---
ERR=$(HOME="$WORK" PT_key_path="$WORK/does-not-exist" sh "$READ_KEY_SH" 2>&1)
rc=$?
if [ "$rc" -eq 0 ]; then
  fail "case (b) missing: expected a nonzero exit, got 0. Output:
$ERR"
fi
case "$ERR" in
  ERROR:*) : ;;
  *) fail "case (b) missing: expected a die() 'ERROR: ...' message on stderr, got:
$ERR" ;;
esac
case "$ERR" in
  *'"private_key"'*) fail "case (b) missing: must NEVER emit a private_key field on failure, got:
$ERR" ;;
  *) : ;;
esac
info "case (b) missing: OK (nonzero exit, die() message, no key emitted)"

# --- Case (c): unreadable -- present but mode 000 (permission denied),
# a distinct real-world cause from absence. Skipped when running as root
# (root ignores file mode bits, e.g. some CI containers), matching the
# established convention for permission-dependent tests in this repo. ---
if [ "$(id -u)" != "0" ]; then
  printf '%s' "$KEY_CONTENT" >"$WORK/id_unreadable"
  chmod 000 "$WORK/id_unreadable"

  ERR=$(HOME="$WORK" PT_key_path="$WORK/id_unreadable" sh "$READ_KEY_SH" 2>&1)
  rc=$?
  chmod 600 "$WORK/id_unreadable" # restore so trap cleanup can remove it
  if [ "$rc" -eq 0 ]; then
    fail "case (c) unreadable: expected a nonzero exit, got 0. Output:
$ERR"
  fi
  case "$ERR" in
    ERROR:*) : ;;
    *) fail "case (c) unreadable: expected a die() 'ERROR: ...' message on stderr, got:
$ERR" ;;
  esac
  info "case (c) unreadable: OK (nonzero exit, die() message)"
else
  info "case (c) unreadable: SKIPPED (running as root, mode bits are not enforced)"
fi

# --- Separation proof: r10k_detect.sh must never reference this task's
# name or logic (47-07-PLAN.md Task 1's own acceptance criterion). ---
DETECT_SH="$SCRIPT_DIR/r10k_detect.sh"
if [ -f "$DETECT_SH" ]; then
  if grep -q r10k_read_deploy_key "$DETECT_SH"; then
    fail "separation: r10k_detect.sh references r10k_read_deploy_key -- these must stay genuinely separate tasks (T-47-16)"
  fi
  info "separation: OK (r10k_detect.sh never references r10k_read_deploy_key)"
fi

info "all r10k_read_deploy_key safety cases PASSED"
exit 0
