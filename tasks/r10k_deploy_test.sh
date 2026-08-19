#!/bin/sh
# stagehand::r10k_deploy JSON-on-fail contract test harness (02-03-PLAN.md
# Task 1). Follows recert_test.sh's env -i isolation pattern; r10k_deploy.sh
# had zero test coverage before this phase.
#
# Cases (see 02-03-PLAN.md Task 1 <behavior>):
#   (1) success (stub r10k exits 0) -> embedded JSON success, exit 0
#       (regression, unchanged).
#   (2) simulated r10k nonzero exit (exit 1) -> embedded JSON error, exit 0
#       (AUDIT-04).
#   (3) PT_environment containing shell metacharacters is rejected by the
#       existing allowlist guard -> die()/exit 1, r10k stub NEVER invoked
#       (AUDIT-01 regression, confirms this task stays clean).
#   (4) PT_r10k_path override is honored -> a specific stub path is invoked
#       instead of relying on the PATH-search fallback.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
TARGET_SH="$SCRIPT_DIR/r10k_deploy.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
info() { printf '>>> %s\n' "$*"; }

[ -f "$TARGET_SH" ] || fail "r10k_deploy.sh not found at $TARGET_SH"
command -v jq >/dev/null 2>&1 || fail "jq is required to run this test harness"

WORK=$(mktemp -d) || fail "mktemp -d failed"
trap 'rm -rf "$WORK"' EXIT

SHIMDIR="$WORK/shims"
mkdir -p "$SHIMDIR" || fail "could not create shim dir"

ARGV_LOG="$WORK/argv.log"
export ARGV_LOG

# make_r10k_stub EXIT_CODE
# Writes a PATH shim named "r10k" that logs its own argv to ARGV_LOG and
# exits with EXIT_CODE. Never a real r10k binary.
make_r10k_stub() {
  exit_code="$1"
  cat > "$SHIMDIR/r10k" <<SHIM
#!/bin/sh
printf 'r10k %s\n' "\$*" >> "$ARGV_LOG"
exit $exit_code
SHIM
  chmod +x "$SHIMDIR/r10k"
}

TEST_PATH="$SHIMDIR:/usr/bin:/bin:/usr/sbin:/sbin"

# run_r10k_deploy ENVIRONMENT [R10K_PATH]
# Invokes r10k_deploy.sh in an isolated environment (env -i) — only PATH,
# HOME, and the explicit PT_* params r10k_deploy.sh reads are passed
# through, so no ambient env var can accidentally reach a real r10k binary.
# PATH is curated to contain ONLY the shim dir plus minimal system dirs
# (no /opt/puppetlabs/puppet/bin, no /usr/local/bin) so "command -v r10k"
# can never resolve to anything but the stub above.
run_r10k_deploy() {
  env_name="$1"
  r10k_path="${2:-}"
  env -i \
    PATH="$TEST_PATH" \
    HOME="$HOME" \
    PT_environment="$env_name" \
    PT_r10k_path="$r10k_path" \
    sh "$TARGET_SH"
}

# --- Case 1: success (stub r10k exits 0) -> embedded JSON success, exit 0 (regression). ---
: > "$ARGV_LOG"
make_r10k_stub 0
OUT=$(run_r10k_deploy production)
RC=$?
[ "$RC" -eq 0 ] || fail "case 1 (success): expected exit 0, got $RC. stdout: $OUT"
STATUS1=$(printf '%s' "$OUT" | jq -r '.status' 2>/dev/null)
ENV1=$(printf '%s' "$OUT" | jq -r '.environment' 2>/dev/null)
[ "$STATUS1" = "deployed" ] || fail "case 1 (success): expected status 'deployed', got: $STATUS1. stdout: $OUT"
[ "$ENV1" = "production" ] || fail "case 1 (success): expected environment 'production', got: $ENV1. stdout: $OUT"
grep -q '^r10k ' "$ARGV_LOG" || fail "case 1 (success): r10k stub was not invoked. argv log:
$(cat "$ARGV_LOG")"
info "case 1 (success): OK (embedded JSON success, exit 0, r10k stub invoked)"

