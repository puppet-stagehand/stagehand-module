#!/bin/sh
# Fail-closed checksum verification test for trivy_scan.sh (FND-09).
#
# POSIX sh, no bats dependency (this repo has no shell test harness). Builds a
# temp sandbox with PATH shims that intercept trivy_scan.sh's network + install
# side effects (curl, tar, install) so the test runs without touching the real
# network or /usr/local/bin. Uses the REAL sha256sum so the match case is
# genuine. The shimmed PATH deliberately excludes any ambient trivy install
# (e.g. Homebrew's /opt/homebrew/bin/trivy) so "command -v trivy" always
# forces the install branch under test.
#
# Reads the pinned TRIVY_VERSION out of trivy_scan.sh so the fixture asset
# name stays in sync with whatever version is actually pinned.
#
# Runs trivy_scan.sh three times against controlled checksums.txt content:
#   (a) match         -> checksums.txt carries the fixture's real sha256 for
#                         the pinned asset. Expect the install step to run
#                         (install sentinel present). The script may still
#                         exit non-zero further downstream (no real trivy
#                         binary is materialized on PATH, so the later
#                         "trivy rootfs" scan step legitimately fails) -- that
#                         is out of scope for this test, which only asserts
#                         the checksum-gated install actually happened.
#   (b) mismatch      -> checksums.txt carries a WRONG sha256 for the pinned
#                         asset. Expect die() (non-zero exit) and NO install.
#   (c) missing entry -> checksums.txt has no line for the pinned asset name.
#                         Expect die() (non-zero exit) and NO install.
#
# This test is intentionally RED against the current unpinned trivy_scan.sh
# (no TRIVY_VERSION pin, no checksum logic exists yet).

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
TRIVY_SCAN="$SCRIPT_DIR/trivy_scan.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
info() { printf '>>> %s\n' "$*"; }

[ -f "$TRIVY_SCAN" ] || fail "trivy_scan.sh not found at $TRIVY_SCAN"

# --- Extract the pinned version so the fixture asset name stays in sync ---
TRIVY_VERSION=$(grep -m1 '^TRIVY_VERSION=' "$TRIVY_SCAN" | sed -E 's/^TRIVY_VERSION="?([^"]*)"?.*/\1/')
[ -n "$TRIVY_VERSION" ] || fail "could not read a pinned TRIVY_VERSION out of trivy_scan.sh (expected a line like TRIVY_VERSION=\"0.72.0\")"
info "testing against pinned TRIVY_VERSION=$TRIVY_VERSION"

TRIVY_ASSET="trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"

WORK=$(mktemp -d) || fail "mktemp -d failed"
trap 'rm -rf "$WORK"' EXIT

SHIMDIR="$WORK/shims"
mkdir -p "$SHIMDIR" || fail "could not create shim dir"

# Fake $PT__installdir/stagehand/files/trivy-report.sh so trivy_scan.sh's adapter
# existence check passes and we can reach the install branch under test.
mkdir -p "$WORK/installdir/stagehand/files"
: > "$WORK/installdir/stagehand/files/trivy-report.sh"

# Fixture tarball. Its content is irrelevant -- tar itself is shimmed below --
# only its sha256 (computed with the REAL sha256sum) matters, so the match
# case is a genuine checksum comparison, not a stubbed-out one.
FIXTURE="$WORK/fixture.tar.gz"
printf 'fixture trivy tarball contents\n' > "$FIXTURE"
FIXTURE_SHA=$(sha256sum "$FIXTURE" | awk '{print $1}')
[ -n "$FIXTURE_SHA" ] || fail "could not compute the fixture's sha256 (is sha256sum on PATH?)"

# A genuinely different, but still well-formed, sha256 for the mismatch case.
WRONG_SHA=$(printf 'wrong-checksum-fixture' | sha256sum | awk '{print $1}')
[ -n "$WRONG_SHA" ] && [ "$WRONG_SHA" != "$FIXTURE_SHA" ] || fail "could not derive a distinct wrong sha256 for the mismatch case"

INSTALL_SENTINEL="$WORK/install-called"

# --- curl shim: serves the fixture tarball for the asset URL, and a
# caller-controlled checksums.txt for the checksums URL. ---
cat > "$SHIMDIR/curl" <<'SHIM'
#!/bin/sh
url=""
outpath=""
prev=""
for arg in "$@"; do
  case "$prev" in
    -o) outpath="$arg" ;;
  esac
  case "$arg" in
    http*) url="$arg" ;;
  esac
  prev="$arg"
done
if [ -z "$outpath" ]; then
  echo "curl shim: no -o target parsed from: $*" >&2
  exit 2
