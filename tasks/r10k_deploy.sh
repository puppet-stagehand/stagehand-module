#!/bin/sh
# stagehand::r10k_deploy — deploy one environment's code via r10k.
# Pull-based on purpose (docs/design/code-management.md §5): this is the
# same mechanics as r10k's timer, run on demand from the console. Webhooks,
# promotion and policy are Enterprise (Code Manager territory) — not here.
set -u

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

ENVIRONMENT="${PT_environment:-production}"
case "$ENVIRONMENT" in
  *[!a-z0-9_]*|"") die "invalid environment name '$ENVIRONMENT'" ;;
esac

R10K="${PT_r10k_path:-}"
if [ -z "$R10K" ]; then
  for cand in /opt/puppetlabs/puppet/bin/r10k /usr/local/bin/r10k r10k; do
    if command -v "$cand" >/dev/null 2>&1; then R10K="$cand"; break; fi
  done
fi
[ -n "$R10K" ] || die "r10k not found — install it on the primary or pass r10k_path"

printf '>>> %s deploy environment %s --modules\n' "$R10K" "$ENVIRONMENT" >&2
OUT=$("$R10K" deploy environment "$ENVIRONMENT" --modules -v 2>&1)
STATUS=$?
printf '%s\n' "$OUT" | tail -n 40 >&2

if [ "$STATUS" -ne 0 ]; then
  printf '{"environment": "%s", "status": "error", "error": "r10k exited %s"}\n' "$ENVIRONMENT" "$STATUS"
  exit 0
fi

printf '{"environment": "%s", "status": "deployed"}\n' "$ENVIRONMENT"
