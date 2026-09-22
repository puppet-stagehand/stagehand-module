#!/bin/sh
# stagehand::inspector_scan test harness (999.12-02-PLAN.md Task 2).
# New coverage: inspector_scan.sh arrived in this phase with zero test
# coverage, and it is the one script this phase can never let regain an
# install path -- puppet-inspector has no release channel to pin a
# checksum against (RESEARCH.md Finding 7), so a fetch-and-execute install
# here would be exactly the unpinned supply-chain hole the module's own
# gate exists to reject.
#
# Cases:
#   (1) static: the script contains no fetch-and-execute install pattern
#       (no `curl ... | sh`/`| bash`, no distro package-manager install
#       invocation, no PT_install parameter reference at all) -- this is
#       the enforceable form of the accepted limit.
#   (2) static: the script's own header still documents the limit in
#       prose ("Does NOT install" / "pre-alpha").
#   (3) runtime: puppet-inspector absent from the configured path -> die()
#       (non-zero exit) with the "this task does not install it" message,
#       never a silent install-then-continue.
#
# This test is intentionally RED against a deliberately modified copy of
# inspector_scan.sh with a `curl ... | sh` install branch added (see
# 999.12-02-SUMMARY.md for the observed failing run).

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
TARGET_SH="$SCRIPT_DIR/inspector_scan.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
info() { printf '>>> %s\n' "$*"; }

[ -f "$TARGET_SH" ] || fail "inspector_scan.sh not found at $TARGET_SH"

# --- Case 1: no fetch-and-execute install pattern anywhere in the script. ---
if grep -qE '\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash)\b' "$TARGET_SH"; then
  fail "case 1 (no fetch-and-execute): found a pipe-into-shell pattern in $TARGET_SH -- puppet-inspector has no release channel to pin a checksum against"
fi
if grep -qE '(apt-get|dnf|yum)[[:space:]]+(-y[[:space:]]+)?install' "$TARGET_SH"; then
  fail "case 1 (no fetch-and-execute): found a package-manager install invocation in $TARGET_SH -- puppet-inspector has no packaged release to install"
fi
if grep -q 'PT_install' "$TARGET_SH"; then
  fail "case 1 (no fetch-and-execute): found a PT_install parameter reference in $TARGET_SH -- this task must never grow an install path"
fi
info "case 1 (no fetch-and-execute): OK (no pipe-to-shell, no package-manager install, no PT_install)"

# --- Case 2: the accepted-limit rationale is still documented in the
# script's own header. ---
grep -q 'Does NOT install puppet-inspector' "$TARGET_SH" \
  || fail "case 2 (documented limit): header no longer states the tool is not installed by this task"
grep -q 'pre-alpha' "$TARGET_SH" \
  || fail "case 2 (documented limit): header no longer explains puppet-inspector is pre-alpha"
info "case 2 (documented limit): OK (header still documents the accepted limit)"

# --- Case 3: puppet-inspector absent -> die() with the no-install message,
# never a silent install-then-continue. ---
WORK=$(mktemp -d) || fail "mktemp -d failed"
trap 'rm -rf "$WORK"' EXIT

PROFILE="$WORK/profile.yaml"
printf 'profile: fixture\n' > "$PROFILE"

OUT=$(env -i \
  PATH="/usr/bin:/bin" \
  HOME="$HOME" \
  PT_console_url="http://example.invalid" \
  PT_profile="$PROFILE" \
  PT_inspector_path="$WORK/no-such-inspector-binary" \
  sh "$TARGET_SH" 2>"$WORK/stderr.3")
RC=$?
[ "$RC" != "0" ] || fail "case 3 (inspector absent): expected non-zero exit, got 0. stdout: $OUT"
grep -q 'this task does not install it' "$WORK/stderr.3" \
  || fail "case 3 (inspector absent): expected the no-install die message, got: $(cat "$WORK/stderr.3")"
info "case 3 (inspector absent): OK (die(), no install attempted)"

info "all inspector no-install-path cases PASSED"
exit 0
