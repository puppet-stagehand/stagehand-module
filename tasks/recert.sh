#!/bin/sh
# stagehand::recert — one-time re-certification of an existing node so
# identity extensions (team, datacenter, …) get burned into a fresh cert.
# Ships as a Bolt task in the puppet_core module (staged here per the
# adapters convention). Contract: docs/design/roles-profiles.md §trusted
# identity. The console has ALREADY revoked+cleaned the old cert and minted
# a single-use, certname-bound autosign authorization before this runs.
#
# Task params (env, per Bolt input_method environment):
#   PT_challenge   the one-time autosign challenge (jti)
#   PT_ext_*       identity extensions minus the pp_ prefix
#                  (PT_ext_department=finance → pp_department: "finance")
set -u

say() { printf '>>> %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
fail_json() { printf '{"status": "error", "error": "%s"}\n' "$*"; exit 0; }

# STAGEHAND_RECERT_PUPPET_BIN exists solely so recert_test.sh can point this
# script at a stub puppet binary on a curated PATH (mirroring
# STAGEHAND_DISCOVER_PUPPET_BIN's convention in discover.sh). It is NEVER a
# Bolt PT_ param.
PUPPET="${STAGEHAND_RECERT_PUPPET_BIN:-/opt/puppetlabs/bin/puppet}"
[ -x "$PUPPET" ] || die "puppet agent not installed at $PUPPET"
[ -n "${PT_challenge:-}" ] || die "challenge parameter is required"

CONFDIR=$("$PUPPET" config print confdir)
SSLDIR=$("$PUPPET" config print ssldir)
STAMP=$(date +%Y%m%d%H%M%S)

# 1. csr_attributes: one-time challenge + identity extensions.
say "writing csr_attributes.yaml (challenge + identity extensions)"
{
  printf 'custom_attributes:\n'
  printf '  1.2.840.113549.1.9.7: "%s"\n' "$PT_challenge"
  FOUND_EXT=0
  for var in $(env | grep '^PT_ext_' | cut -d= -f1); do
    [ "$FOUND_EXT" = 0 ] && printf 'extension_requests:\n' && FOUND_EXT=1
    key="pp_${var#PT_ext_}"
    val=$(printenv "$var" | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '  %s: "%s"\n' "$key" "$val"
  done
} > "${CONFDIR}/csr_attributes.yaml"
chmod 640 "${CONFDIR}/csr_attributes.yaml"

# 2. Move the old SSL state aside (backup, never delete — rollback = move back).
say "backing up ${SSLDIR} -> ${SSLDIR}.recert-${STAMP}"
mv "$SSLDIR" "${SSLDIR}.recert-${STAMP}" || fail_json "could not move ssldir"

# 3. Request the new cert. The console pre-authorized this certname, so the
# policy-autosign hook signs it; if the authorization expired, the CSR waits
# for manual signing in the console (safe failure mode).
say "requesting new certificate"
"$PUPPET" agent -t --waitforcert 60
RC=$?
case "$RC" in
  0|2)
    say "re-cert complete; verifying trusted extensions"
    "$PUPPET" facts show trusted.extensions 1>&2 2>/dev/null || true
    say "old ssl state kept at ${SSLDIR}.recert-${STAMP} — remove after verifying"
    printf '{"status": "recertified", "ssl_backup": "%s"}\n' "${SSLDIR}.recert-${STAMP}"
    exit 0
    ;;
  1)
    fail_json "agent exited 1 — if the CSR is pending, the authorization may have expired; sign manually in the console or re-run recert. Rollback: rm -rf $SSLDIR && mv ${SSLDIR}.recert-${STAMP} $SSLDIR"
    ;;
  *)
    fail_json "agent exited ${RC}; old ssl state preserved at ${SSLDIR}.recert-${STAMP}"
    ;;
esac
