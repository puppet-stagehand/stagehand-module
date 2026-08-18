#!/bin/sh
# Never-argv + 0600 + hosts/connection-validation proof test for
# run_playbook.sh (T-14.3-01, T-14.3-04, D-04). See 14.3-01-PLAN.md Task 1
# <verify>/<acceptance_criteria>.
#
# POSIX sh, no bats dependency — follows discover_test.sh's structure:
# mktemp sandbox, a PATH-shimmed stub ansible-playbook that records its own
# argv (and the mode of the playbook file it's invoked with), curated PATH,
# and exit-code/content assertions. Feeds params via STDIN (Bolt's stdin
# input_method), never PT_* env vars.
#
# Cases (see 14.3-01-PLAN.md Task 1 <action>/<acceptance_criteria>):
#   (a) valid playbook  -> stub invoked with --connection=local, script
#                          exits 0, play.status == "ok".
#   (b) never-argv proof -> the raw playbook YAML text never appears as an
#                          argv token in ARGV_LOG; only a temp-file path is
#                          passed positionally.
#   (c) missing connection: local -> play.status == "failed" with a
#                          validation error; stub NOT invoked; install.status
#                          == "skipped" (WR-01: validation runs BEFORE the
#                          install step, so install never ran at all — not
#                          just "ran and happened not to invoke a stub").
#   (d) 0600 temp file  -> the on-disk playbook temp file, as seen by the
#                          stub at invocation time, is mode 0600.
#   (e) install_method skip, stub present -> install.status == "ok".
#   (f) ruby override  -> STAGEHAND_RUBY_BIN points json_field/json_escape at a
#                        ruby stub that records it was invoked (G-14.3-4
#                        fix: same override discover.sh honors).

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
RUN_PLAYBOOK_SH="$SCRIPT_DIR/run_playbook.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
info() { printf '>>> %s\n' "$*"; }

[ -f "$RUN_PLAYBOOK_SH" ] || fail "run_playbook.sh not found at $RUN_PLAYBOOK_SH"
[ -f "$SCRIPT_DIR/install_ansible.sh" ] || fail "install_ansible.sh not found at $SCRIPT_DIR/install_ansible.sh"

WORK=$(mktemp -d) || fail "mktemp -d failed"
trap 'rm -rf "$WORK"' EXIT

SHIMDIR="$WORK/shims"
mkdir -p "$SHIMDIR" || fail "could not create shim dir"

ARGV_LOG="$WORK/argv.log"
MODE_LOG="$WORK/mode.log"
export ARGV_LOG MODE_LOG

# --- ansible-playbook stub: records its own argv (one invocation per line)
# and, for the last positional arg (the playbook file path), records its
# permission mode so case (d) can assert 0600 without racing the script's
# own EXIT-trap cleanup (the stub inspects the file WHILE run_playbook.sh is
# still running, before its trap fires). ---
cat > "$SHIMDIR/ansible-playbook" <<'SHIM'
#!/bin/sh
printf '%s\n' "$*" >> "$ARGV_LOG"
last=""
for arg in "$@"; do last="$arg"; done
if [ -n "$last" ] && [ -f "$last" ]; then
  MODE=$(stat -c '%a' "$last" 2>/dev/null || stat -f '%Lp' "$last" 2>/dev/null)
  printf '%s\n' "$MODE" > "$MODE_LOG"
fi
printf 'PLAY [Say hello] ****\nok: [localhost]\nPLAY RECAP ****\nlocalhost : ok=1 changed=0 unreachable=0 failed=0\n'
exit 0
SHIM
chmod +x "$SHIMDIR/ansible-playbook"

TEST_PATH="$SHIMDIR:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# json_encode TEXT — prints TEXT as a JSON-quoted string (test harness's own
# copy of run_playbook.sh's json_escape, kept independent so the test never
# accidentally validates itself against its own helper).
json_encode() {
  printf '%s' "$1" | ruby -rjson -e 'print JSON.generate(STDIN.read)'
}

