#!/bin/sh
# Stagehand scanner lifecycle. The marker is the sole removal authority: a
# pre-existing executable/package is external and is never overwritten,
# claimed, or removed.
set -eu

SCANNER=${PT_scanner:-}
ACTION=${PT_action:-}
INSTANCE=${PT_console_instance:-}
STATE_DIR=/var/lib/stagehand/scanners
MARKER=$STATE_DIR/$SCANNER.json
TRIVY_VERSION=0.72.0

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
has_scanner() {
  case "$SCANNER" in
    trivy) command -v trivy >/dev/null 2>&1 ;;
    openscap) command -v oscap >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}
owned_here() {
  [ -f "$MARKER" ] || return 1
  managed_by=$(sed -n 's/.*"console_instance":"\([^"]*\)".*/\1/p' "$MARKER")
  [ -n "$managed_by" ] && [ "$managed_by" = "$INSTANCE" ]
}
version() {
  case "$SCANNER" in
    trivy) trivy --version 2>/dev/null | awk 'NR==1{print $2}' ;;
    openscap) oscap --version 2>/dev/null | awk 'NR==1{print $NF}' ;;
  esac
}
report() {
  present=false; has_scanner && present=true
  ownership=none; owned_here && ownership=stagehand
  if [ "$present" = true ] && [ "$ownership" = none ]; then ownership=external; fi
  marker_json={}; [ -f "$MARKER" ] && marker_json=$(cat "$MARKER")
  printf '{"scanner":"%s","action":"%s","present":%s,"ownership":"%s","version":"%s","ownership_marker":%s}\n' \
    "$SCANNER" "$ACTION" "$present" "$ownership" "$(version || true)" "$marker_json"
}
write_marker() {
  mkdir -p "$STATE_DIR"
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  tmp=$MARKER.tmp.$$
  printf '{"component":"%s","version":"%s","install_method":"stagehand-lifecycle","paths_packages":"%s","installed_at":"%s","console_instance":"%s"}\n' \
    "$SCANNER" "$(version)" "$1" "$now" "$INSTANCE" > "$tmp"
  chmod 0600 "$tmp"
  mv "$tmp" "$MARKER"
}

[ "$SCANNER" = trivy ] || [ "$SCANNER" = openscap ] || die 'scanner must be trivy or openscap'
[ "$ACTION" = inspect ] || [ "$ACTION" = install ] || [ "$ACTION" = upgrade ] || [ "$ACTION" = uninstall ] || die 'invalid action'
[ -n "$INSTANCE" ] || die 'console_instance is required'

if [ "$ACTION" = inspect ]; then report; exit 0; fi

if [ "$ACTION" = uninstall ]; then
  # External and absent installations are deliberately successful no-ops.
  owned_here || { report; exit 0; }
  case "$SCANNER" in
    trivy) rm -f /usr/local/bin/trivy ;;
    openscap)
      if command -v dnf >/dev/null 2>&1; then dnf -y remove openscap-scanner scap-security-guide
      elif command -v apt-get >/dev/null 2>&1; then apt-get -y remove libopenscap8 openscap-scanner ssg-base
      else die 'no supported package manager'; fi ;;
  esac
  rm -f "$MARKER"
  report
  exit 0
fi

# Never claim or overwrite a pre-existing scanner.
if has_scanner && ! owned_here; then report; exit 0; fi

case "$SCANNER" in
  trivy)
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    asset=trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz
    base=https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}
    curl -fsSL "$base/$asset" -o "$tmp/$asset"
    curl -fsSL "$base/trivy_${TRIVY_VERSION}_checksums.txt" -o "$tmp/checksums.txt"
    expected=$(awk -v asset="$asset" '$2==asset {print $1}' "$tmp/checksums.txt")
    [ -n "$expected" ] || die 'pinned Trivy checksum missing'
    actual=$(sha256sum "$tmp/$asset" | awk '{print $1}')
    [ "$actual" = "$expected" ] || die 'Trivy checksum mismatch'
    tar -xzf "$tmp/$asset" -C "$tmp" trivy
    install -m 0755 "$tmp/trivy" /usr/local/bin/trivy
    write_marker /usr/local/bin/trivy
    ;;
  openscap)
    # The installer owns the platform-specific exact package lock. Refuse an
    # unconstrained repository install when that lock is absent.
    lock=/var/lib/stagehand/platform-lock/openscap.version
    [ -s "$lock" ] || die 'OpenSCAP platform lock is missing'
    pinned=$(sed -n '1p' "$lock")
    case "$pinned" in *[!A-Za-z0-9._:+~-]*|'') die 'invalid OpenSCAP package lock' ;; esac
    if command -v dnf >/dev/null 2>&1; then
      dnf -y install "openscap-scanner-$pinned" "scap-security-guide-$pinned"
      write_marker "openscap-scanner-$pinned,scap-security-guide-$pinned"
    elif command -v apt-get >/dev/null 2>&1; then
      apt-get update
      apt-get -y install "libopenscap8=$pinned" "openscap-scanner=$pinned" "ssg-base=$pinned"
      write_marker "libopenscap8=$pinned,openscap-scanner=$pinned,ssg-base=$pinned"
    else die 'no supported package manager'; fi
    ;;
esac
report
