#!/bin/sh
# stagehand::inspector_scan — run a Puppet Inspector profile against this node,
# normalize the native JSON report to compliance.v1 with the bundled
# adapter, and POST to the console. Self-contained: the adapter ships via
# metadata "files" ($PT__installdir).
#
# Does NOT install puppet-inspector: the tool is pre-alpha with no published
# release/package yet (checked docs/DESIGN.md, README.md this session -- no
# release channel exists to pin a checksum against, unlike trivy/openscap),
# so unlike stagehand::trivy_scan or stagehand::openscap_scan this task has no
# install=true path. The binary must already be on the target.
set -u

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

CONSOLE="${PT_console_url:-}"
TOKEN="${PT_ingest_token:-}"
PROFILE="${PT_profile:-}"
INSPECTOR="${PT_inspector_path:-/usr/local/bin/puppet-inspector}"

[ -n "$CONSOLE" ] || die "console_url is required"
[ -n "$PROFILE" ] || die "profile is required"
[ -r "$PROFILE" ] || die "profile not found or not readable: $PROFILE"
command -v "$INSPECTOR" >/dev/null 2>&1 || die "puppet-inspector not found at $INSPECTOR (this task does not install it -- pre-alpha, no release channel yet)"

INSTALLDIR="${PT__installdir:-}"
ADAPTER="${INSTALLDIR}/stagehand/files/inspector-report.sh"
[ -f "$ADAPTER" ] || die "inspector-report adapter not found at $ADAPTER"
command -v python3 >/dev/null 2>&1 || die "python3 is required on the target for the inspector adapter"

TOOL_VERSION=$("$INSPECTOR" --version 2>/dev/null | head -1)

REPORT=$(mktemp) || die "mktemp failed"
trap 'rm -f "$REPORT"' EXIT

printf '>>> puppet-inspector exec --local --format json %s\n' "$PROFILE"
"$INSPECTOR" exec --local --format json "$PROFILE" > "$REPORT" 2>/dev/null || true
[ -s "$REPORT" ] || die "puppet-inspector produced no report (check the profile path and target facts)"

BATCH=$(bash "$ADAPTER" --report "$REPORT" --tool-version "$TOOL_VERSION") || die "adapter normalization failed"

if [ -n "$TOKEN" ]; then
  printf '%s' "$BATCH" | curl -sf -X POST "$CONSOLE/api/v1/compliance/results" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' --data-binary @- >/dev/null \
    || die "POST to console failed"
else
  printf '%s' "$BATCH" | curl -sf -X POST "$CONSOLE/api/v1/compliance/results" \
    -H 'Content-Type: application/json' --data-binary @- >/dev/null \
    || die "POST to console failed"
fi

CERT=$(/opt/puppetlabs/bin/puppet config print certname 2>/dev/null || hostname -f 2>/dev/null || hostname)
printf '{"status": "scanned", "scanner": "puppet-inspector", "certname": "%s"}\n' "$CERT"
