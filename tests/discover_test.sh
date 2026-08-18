#!/bin/sh
# Never-set-form + redaction proof test for discover.sh (DISC-02 script
# layer + DISC-03).
#
# POSIX sh, no bats dependency (this repo has no shell test harness) —
# follows trivy_scan_checksum_test.sh's structure: mktemp sandbox, a
# PATH-shimmed puppet stub that records its own argv, curated PATH, and
# exit-code/content assertions. Uses STAGEHAND_DISCOVER_PUPPET_BIN (the same
# env-override convention discover.sh documents, mirroring
# trivy_scan_checksum_test.sh's SHIM_* pattern) to point discover.sh at the
# stub instead of a real puppet agent.
#
# Cases (see 14-01-PLAN.md Task 2 <behavior>):
#   (a) redaction    -> a fixture `user` with a real-shaped test password
#                        hash: stdout contains "<redacted>" and NEVER the
#                        literal hash value.
#   (b) query-form    -> requesting `package` records an argv of exactly
#                        `resource package --to_yaml` — never a 3rd
#                        positional token, never an `=` (no set form).
#   (c) unknown-type   -> requesting `package,evil;rm -rf,user` invokes the
#                        stub for package/user only; `evil;rm -rf` never
#                        reaches puppet.
#   (d) per-type timeout -> a stub that sleeps past the (test-shortened)
#                        timeout for `package` yields
#                        types.package.status=="timeout",
#                        types.user.status=="ok", and script exit code 0.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
DISCOVER_SH="$SCRIPT_DIR/../tasks/discover.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
info() { printf '>>> %s\n' "$*"; }

[ -f "$DISCOVER_SH" ] || fail "discover.sh not found at $DISCOVER_SH"

WORK=$(mktemp -d) || fail "mktemp -d failed"
trap 'rm -rf "$WORK"' EXIT

SHIMDIR="$WORK/shims"
mkdir -p "$SHIMDIR" || fail "could not create shim dir"

# A real-shaped (but fixture-only) SHA-512 crypt password hash, matching
# what `puppet resource user --to_yaml` emits for the `password` attribute
# on Linux. Never a real credential.
PASSWORD_HASH='$6$rounds=656000$abcdEFGH12345678$fixtureOnlyHashValueForUnitTestsNeverRealCredential1234567890'
CRON_SECRET_LINE='AWS_SECRET_ACCESS_KEY=AKIAIOSFODNN7EXAMPLE /opt/backup/run.sh --quiet'

ARGV_LOG="$WORK/argv.log"

# --- puppet stub: records its own argv (one invocation per line, joined by
# spaces) and emits fixture --to_yaml output per requested type. Supports
# an optional artificial sleep (SHIM_SLEEP_TYPE/SHIM_SLEEP_SECS) so the
# timeout case can be exercised without waiting out a real 60s timeout. ---
cat > "$SHIMDIR/puppet" <<'SHIM'
#!/bin/sh
printf '%s\n' "$*" >> "$ARGV_LOG"

resource_type="$2"

if [ "${SHIM_SLEEP_TYPE:-}" = "$resource_type" ]; then
  sleep "${SHIM_SLEEP_SECS:-5}"
fi

case "$resource_type" in
  package)
    printf 'package:\n  vim:\n    ensure: "8.2"\n'
    ;;
  user)
    printf "user:\n  bob:\n    ensure: present\n    password: '%s'\n" "$SHIM_USER_PASSWORD_HASH"
    ;;
  group)
    printf 'group:\n  bob:\n    ensure: present\n'
    ;;
  service)
    printf 'service:\n  sshd:\n    ensure: running\n'
    ;;
  mount)
    printf 'mount:\n  "/data":\n    ensure: mounted\n'
    ;;
  cron)
    printf "cron:\n  backup:\n    command: '%s'\n" "$SHIM_CRON_COMMAND"
    ;;
  *)
    exit 1
    ;;
esac
SHIM
chmod +x "$SHIMDIR/puppet"

# Curated PATH: shim dir first, then a minimal real-tool set (ruby, sed,
# timeout, mktemp, tr, printf/cat all need to resolve for real). Discovery
# itself is pointed at the stub via STAGEHAND_DISCOVER_PUPPET_BIN (an absolute
# path, never a PATH lookup), matching how discover.sh resolves $PUPPET —
# the curated PATH here is defense-in-depth documentation, not load-bearing
# for which puppet binary gets used.
TEST_PATH="$SHIMDIR:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

