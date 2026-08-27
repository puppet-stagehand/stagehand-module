#!/bin/sh
# install_ansible.sh multi-strategy body test harness (14.3-02-PLAN.md
# Task 1). Follows discover_test.sh / run_playbook_test.sh's structure:
# mktemp sandbox, PATH-shimmed installer stubs that record their own
# invocation, a curated PATH, and exit-code/content assertions. Feeds
# params via STDIN (Bolt's stdin input_method), and points the presence
# check at a scratch file via STAGEHAND_ANSIBLE_BIN (mirroring
# STAGEHAND_DISCOVER_PUPPET_BIN's env-override convention) rather than a real
# ansible-playbook binary.
#
# Cases (see 14.3-02-PLAN.md Task 1 <action>):
#   (a) skip, ansible present  -> status ok, no installer stub invoked.
#   (b) skip, ansible absent   -> status error.
#   (c) package on a stubbed apt host -> apt-get stub invoked, status ok.
#   (d) pip                    -> pip3 stub invoked, status ok.
#   (e) auto, ansible absent, working package stub -> ok via package
#                                 (pip stub NOT invoked).
#   (f) auto, package stub present but failing -> falls back to pip
#                                 stub, status ok.
#   (g) pipx                   -> pipx stub invoked, status ok.
#   (h) wsl, wsl command unavailable -> status error, WSL-specific message.
#   (j) ruby override  -> STAGEHAND_RUBY_BIN points the standalone entry point's
#                        install_method JSON parse at a ruby stub that
#                        records it was invoked (G-14.3-4 fix).

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
INSTALL_SH="$SCRIPT_DIR/install_ansible.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
info() { printf '>>> %s\n' "$*"; }

[ -f "$INSTALL_SH" ] || fail "install_ansible.sh not found at $INSTALL_SH"

WORK=$(mktemp -d) || fail "mktemp -d failed"
trap 'rm -rf "$WORK"' EXIT

SHIMDIR="$WORK/shims"
mkdir -p "$SHIMDIR" || fail "could not create shim dir"

ARGV_LOG="$WORK/argv.log"
export ARGV_LOG

# The scratch path install_ansible_run's presence check targets via
# STAGEHAND_ANSIBLE_BIN — never created by this harness directly. Only a
# "successful" installer stub creates it, simulating a real install
# producing a working ansible-playbook binary.
ANSIBLE_TARGET="$WORK/ansible-playbook"

# make_installer_stub NAME SUCCEED_FLAG_VAR
# Writes a PATH shim for NAME that logs "NAME <argv>" to ARGV_LOG and, only
# if SUCCEED_FLAG_VAR is exported "1", creates+chmods ANSIBLE_TARGET to
# simulate a successful install. Always exits 0 — apt-get/dnf/pip/pipx/wsl
# never fail outright in these tests, they just may or may not "produce" a
# working binary, matching install_ansible.sh's own best-effort/re-check
# idiom.
make_installer_stub() {
  name="$1"
  flag_var="$2"
  cat > "$SHIMDIR/$name" <<SHIM
#!/bin/sh
printf '$name %s\n' "\$*" >> "$ARGV_LOG"
if [ "\${$flag_var:-0}" = "1" ]; then
  : > "$ANSIBLE_TARGET"
  chmod +x "$ANSIBLE_TARGET"
fi
exit 0
SHIM
  chmod +x "$SHIMDIR/$name"
}

make_installer_stub apt-get SHIM_APT_SUCCEED
make_installer_stub dnf SHIM_DNF_SUCCEED
make_installer_stub pip3 SHIM_PIP_SUCCEED
make_installer_stub pip SHIM_PIP_SUCCEED
make_installer_stub pipx SHIM_PIPX_SUCCEED
make_installer_stub wsl SHIM_WSL_SUCCEED

TEST_PATH="$SHIMDIR:/usr/bin:/bin:/usr/sbin:/sbin"

