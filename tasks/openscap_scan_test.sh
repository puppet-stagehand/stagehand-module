#!/bin/sh
# stagehand::openscap_scan test harness (999.12-02-PLAN.md Task 2).
# New coverage: openscap_scan.sh arrived in this phase with zero test
# coverage. Follows patch_test.sh's env -i + PATH-shim invocation pattern
# and trivy_scan_checksum_test.sh's install-sentinel structure.
#
# Cases:
#   (1) install unset (default false), oscap absent -> die() (non-zero
#       exit, the "oscap not installed" message), and the distro-native
#       install branch NEVER runs (no package-manager invocation).
#   (2) install=true, oscap absent, apt-get stub present -> the
#       distro-native install branch actually runs (apt-get invoked). The
#       script may still fail further downstream (this machine has no real
#       SCAP datastream) -- out of scope for this test, which only proves
#       the install branch is reachable and correctly gated on the task's
#       install parameter.
#
# This test is intentionally RED against a deliberately broken copy of
# openscap_scan.sh with the `if [ "$INSTALL" = "true" ]` gate removed (see
# 999.12-02-SUMMARY.md for the observed failing run).

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
TARGET_SH="$SCRIPT_DIR/openscap_scan.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
info() { printf '>>> %s\n' "$*"; }

[ -f "$TARGET_SH" ] || fail "openscap_scan.sh not found at $TARGET_SH"
command -v python3 >/dev/null 2>&1 || fail "python3 is required to run this test harness"

WORK=$(mktemp -d) || fail "mktemp -d failed"
trap 'rm -rf "$WORK"' EXIT

SHIMDIR="$WORK/shims"
mkdir -p "$SHIMDIR" || fail "could not create shim dir"

# Fake $PT__installdir/stagehand/files/scan-report.sh so the adapter
# existence check passes and the script proceeds to the install-gate logic
# under test.
mkdir -p "$WORK/installdir/stagehand/files"
: > "$WORK/installdir/stagehand/files/scan-report.sh"

INSTALL_SENTINEL="$WORK/apt-get-called"

# apt-get shim: records that it was invoked (any args), then exits 0 so
# the install branch's own error handling never masks the invocation.
cat > "$SHIMDIR/apt-get" <<SHIM
#!/bin/sh
: > "$INSTALL_SENTINEL"
exit 0
SHIM
chmod +x "$SHIMDIR/apt-get"

REAL_PYTHON3=$(command -v python3) || fail "no real python3 to link into the shim PATH"
ln -s "$REAL_PYTHON3" "$SHIMDIR/python3" || fail "could not symlink python3 into the shim PATH"

# Curated PATH: shim dir first, then a minimal real-tool set. Deliberately
# excludes any real oscap (this dev machine has none anyway) so
# "command -v oscap" always forces the install-gate branch under test, and
# excludes dnf/yum so only the apt-get leg of the distro-native branch is
# reachable here.
TEST_PATH="$SHIMDIR:/usr/bin:/bin"

reset() { rm -f "$INSTALL_SENTINEL"; }

run_case() {
  # shellcheck disable=SC2086
  env -i \
    PATH="$TEST_PATH" \
    HOME="$HOME" \
    PT_console_url="http://example.invalid" \
    PT__installdir="$WORK/installdir" \
    ${PT_install:+PT_install="$PT_install"} \
    sh "$TARGET_SH"
  printf '%s' "$?"
}

# --- Case 1: install unset (default false), oscap absent -> die(), no
# install attempted. ---
reset
unset PT_install
RC=$(run_case 2>"$WORK/stderr.1")
[ "$RC" != "0" ] || fail "case 1 (install unset): expected non-zero exit, got 0"
[ -f "$INSTALL_SENTINEL" ] && fail "case 1 (install unset): expected NO install, but apt-get was invoked"
grep -q 'oscap not installed' "$WORK/stderr.1" \
  || fail "case 1 (install unset): expected the 'oscap not installed' die message, got: $(cat "$WORK/stderr.1")"
info "case 1 (install unset): OK (die(), no install attempted)"

# --- Case 2: install=true, oscap absent, apt-get stub present -> the
# distro-native install branch actually runs. ---
reset
PT_install=true
RC=$(run_case 2>"$WORK/stderr.2")
[ -f "$INSTALL_SENTINEL" ] \
  || fail "case 2 (install=true): expected the install branch to run (apt-get invoked), but it did not. exit=$RC stderr: $(cat "$WORK/stderr.2")"
info "case 2 (install=true): OK (install branch reached, apt-get invoked; exit=$RC past this point is out of scope)"

info "all openscap install-gate cases PASSED"
exit 0
