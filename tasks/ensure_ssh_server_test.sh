#!/bin/sh
# ensure_ssh_server.sh shim-based test harness (47-04-PLAN.md Task 1).
# Follows install_ansible_test.sh's structure: mktemp sandbox, PATH-shimmed
# command/systemctl/package-manager stubs that record their own invocation,
# a curated PATH, exit-code/content assertions.
#
# Cases (see 47-04-PLAN.md Task 1 <acceptance_criteria>):
#   (a) already-present -> {"already_present": true}, exit 0, no package
#       manager stub invoked -- run TWICE to prove no second install attempt
#       (idempotent).
#   (b) successful install via apt-get -> apt-get stub invoked, systemctl
#       enable --now sshd stub invoked, {"installed": true,
#       "package_manager": "apt-get"}.
#   (c) successful install via dnf (a second package manager) -> dnf stub
#       invoked, {"installed": true, "package_manager": "dnf"}.
#   (d) failed install -> the real underlying error text from the failing
#       package-manager stub is surfaced via die(), never a generic message.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
ENSURE_SH="$SCRIPT_DIR/ensure_ssh_server.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
info() { printf '>>> %s\n' "$*"; }

[ -f "$ENSURE_SH" ] || fail "ensure_ssh_server.sh not found at $ENSURE_SH"

WORK=$(mktemp -d) || fail "mktemp -d failed"
trap 'rm -rf "$WORK"' EXIT

SHIMDIR="$WORK/shims"
mkdir -p "$SHIMDIR" || fail "could not create shim dir"

ARGV_LOG="$WORK/argv.log"

# make_pm_stub NAME SUCCEED_FLAG_VAR — writes a PATH shim for a package
# manager (apt-get/dnf/yum/zypper) that logs "NAME <argv>" and either exits 0
# (SUCCEED_FLAG_VAR=1) or exits 1 with a distinguishable "real" error message
# on stdout (captured by ensure_ssh_server.sh's own output redirection into
# its LOG, then surfaced via die()) — proving case (d)'s real-error contract.
make_pm_stub() {
  name="$1"
  flag_var="$2"
  cat > "$SHIMDIR/$name" <<SHIM
#!/bin/sh
printf '$name %s\n' "\$*" >> "$ARGV_LOG"
if [ "\${$flag_var:-0}" = "1" ]; then
  exit 0
fi
printf 'E: Unable to locate package openssh-server (simulated $name failure)\n'
exit 100
SHIM
  chmod +x "$SHIMDIR/$name"
}

make_pm_stub apt-get SHIM_APT_SUCCEED
make_pm_stub dnf SHIM_DNF_SUCCEED
make_pm_stub yum SHIM_YUM_SUCCEED
make_pm_stub zypper SHIM_ZYPPER_SUCCEED

# sshd stub — presence-only signal for "command -v sshd"; never actually
# invoked as a command by ensure_ssh_server.sh.
cat > "$SHIMDIR/sshd" <<'SHIM'
#!/bin/sh
exit 0
SHIM
chmod +x "$SHIMDIR/sshd"

# systemctl stub: `is-active --quiet <unit>` succeeds only when <unit>
# matches SHIM_ACTIVE_UNIT; `enable --now <unit>` logs its invocation and
# succeeds only when <unit> is listed (space-separated) in
# SHIM_ENABLE_OK_UNITS.
cat > "$SHIMDIR/systemctl" <<SHIM
#!/bin/sh
if [ "\$1" = "is-active" ]; then
  unit="\$3"
  [ "\$unit" = "\${SHIM_ACTIVE_UNIT:-}" ] && exit 0
  exit 1
fi
if [ "\$1" = "enable" ]; then
  unit="\$3"
  printf 'systemctl enable --now %s\n' "\$unit" >> "$ARGV_LOG"
  case " \${SHIM_ENABLE_OK_UNITS:-} " in
    *" \$unit "*) exit 0 ;;
  esac
  exit 1
fi
exit 1
SHIM
chmod +x "$SHIMDIR/systemctl"

# Real coreutils ensure_ssh_server.sh needs regardless of which
# package-manager case is under test (mktemp/tail/tr for its LOG/die()
# handling; rm for cleanup). Symlinked into SHIMDIR itself -- rather than
# appending real system dirs (/usr/bin, /bin, ...) to TEST_PATH -- so that
# a case which removes a package-manager stub (e.g. "rm -f
# $SHIMDIR/apt-get" to simulate an apt-get-less host) genuinely makes that
# command unresolvable. Ubuntu/Debian CI runners have a real /usr/bin/
# apt-get; appending system dirs to PATH let it leak through and defeated
# the simulated-absence cases entirely.
for real_bin in sh mktemp tail tr rm; do
  real_path=$(command -v "$real_bin") || fail "required real binary not found: $real_bin"
  ln -s "$real_path" "$SHIMDIR/$real_bin" || fail "could not symlink $real_bin into shim dir"
done

TEST_PATH="$SHIMDIR"