# run_install METHOD — feeds {"install_method": METHOD} via stdin, pointing
# install_ansible.sh's presence check at ANSIBLE_TARGET and forwarding the
# current SHIM_*_SUCCEED flags (regular, possibly-unexported shell vars set
# by each case below) into the subshell's environment.
run_install() {
  method="$1"
  printf '{"install_method": "%s"}' "$method" | \
    PATH="$TEST_PATH" \
    STAGEHAND_ANSIBLE_BIN="$ANSIBLE_TARGET" \
    SHIM_APT_SUCCEED="${SHIM_APT_SUCCEED:-0}" \
    SHIM_DNF_SUCCEED="${SHIM_DNF_SUCCEED:-0}" \
    SHIM_PIP_SUCCEED="${SHIM_PIP_SUCCEED:-0}" \
    SHIM_PIPX_SUCCEED="${SHIM_PIPX_SUCCEED:-0}" \
    SHIM_WSL_SUCCEED="${SHIM_WSL_SUCCEED:-0}" \
    sh "$INSTALL_SH"
}

reset() {
  rm -f "$ANSIBLE_TARGET"
  : > "$ARGV_LOG"
  SHIM_APT_SUCCEED=0
  SHIM_DNF_SUCCEED=0
  SHIM_PIP_SUCCEED=0
  SHIM_PIPX_SUCCEED=0
  SHIM_WSL_SUCCEED=0
}

# --- Case (a): skip, ansible present -> ok, no installer stub invoked. ---
reset
: > "$ANSIBLE_TARGET"
chmod +x "$ANSIBLE_TARGET"
OUT=$(run_install skip)
case "$OUT" in
  *'"method": "skip", "status": "ok"'*) : ;;
  *) fail "case (a) skip+present: expected skip/ok, got: $OUT" ;;
esac
[ -s "$ARGV_LOG" ] && fail "case (a) skip+present: an installer stub was invoked but should not have been. argv log:
$(cat "$ARGV_LOG")"
info "case (a) skip+present: OK (status ok, no installer invoked)"

# --- Case (b): skip, ansible absent -> error. ---
reset
OUT=$(run_install skip)
case "$OUT" in
  *'"method": "skip", "status": "error"'*) : ;;
  *) fail "case (b) skip+absent: expected skip/error, got: $OUT" ;;
esac
info "case (b) skip+absent: OK (status error)"

# --- Case (c): package on a stubbed apt host -> apt-get stub invoked, status ok. ---
reset
SHIM_APT_SUCCEED=1
OUT=$(run_install package)
case "$OUT" in
  *'"method": "package", "status": "ok"'*) : ;;
  *) fail "case (c) package via apt-get: expected package/ok, got: $OUT" ;;
esac
grep -q '^apt-get ' "$ARGV_LOG" || fail "case (c) package via apt-get: apt-get stub was not invoked. argv log:
$(cat "$ARGV_LOG")"
info "case (c) package via apt-get: OK (apt-get stub invoked, status ok)"

# --- Case (d): pip -> pip3 stub invoked, status ok. ---
reset
SHIM_PIP_SUCCEED=1
OUT=$(run_install pip)
case "$OUT" in
  *'"method": "pip", "status": "ok"'*) : ;;
  *) fail "case (d) pip: expected pip/ok, got: $OUT" ;;
esac
grep -Eq '^pip3? ' "$ARGV_LOG" || fail "case (d) pip: pip/pip3 stub was not invoked. argv log:
$(cat "$ARGV_LOG")"
info "case (d) pip: OK (pip3 stub invoked, status ok)"

# --- Case (e): auto, ansible absent, working package stub -> ok via package (pip NOT invoked). ---
reset
SHIM_APT_SUCCEED=1
OUT=$(run_install auto)
case "$OUT" in
  *'"method": "auto", "status": "ok"'*) : ;;
  *) fail "case (e) auto via package: expected auto/ok, got: $OUT" ;;