VALID_PLAYBOOK='---
- hosts: localhost
  connection: local
  tasks:
    - name: Say hello
      debug:
        msg: "Hello from {{ inventory_hostname }}"
'

INVALID_PLAYBOOK='---
- hosts: localhost
  tasks:
    - name: Say hello
      debug:
        msg: "hello, no local exec directive here"
'

# run_playbook BODY_JSON — feeds BODY_JSON via stdin (Bolt's stdin
# input_method), pointing the script's ansible-playbook binary (both the
# install-step presence check and the play-step invocation) at the stub.
run_playbook() {
  printf '%s' "$1" | \
    PATH="$TEST_PATH" \
    STAGEHAND_PLAYBOOK_ANSIBLE_BIN="$SHIMDIR/ansible-playbook" \
    sh "$RUN_PLAYBOOK_SH"
}

# --- Case (a): valid playbook -> stub invoked with --connection=local, exit 0, play.status=="ok". ---
: > "$ARGV_LOG"
BODY=$(printf '{"playbook": %s, "install_method": "auto"}' "$(json_encode "$VALID_PLAYBOOK")")
OUT=$(run_playbook "$BODY")
RC=$?
[ "$RC" = "0" ] || fail "case (a) valid playbook: expected exit 0, got $RC. Output:
$OUT"
case "$OUT" in
  *'"play": {"status": "ok"'*) : ;;
  *) fail "case (a) valid playbook: expected play.status==\"ok\", got:
$OUT" ;;
esac
LOG_CONTENTS=$(cat "$ARGV_LOG")
case "$LOG_CONTENTS" in
  *'--connection=local'*) : ;;
  *) fail "case (a) valid playbook: expected stub argv to contain --connection=local, got: '$LOG_CONTENTS'" ;;
esac
info "case (a) valid playbook: OK (stub invoked with --connection=local, play.status==ok)"

# --- Case (b): never-argv proof. ---
: > "$ARGV_LOG"
BODY=$(printf '{"playbook": %s, "install_method": "skip"}' "$(json_encode "$VALID_PLAYBOOK")")
OUT=$(run_playbook "$BODY") || fail "case (b) never-argv: run_playbook.sh exited non-zero. Output:
$OUT"
LOG_CONTENTS=$(cat "$ARGV_LOG")
case "$LOG_CONTENTS" in
  *'hosts: localhost'*) fail "case (b) never-argv: playbook content leaked into argv: '$LOG_CONTENTS'" ;;
  *'Say hello'*) fail "case (b) never-argv: playbook content leaked into argv: '$LOG_CONTENTS'" ;;