run() {
  PATH="$TEST_PATH" \
    SHIM_APT_SUCCEED="${SHIM_APT_SUCCEED:-0}" \
    SHIM_DNF_SUCCEED="${SHIM_DNF_SUCCEED:-0}" \
    SHIM_YUM_SUCCEED="${SHIM_YUM_SUCCEED:-0}" \
    SHIM_ZYPPER_SUCCEED="${SHIM_ZYPPER_SUCCEED:-0}" \
    SHIM_ACTIVE_UNIT="${SHIM_ACTIVE_UNIT:-}" \
    SHIM_ENABLE_OK_UNITS="${SHIM_ENABLE_OK_UNITS:-}" \
    sh "$ENSURE_SH"
}

reset() {
  : > "$ARGV_LOG"
  SHIM_APT_SUCCEED=0
  SHIM_DNF_SUCCEED=0
  SHIM_YUM_SUCCEED=0
  SHIM_ZYPPER_SUCCEED=0
  SHIM_ACTIVE_UNIT=""
  SHIM_ENABLE_OK_UNITS=""
}

# --- Case (a): already-present. sshd on PATH, systemctl reports sshd active.
# Run TWICE to prove idempotent -- no package-manager stub invoked either
# time. ---
reset
SHIM_ACTIVE_UNIT="sshd"
OUT1=$(run) || fail "case (a) already-present (run 1): ensure_ssh_server.sh exited non-zero. Output:
$OUT1"
[ "$OUT1" = '{"already_present": true}' ] || fail "case (a) already-present (run 1): expected the exact no-op signal, got:
$OUT1"
OUT2=$(run) || fail "case (a) already-present (run 2): ensure_ssh_server.sh exited non-zero. Output:
$OUT2"
[ "$OUT2" = '{"already_present": true}' ] || fail "case (a) already-present (run 2): expected the exact no-op signal, got:
$OUT2"
[ -s "$ARGV_LOG" ] && fail "case (a) already-present: a package-manager/enable stub was invoked across two runs but should never have been. argv log:
$(cat "$ARGV_LOG")"
info "case (a) already-present: OK (no-op both runs, no install attempted -- idempotent)"

# --- Case (b): successful install via apt-get. Not already active; apt-get
# succeeds; systemctl enable --now sshd succeeds. ---
reset
SHIM_APT_SUCCEED=1
SHIM_ENABLE_OK_UNITS="sshd"
OUT=$(run) || fail "case (b) apt-get install: ensure_ssh_server.sh exited non-zero. Output:
$OUT"
[ "$OUT" = '{"already_present": false, "installed": true, "package_manager": "apt-get"}' ] ||
  fail "case (b) apt-get install: unexpected output:
$OUT"
grep -q '^apt-get ' "$ARGV_LOG" || fail "case (b) apt-get install: apt-get stub was not invoked. argv log:
$(cat "$ARGV_LOG")"
grep -q '^systemctl enable --now sshd$' "$ARGV_LOG" || fail "case (b) apt-get install: systemctl enable --now sshd was not invoked. argv log:
$(cat "$ARGV_LOG")"
info "case (b) apt-get install: OK (apt-get + systemctl enable --now sshd invoked, installed: true)"

# --- Case (c): successful install via dnf (a second package manager -- proves
# detection isn't hardcoded to apt-get). apt-get stub still present on PATH
# but must NOT be preferred once we simulate an apt-get-less host by removing
# the apt-get stub for this case. ---
reset
rm -f "$SHIMDIR/apt-get"
SHIM_DNF_SUCCEED=1
SHIM_ENABLE_OK_UNITS="sshd"
OUT=$(run) || fail "case (c) dnf install: ensure_ssh_server.sh exited non-zero. Output:
$OUT"
[ "$OUT" = '{"already_present": false, "installed": true, "package_manager": "dnf"}' ] ||
  fail "case (c) dnf install: unexpected output:
$OUT"
grep -q '^dnf ' "$ARGV_LOG" || fail "case (c) dnf install: dnf stub was not invoked. argv log:
$(cat "$ARGV_LOG")"
info "case (c) dnf install: OK (dnf + systemctl enable --now sshd invoked, installed: true)"
# restore apt-get stub for subsequent cases
make_pm_stub apt-get SHIM_APT_SUCCEED

# --- Case (d): failed install -- apt-get stub exits non-zero with a real,
# distinguishable error message; ensure_ssh_server.sh must surface that real
# text via die(), never a generic "failed" string. ---
reset
OUT=$(run 2>&1 1>/dev/null)
STATUS=$?
[ $STATUS -ne 0 ] || fail "case (d) failed install: expected a non-zero exit, got 0. Output:
$OUT"
case "$OUT" in
  *"ERROR:"*"openssh-server install via apt-get failed"*"Unable to locate package openssh-server"*) : ;;
  *) fail "case (d) failed install: expected the real underlying apt-get error text surfaced via die(), got:
$OUT" ;;
esac
info "case (d) failed install: OK (real underlying error surfaced, not a generic failure string)"

info "all ensure_ssh_server safety cases PASSED"
exit 0