esac
grep -q '^apt-get ' "$ARGV_LOG" || fail "case (e) auto via package: apt-get stub was not invoked. argv log:
$(cat "$ARGV_LOG")"
grep -Eq '^pip3? ' "$ARGV_LOG" && fail "case (e) auto via package: pip stub was invoked but should not have been (package already succeeded). argv log:
$(cat "$ARGV_LOG")"
info "case (e) auto via package: OK (package succeeded, no pip fallback)"

# --- Case (f): auto, package stub failing -> falls back to pip stub, status ok. ---
reset
SHIM_PIP_SUCCEED=1
OUT=$(run_install auto)
case "$OUT" in
  *'"method": "auto", "status": "ok"'*) : ;;
  *) fail "case (f) auto falls back to pip: expected auto/ok, got: $OUT" ;;
esac
grep -q '^apt-get ' "$ARGV_LOG" || fail "case (f) auto falls back to pip: apt-get stub (attempted, failing) was not invoked. argv log:
$(cat "$ARGV_LOG")"
grep -Eq '^pip3? ' "$ARGV_LOG" || fail "case (f) auto falls back to pip: pip fallback stub was not invoked. argv log:
$(cat "$ARGV_LOG")"
info "case (f) auto falls back to pip: OK (package attempted+failed, pip fallback succeeded)"

# --- Case (g): pipx -> pipx stub invoked, status ok. ---
reset
SHIM_PIPX_SUCCEED=1
OUT=$(run_install pipx)
case "$OUT" in
  *'"method": "pipx", "status": "ok"'*) : ;;
  *) fail "case (g) pipx: expected pipx/ok, got: $OUT" ;;
esac
grep -q '^pipx ' "$ARGV_LOG" || fail "case (g) pipx: pipx stub was not invoked. argv log:
$(cat "$ARGV_LOG")"
info "case (g) pipx: OK (pipx stub invoked, status ok)"

# --- Case (h): wsl, wsl command unavailable -> error, WSL-specific message. ---
reset
rm -f "$SHIMDIR/wsl"
OUT=$(run_install wsl)
case "$OUT" in
  *'"method": "wsl", "status": "error"'*) : ;;
  *) fail "case (h) wsl unavailable: expected wsl/error, got: $OUT" ;;
esac
case "$OUT" in
  *'WSL'*) : ;;
  *) fail "case (h) wsl unavailable: expected a WSL-specific error message, got: $OUT" ;;
esac
info "case (h) wsl unavailable: OK (status error, WSL-specific message)"

# --- Case (i): unknown install_method containing a double-quote and
# backslash -> the catch-all branch's JSON output is still valid, properly
# escaped JSON (WR-02). Calls install_ansible_run directly (sourced in a
# subshell) rather than through run_install/stdin, since the method string
# itself contains characters that would break the test harness's own naive
# stdin-JSON construction — this exercises exactly the code path WR-02
# found: a direct/manual invocation with an arbitrary, unvalidated
# install_method string. ---
reset
UNKNOWN_METHOD='foo"bar\baz'
OUT=$(
  STAGEHAND_SOURCED=1
  export STAGEHAND_SOURCED
  STAGEHAND_ANSIBLE_BIN="$ANSIBLE_TARGET"
  export STAGEHAND_ANSIBLE_BIN
  # shellcheck disable=SC1090
  . "$INSTALL_SH"
  install_ansible_run "$UNKNOWN_METHOD"
)
case "$OUT" in
  *'"status": "error"'*) : ;;
  *) fail "case (i) unknown method with quote: expected status error, got: $OUT" ;;
esac
printf '%s' "$OUT" | ruby -rjson -e 'JSON.parse(STDIN.read)' >/dev/null 2>&1 \
  || fail "case (i) unknown method with quote: emitted fragment is not valid JSON: $OUT"
case "$OUT" in
  *'foo\"bar\\baz'*) : ;;
  *) fail "case (i) unknown method with quote: expected the escaped method string in output, got: $OUT" ;;