run_discover() {
  # $1 = PT_types JSON-array text; remaining args are extra env assignments
  # already exported by the caller before invoking this function.
  types="$1"
  PATH="$TEST_PATH" \
    ARGV_LOG="$ARGV_LOG" \
    STAGEHAND_DISCOVER_PUPPET_BIN="$SHIMDIR/puppet" \
    STAGEHAND_DISCOVER_TIMEOUT_SECS="${STAGEHAND_DISCOVER_TIMEOUT_SECS:-1}" \
    SHIM_USER_PASSWORD_HASH="$PASSWORD_HASH" \
    SHIM_CRON_COMMAND="$CRON_SECRET_LINE" \
    SHIM_SLEEP_TYPE="${SHIM_SLEEP_TYPE:-}" \
    SHIM_SLEEP_SECS="${SHIM_SLEEP_SECS:-}" \
    PT_types="$types" \
    sh "$DISCOVER_SH"
}

# --- Case (a): redaction. ---
: > "$ARGV_LOG"
OUT=$(run_discover '["user"]') || fail "case (a) redaction: discover.sh exited non-zero (expected 0). Output:
$OUT"
case "$OUT" in
  *"$PASSWORD_HASH"*) fail "case (a) redaction: the fixture password hash leaked into stdout verbatim. Output:
$OUT" ;;
esac
case "$OUT" in
  *'<redacted>'*) : ;;
  *) fail "case (a) redaction: expected \"<redacted>\" in stdout, got:
$OUT" ;;
esac
info "case (a) redaction: OK (hash absent, <redacted> present)"

# --- Case (b): query-form only, exact argv. ---
: > "$ARGV_LOG"
OUT=$(run_discover '["package"]') || fail "case (b) query-form: discover.sh exited non-zero. Output:
$OUT"
LOG_CONTENTS=$(cat "$ARGV_LOG")
[ "$(wc -l <"$ARGV_LOG" | tr -d ' ')" = "1" ] || fail "case (b) query-form: expected exactly 1 puppet invocation, got:
$LOG_CONTENTS"
case "$LOG_CONTENTS" in
  'resource package --to_yaml')
    :
    ;;
  *)
    fail "case (b) query-form: expected argv 'resource package --to_yaml', got: '$LOG_CONTENTS'"
    ;;
esac
case "$LOG_CONTENTS" in
  *'='*) fail "case (b) query-form: argv contains '=' (set-form shaped): '$LOG_CONTENTS'" ;;
esac
info "case (b) query-form: OK (argv is exactly 'resource package --to_yaml')"

# --- Case (c): unknown type token is skipped; siblings still run. ---
: > "$ARGV_LOG"
OUT=$(run_discover '["package","evil;rm -rf","user"]') || fail "case (c) unknown-type: discover.sh exited non-zero. Output:
$OUT"
LOG_CONTENTS=$(cat "$ARGV_LOG")
case "$LOG_CONTENTS" in
  *'evil'*) fail "case (c) unknown-type: 'evil;rm -rf' reached puppet. argv log:
$LOG_CONTENTS" ;;
esac
case "$LOG_CONTENTS" in
  *'resource package --to_yaml'*) : ;;
  *) fail "case (c) unknown-type: expected a 'package' invocation, argv log:
$LOG_CONTENTS" ;;
esac
case "$LOG_CONTENTS" in
  *'resource user --to_yaml'*) : ;;
  *) fail "case (c) unknown-type: expected a 'user' invocation, argv log:
$LOG_CONTENTS" ;;
esac
case "$OUT" in
  *'"package"'*'"status": "ok"'*) : ;;
esac
info "case (c) unknown-type: OK (evil;rm -rf never reached puppet; package/user still ran)"

# --- Case (d): per-type timeout; siblings still succeed; exit 0. ---
: > "$ARGV_LOG"
SHIM_SLEEP_TYPE="package"
SHIM_SLEEP_SECS="5"
STAGEHAND_DISCOVER_TIMEOUT_SECS="1"
OUT=$(run_discover '["package","user"]')
RC=$?
[ "$RC" = "0" ] || fail "case (d) timeout: expected exit 0, got $RC. Output:
$OUT"
case "$OUT" in
  *'"package": {"status": "timeout"'*) : ;;
  *) fail "case (d) timeout: expected types.package.status==\"timeout\", got:
$OUT" ;;
esac
case "$OUT" in
  *'"user": {"status": "ok"'*) : ;;
  *) fail "case (d) timeout: expected types.user.status==\"ok\", got:
$OUT" ;;
esac
info "case (d) timeout: OK (package timed out, user still succeeded, exit 0)"

info "all discovery safety cases PASSED"
exit 0
