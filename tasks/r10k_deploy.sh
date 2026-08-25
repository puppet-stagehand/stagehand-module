#!/bin/sh
# stagehand::r10k_deploy — deploy one environment's code via r10k.
# Pull-based on purpose (docs/design/code-management.md §5): this is the
# same mechanics as r10k's timer, run on demand from the console. Webhooks,
# promotion and policy are Enterprise (Code Manager territory) — not here.
#
# Phase 47, D-10's remote half: when the console-side Puppetfile scan
# matched git_credentials for one or more hosts the control repo's
# Puppetfile references, it stages them here as two OPTIONAL task
# parameters — PT_git_ssh_config (an ssh_config-format string with a
# %%GIT_SSH_KEYSDIR%% placeholder, gitops.BuildMultiHostSSHConfig) and
# PT_git_ssh_keys (a JSON object: sanitized host -> PEM key content). When
# PT_git_ssh_config is set, this script stages both into a per-run
# mktemp -d temp dir (unpredictable path, not a fixed well-known location —
# T-47-12), substitutes the real keys dir for the placeholder, points
# GIT_SSH_COMMAND at the staged config for the r10k invocation ONLY, and
# removes the whole temp dir via a POSIX sh `trap` on EXIT/INT/TERM — so
# cleanup fires on success, on r10k failure, AND on the process being
# killed, all from inside this ONE task invocation (Open Question 1,
# resolved: no separate follow-up Bolt call). When PT_git_ssh_config is
# unset (the existing, common case), none of this runs — behavior is
# byte-for-byte identical to the pre-Phase-47 script.
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

if [ -n "${PT_git_ssh_config:-}" ]; then
  GIT_SSH_TMPDIR=$(mktemp -d) || die "mktemp -d failed for git ssh config staging"
  # Fires on normal exit, r10k failure (die below), AND process kill (INT/
  # TERM) — the whole reason this lives inside one task invocation rather
  # than a separate follow-up Bolt call.
  trap 'rm -rf "$GIT_SSH_TMPDIR"' EXIT INT TERM
  mkdir -p "$GIT_SSH_TMPDIR/keys" || die "mkdir keys dir failed"

  # Substitute the console-side placeholder (Task 1, sshconfig.go — the
  # console cannot know this run's mktemp -d path in advance) for the real
  # staged keys directory, then write the resulting ssh_config content.
  printf '%s' "$PT_git_ssh_config" |
    sed "s#%%GIT_SSH_KEYSDIR%%#$GIT_SSH_TMPDIR/keys#g" >"$GIT_SSH_TMPDIR/config" ||
    die "failed to write staged git ssh config"
  chmod 600 "$GIT_SSH_TMPDIR/config"

  GIT_SSH_RUBY="${PCM_RUBY_BIN:-}"
  if [ -z "$GIT_SSH_RUBY" ]; then
    if [ -x /opt/puppetlabs/puppet/bin/ruby ]; then
      GIT_SSH_RUBY=/opt/puppetlabs/puppet/bin/ruby
    else
      GIT_SSH_RUBY=ruby
    fi
  fi
  # Same RUBY -rjson convention discover.sh already establishes for
  # parsing a Bolt-delivered JSON param — writes each key file directly
  # from Ruby (avoids a second shell-level JSON parser for multiline PEM
  # content) and chmod 600s it immediately.
  GIT_SSH_KEYS_JSON="${PT_git_ssh_keys:-}"
  [ -n "$GIT_SSH_KEYS_JSON" ] || GIT_SSH_KEYS_JSON='{}'
  printf '%s' "$GIT_SSH_KEYS_JSON" | "$GIT_SSH_RUBY" -rjson -e '
keysdir = ARGV[0]
data = JSON.parse(STDIN.read)
data.each do |host, pem|
  path = File.join(keysdir, host)
  File.open(path, "w", 0600) { |f| f.write(pem) }
  File.chmod(0600, path)
end
' "$GIT_SSH_TMPDIR/keys" || die "failed to stage git ssh keys"

  # Scoped to THIS script's process (and the r10k subprocess it execs
  # below) via export — never written to a persistent shell profile or
  # system-wide config (T-47-14, accepted risk).
  export GIT_SSH_COMMAND="ssh -F $GIT_SSH_TMPDIR/config"
fi

printf '>>> %s deploy environment %s --modules\n' "$R10K" "$ENVIRONMENT"
OUT=$("$R10K" deploy environment "$ENVIRONMENT" --modules -v 2>&1)
STATUS=$?
printf '%s\n' "$OUT" | tail -n 40
[ $STATUS -eq 0 ] || die "r10k exited $STATUS"

printf '{"environment": "%s", "status": "deployed"}\n' "$ENVIRONMENT"