esac
info "case (i) unknown method with quote: OK (valid JSON, quote/backslash escaped)"

# --- Case (i2): unknown install_method containing JSON control characters ->
# the catch-all branch preserves the value and still emits valid JSON. ---
reset
UNKNOWN_METHOD=$(printf 'foo\nbar\tqux')
OUT=$(
  STAGEHAND_SOURCED=1
  export STAGEHAND_SOURCED
  STAGEHAND_ANSIBLE_BIN="$ANSIBLE_TARGET"
  export STAGEHAND_ANSIBLE_BIN
  # shellcheck disable=SC1090
  . "$INSTALL_SH"
  install_ansible_run "$UNKNOWN_METHOD"
)
PARSED_METHOD=$(printf '%s' "$OUT" | ruby -rjson -e 'print JSON.parse(STDIN.read).fetch("method")' 2>/dev/null) \
  || fail "case (i2) unknown method with controls: emitted fragment is not valid JSON: $OUT"
[ "$PARSED_METHOD" = "$UNKNOWN_METHOD" ] \
  || fail "case (i2) unknown method with controls: method did not round-trip exactly"
info "case (i2) unknown method with controls: OK (valid JSON, value round-trips)"

# --- Case (i3): the ansible-present fast path must encode arbitrary sourced
# input just as safely as the catch-all branch. ---
reset
: > "$ANSIBLE_TARGET"
chmod +x "$ANSIBLE_TARGET"
PRESENT_METHOD=$(printf 'present"method\nwith\tcontrols\\tail')
OUT=$(
  STAGEHAND_SOURCED=1
  export STAGEHAND_SOURCED
  STAGEHAND_ANSIBLE_BIN="$ANSIBLE_TARGET"
  export STAGEHAND_ANSIBLE_BIN
  # shellcheck disable=SC1090
  . "$INSTALL_SH"
  install_ansible_run "$PRESENT_METHOD"
)
PARSED_METHOD=$(printf '%s' "$OUT" | ruby -rjson -e 'print JSON.parse(STDIN.read).fetch("method")' 2>/dev/null) \
  || fail "case (i3) present fast path: emitted fragment is not valid JSON: $OUT"
[ "$PARSED_METHOD" = "$PRESENT_METHOD" ] \
  || fail "case (i3) present fast path: method did not round-trip exactly"
info "case (i3) present fast path: OK (valid JSON, value round-trips)"

# --- Case (j): STAGEHAND_RUBY_BIN override is honored by the standalone entry
# point's install_method JSON parse. ---
reset
: > "$ANSIBLE_TARGET"
chmod +x "$ANSIBLE_TARGET"
REAL_RUBY=$(command -v ruby) || fail "case (j) ruby override: no real ruby on PATH to wrap"
RUBY_LOG="$WORK/ruby_invoked.log"
cat > "$SHIMDIR/ruby-shim" <<SHIM
#!/bin/sh
printf 'invoked\n' >> "$RUBY_LOG"
exec "$REAL_RUBY" "\$@"
SHIM
chmod +x "$SHIMDIR/ruby-shim"
: > "$RUBY_LOG"
OUT=$(printf '{"install_method": "skip"}' | \
  PATH="$TEST_PATH" \
  STAGEHAND_ANSIBLE_BIN="$ANSIBLE_TARGET" \
  STAGEHAND_RUBY_BIN="$SHIMDIR/ruby-shim" \
  sh "$INSTALL_SH")
[ -s "$RUBY_LOG" ] || fail "case (j) ruby override: STAGEHAND_RUBY_BIN shim was never invoked"
case "$OUT" in
  *'"method": "skip", "status": "ok"'*) : ;;
  *) fail "case (j) ruby override: expected skip/ok via the override, got: $OUT" ;;
esac
info "case (j) ruby override: OK (STAGEHAND_RUBY_BIN honored by the standalone entry point)"

info "all install_ansible strategy cases PASSED"
exit 0