# --- Case 2: simulated r10k nonzero exit -> embedded JSON error, exit 0 (AUDIT-04). ---
: > "$ARGV_LOG"
make_r10k_stub 1
OUT=$(run_r10k_deploy production)
RC=$?
[ "$RC" -eq 0 ] || fail "case 2 (r10k exit 1): expected exit 0 (status embedded), got $RC. stdout: $OUT"
STATUS2=$(printf '%s' "$OUT" | jq -r '.status' 2>/dev/null)
ERROR2=$(printf '%s' "$OUT" | jq -r '.error' 2>/dev/null)
ENV2=$(printf '%s' "$OUT" | jq -r '.environment' 2>/dev/null)
[ "$STATUS2" = "error" ] || fail "case 2 (r10k exit 1): expected status 'error', got: $STATUS2. stdout: $OUT"
[ "$ENV2" = "production" ] || fail "case 2 (r10k exit 1): expected environment 'production', got: $ENV2. stdout: $OUT"
case "$ERROR2" in
  *'r10k exited 1'*) : ;;
  *) fail "case 2 (r10k exit 1): expected error to mention 'r10k exited 1', got: $ERROR2" ;;
esac
info "case 2 (r10k exit 1): OK (embedded JSON error, exit 0)"

# --- Case 3: PT_environment with shell metacharacters -> die()/exit 1, stub NEVER invoked (AUDIT-01 regression). ---
: > "$ARGV_LOG"
make_r10k_stub 0
OUT=$(run_r10k_deploy 'production; rm -rf /' 2>"$WORK/stderr.3")
RC=$?
STDERR3=$(cat "$WORK/stderr.3")
[ "$RC" -eq 1 ] || fail "case 3 (metachar environment): expected exit 1, got $RC. stdout: $OUT"
case "$STDERR3" in
  *'invalid environment name'*) : ;;
  *) fail "case 3 (metachar environment): expected stderr to mention 'invalid environment name', got: $STDERR3" ;;
esac
[ -s "$ARGV_LOG" ] && fail "case 3 (metachar environment): r10k stub was invoked but should not have been. argv log:
$(cat "$ARGV_LOG")"
info "case 3 (metachar environment): OK (die()/exit 1, r10k stub never invoked)"

# --- Case 4: PT_r10k_path override is honored (points at a specific stub, not PATH search). ---
: > "$ARGV_LOG"
ALT_R10K="$WORK/alt-r10k"
cat > "$ALT_R10K" <<SHIM
#!/bin/sh
printf 'alt-r10k %s\n' "\$*" >> "$ARGV_LOG"
exit 0
SHIM
chmod +x "$ALT_R10K"
# No "r10k" shim on PATH at all for this case — if the override were NOT
# honored, command -v r10k would fail and the script would die() with "r10k
# not found", proving the override is what made this succeed.
rm -f "$SHIMDIR/r10k"
OUT=$(run_r10k_deploy production "$ALT_R10K")
RC=$?
[ "$RC" -eq 0 ] || fail "case 4 (r10k_path override): expected exit 0, got $RC. stdout: $OUT"
STATUS4=$(printf '%s' "$OUT" | jq -r '.status' 2>/dev/null)
[ "$STATUS4" = "deployed" ] || fail "case 4 (r10k_path override): expected status 'deployed', got: $STATUS4. stdout: $OUT"
grep -q '^alt-r10k ' "$ARGV_LOG" || fail "case 4 (r10k_path override): PT_r10k_path override was not honored — alt-r10k stub was never invoked. argv log:
$(cat "$ARGV_LOG")"
info "case 4 (r10k_path override): OK (PT_r10k_path honored, not the PATH-search fallback)"

info "all r10k_deploy safety cases PASSED"
exit 0