esac
# The last token of the logged argv must look like a filesystem path (e.g.
# a mktemp-style /tmp/... path), not multi-line YAML content — the positive
# half of the never-argv proof (the negative half is the leak checks above).
LAST_TOKEN=$(printf '%s' "$LOG_CONTENTS" | awk '{print $NF}')
case "$LAST_TOKEN" in
  /*) : ;;
  *) fail "case (b) never-argv: expected the last argv token to be an absolute temp-file path, got: '$LAST_TOKEN'" ;;
esac
info "case (b) never-argv: OK (playbook YAML never appears in argv; only a temp-file path is passed positionally)"

# --- Case (c): missing 'connection: local' -> failed, stub NOT invoked. ---
: > "$ARGV_LOG"
BODY=$(printf '{"playbook": %s, "install_method": "skip"}' "$(json_encode "$INVALID_PLAYBOOK")")
OUT=$(run_playbook "$BODY")
RC=$?
[ "$RC" = "0" ] || fail "case (c) missing connection:local: expected exit 0 (status embedded), got $RC. Output:
$OUT"
case "$OUT" in
  *'"play": {"status": "failed"'*) : ;;
  *) fail "case (c) missing connection:local: expected play.status==\"failed\", got:
$OUT" ;;
esac
case "$OUT" in
  *'connection: local'*) : ;;
  *) fail "case (c) missing connection:local: expected a validation error mentioning connection: local, got:
$OUT" ;;
esac
[ -s "$ARGV_LOG" ] && fail "case (c) missing connection:local: ansible-playbook stub was invoked but should not have been. argv log:
$(cat "$ARGV_LOG")"
# WR-01: install must not even be attempted for an invalid playbook — proven
# by install.status == "skipped" rather than the "ok" install_method=skip
# would otherwise report (the stub is present on PATH, so a real
# install_ansible_run("skip") call would find it and report "ok"; "skipped"
# only appears when the WR-01 pre-install validation short-circuits before
# install_ansible_run is ever called).
case "$OUT" in
  *'"install": {"method": "skip", "status": "skipped"'*) : ;;
  *) fail "case (c) missing connection:local: expected install.status==\"skipped\" (install never attempted), got:
$OUT" ;;
esac
info "case (c) missing connection:local: OK (play.status==failed, validation error present, stub not invoked, install skipped entirely)"

# --- Case (d): playbook temp file is mode 0600. ---
: > "$ARGV_LOG"
: > "$MODE_LOG"
BODY=$(printf '{"playbook": %s, "install_method": "skip"}' "$(json_encode "$VALID_PLAYBOOK")")
OUT=$(run_playbook "$BODY") || fail "case (d) 0600: run_playbook.sh exited non-zero. Output:
$OUT"
MODE=$(cat "$MODE_LOG" 2>/dev/null || true)
[ "$MODE" = "600" ] || fail "case (d) 0600: expected playbook temp file mode 600, got '$MODE'"
info "case (d) 0600: OK (playbook temp file was mode 600 at invocation time)"

# --- Case (e): install_method skip, stub present -> install.status=="ok". ---
: > "$ARGV_LOG"
BODY=$(printf '{"playbook": %s, "install_method": "skip"}' "$(json_encode "$VALID_PLAYBOOK")")
OUT=$(run_playbook "$BODY") || fail "case (e) skip-with-stub: run_playbook.sh exited non-zero. Output:
$OUT"
case "$OUT" in
  *'"install": {"method": "skip", "status": "ok"}'*) : ;;
  *) fail "case (e) skip-with-stub: expected install.status==\"ok\" for install_method skip with the stub present, got:
$OUT" ;;
esac
info "case (e) skip-with-stub: OK (install.status==ok when ansible-playbook is already present)"

# --- Case (f): STAGEHAND_RUBY_BIN override is honored by json_field/json_escape. ---
REAL_RUBY=$(command -v ruby) || fail "case (f) ruby override: no real ruby on PATH to wrap"
RUBY_LOG="$WORK/ruby_invoked.log"
cat > "$SHIMDIR/ruby-shim" <<SHIM
#!/bin/sh
printf 'invoked\n' >> "$RUBY_LOG"
exec "$REAL_RUBY" "\$@"
SHIM
chmod +x "$SHIMDIR/ruby-shim"

: > "$ARGV_LOG"
: > "$RUBY_LOG"
BODY=$(printf '{"playbook": %s, "install_method": "skip"}' "$(json_encode "$VALID_PLAYBOOK")")
OUT=$(printf '%s' "$BODY" | \
  PATH="$TEST_PATH" \
  STAGEHAND_PLAYBOOK_ANSIBLE_BIN="$SHIMDIR/ansible-playbook" \
  STAGEHAND_RUBY_BIN="$SHIMDIR/ruby-shim" \
  sh "$RUN_PLAYBOOK_SH") || fail "case (f) ruby override: run_playbook.sh exited non-zero. Output:
$OUT"
[ -s "$RUBY_LOG" ] || fail "case (f) ruby override: STAGEHAND_RUBY_BIN shim was never invoked"
case "$OUT" in
  *'"play": {"status": "ok"'*) : ;;
  *) fail "case (f) ruby override: expected play.status==\"ok\" via the override, got:
$OUT" ;;
esac
info "case (f) ruby override: OK (STAGEHAND_RUBY_BIN honored by json_field/json_escape)"

info "all run_playbook safety cases PASSED"
exit 0
