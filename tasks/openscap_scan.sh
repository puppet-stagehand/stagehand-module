#!/bin/sh
# stagehand::openscap_scan — evaluate a node with OpenSCAP, normalize to
# compliance.v1 with the bundled adapter, and POST to the console.
# Self-contained: the adapter ships via metadata "files" ($PT__installdir).
set -u

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

CONSOLE="${PT_console_url:-}"
TOKEN="${PT_ingest_token:-}"
PROFILE="${PT_profile:-xccdf_org.ssgproject.content_profile_standard}"
DATASTREAM="${PT_datastream:-}"
INSTALL="${PT_install:-false}"

[ -n "$CONSOLE" ] || die "console_url is required"

INSTALLDIR="${PT__installdir:-}"
ADAPTER="${INSTALLDIR}/stagehand/files/scan-report.sh"
[ -f "$ADAPTER" ] || die "scan-report adapter not found at $ADAPTER"
command -v python3 >/dev/null 2>&1 || die "python3 is required on the target for the openscap adapter"

if ! command -v oscap >/dev/null 2>&1; then
  if [ "$INSTALL" = "true" ]; then
    printf '>>> installing openscap-scanner + scap-security-guide\n'
    if command -v apt-get >/dev/null 2>&1; then
      apt-get -qq update && apt-get -y install openscap-scanner ssg-debian ssg-debderived >/dev/null 2>&1 \
        || apt-get -y install openscap-scanner >/dev/null 2>&1 || die "openscap install failed"
    elif command -v dnf >/dev/null 2>&1; then
      dnf -y install openscap-scanner scap-security-guide >/dev/null 2>&1 || die "openscap install failed"
    elif command -v yum >/dev/null 2>&1; then
      yum -y install openscap-scanner scap-security-guide >/dev/null 2>&1 || die "openscap install failed"
    else
      die "no supported package manager to install openscap"
    fi
  else
    die "oscap not installed (pass install=true to auto-install)"
  fi
fi

# Resolve a datastream if one wasn't given: pick the first SSG ds on disk.
if [ -z "$DATASTREAM" ]; then
  for cand in /usr/share/xml/scap/ssg/content/ssg-*-ds.xml; do
    [ -e "$cand" ] && DATASTREAM="$cand" && break
  done
fi
[ -n "$DATASTREAM" ] && [ -r "$DATASTREAM" ] || die "no readable SCAP datastream (pass datastream=<path>)"

CERT=$(/opt/puppetlabs/bin/puppet config print certname 2>/dev/null || hostname -f 2>/dev/null || hostname)
ARF=$(mktemp) || die "mktemp failed"
trap 'rm -f "$ARF"' EXIT

printf '>>> oscap xccdf eval --profile %s %s\n' "$PROFILE" "$DATASTREAM"
# oscap exits 2 when any rule fails — that is expected, hence the guard.
oscap xccdf eval --profile "$PROFILE" --results-arf "$ARF" "$DATASTREAM" >/dev/null 2>&1 || true
[ -s "$ARF" ] || die "oscap produced no results (check the profile id and datastream)"

BATCH=$(bash "$ADAPTER" --arf "$ARF" --certname "$CERT") || die "adapter normalization failed"

if [ -n "$TOKEN" ]; then
  printf '%s' "$BATCH" | curl -sf -X POST "$CONSOLE/api/v1/compliance/results" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' --data-binary @- >/dev/null \
    || die "POST to console failed"
else
  printf '%s' "$BATCH" | curl -sf -X POST "$CONSOLE/api/v1/compliance/results" \
    -H 'Content-Type: application/json' --data-binary @- >/dev/null \
    || die "POST to console failed"
fi

printf '{"status": "scanned", "scanner": "openscap", "certname": "%s"}\n' "$CERT"