fi
case "$url" in
  *checksums.txt)
    if [ ! -f "${SHIM_CHECKSUMS_FILE:-}" ]; then
      echo "curl shim: SHIM_CHECKSUMS_FILE not set or missing" >&2
      exit 2
    fi
    cp "$SHIM_CHECKSUMS_FILE" "$outpath"
    ;;
  *)
    if [ ! -f "${SHIM_FIXTURE_TARBALL:-}" ]; then
      echo "curl shim: SHIM_FIXTURE_TARBALL not set or missing" >&2
      exit 2
    fi
    cp "$SHIM_FIXTURE_TARBALL" "$outpath"
    ;;
esac
SHIM
chmod +x "$SHIMDIR/curl"

# --- tar shim: ignores the (fixture) archive content entirely and just
# materializes a dummy "trivy" file in the -C target directory. ---
cat > "$SHIMDIR/tar" <<'SHIM'
#!/bin/sh
dir="."
prev=""
for arg in "$@"; do
  case "$prev" in
    -C) dir="$arg" ;;
  esac
  prev="$arg"
done
printf '#!/bin/sh\necho dummy trivy\n' > "$dir/trivy"
chmod +x "$dir/trivy"
SHIM
chmod +x "$SHIMDIR/tar"

# --- install shim: records that it was called instead of touching the real
# /usr/local/bin. ---
cat > "$SHIMDIR/install" <<'SHIM'
#!/bin/sh
: > "${SHIM_INSTALL_SENTINEL:?SHIM_INSTALL_SENTINEL not set}"
SHIM
chmod +x "$SHIMDIR/install"

# Curated PATH: shim dir first, then a minimal real-tool set. Deliberately
# excludes /opt/homebrew/bin, /usr/local/bin, and any other developer-machine
# location a real trivy binary might live -- otherwise "command -v trivy"
# could find a real install and skip the install branch entirely, silently
# passing this test for the wrong reason.
TEST_PATH="$SHIMDIR:/usr/bin:/bin:/sbin:/usr/sbin"

run_case() {
  # $1 = checksums.txt content, $2 = case name -> prints exit code to stdout
  content="$1"
  case_name="$2"
  checksums_file="$WORK/checksums-$case_name.txt"
  printf '%s\n' "$content" > "$checksums_file"

  rm -f "$INSTALL_SENTINEL"

  PATH="$TEST_PATH" \
    SHIM_FIXTURE_TARBALL="$FIXTURE" \
    SHIM_CHECKSUMS_FILE="$checksums_file" \
    SHIM_INSTALL_SENTINEL="$INSTALL_SENTINEL" \
    PT_console_url="http://example.invalid" \
    PT_install=true \
    PT__installdir="$WORK/installdir" \
    sh "$TRIVY_SCAN" >"$WORK/out-$case_name.log" 2>&1
  printf '%s' "$?"
}

# --- Case (a): match -> install expected to run. ---
MATCH_CHECKSUMS="$FIXTURE_SHA  $TRIVY_ASSET"
RC=$(run_case "$MATCH_CHECKSUMS" "match")
if [ ! -f "$INSTALL_SENTINEL" ]; then
  fail "case (a) match: expected the install step to run (sentinel present), but it did not (exit=$RC). Log:
$(cat "$WORK/out-match.log")"
fi
info "case (a) match: OK (install ran, script exit=$RC)"

# --- Case (b): checksum mismatch -> die(), no install, non-zero exit. ---
MISMATCH_CHECKSUMS="$WRONG_SHA  $TRIVY_ASSET"
RC=$(run_case "$MISMATCH_CHECKSUMS" "mismatch")
if [ "$RC" = "0" ]; then
  fail "case (b) mismatch: expected a non-zero exit, got 0. Log:
$(cat "$WORK/out-mismatch.log")"
fi
if [ -f "$INSTALL_SENTINEL" ]; then
  fail "case (b) mismatch: expected NO install, but the install sentinel is present"
fi
info "case (b) mismatch: OK (exit=$RC, no install)"

# --- Case (c): no checksums.txt entry for the pinned asset -> die(), no
# install, non-zero exit. ---
MISSING_CHECKSUMS="$FIXTURE_SHA  some-other-asset.tar.gz"
RC=$(run_case "$MISSING_CHECKSUMS" "missing")
if [ "$RC" = "0" ]; then
  fail "case (c) missing-entry: expected a non-zero exit, got 0. Log:
$(cat "$WORK/out-missing.log")"
fi
if [ -f "$INSTALL_SENTINEL" ]; then
  fail "case (c) missing-entry: expected NO install, but the install sentinel is present"
fi
info "case (c) missing-entry: OK (exit=$RC, no install)"

info "all checksum fail-closed cases PASSED"
exit 0
