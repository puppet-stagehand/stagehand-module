#!/bin/sh
# stagehand::r10k_read_deploy_key — SECURITY-SENSITIVE. Reads an existing
# r10k/control-repo deploy key's PRIVATE key material off this host and
# returns it verbatim (D-19, 47-CONTEXT.md). This is a genuinely SEPARATE
# task from stagehand::r10k_detect (D-17's read-only, non-secret-reading
# discovery task, tasks/r10k_detect.sh) — never invoked as part
# of passive detection; only reachable via an endpoint requiring
# RoleGlobalAdmin AND an explicit, non-default operator consent click
# (T-47-16, three independent gates — see 47-07-PLAN.md's threat model).
# This task does exactly ONE thing: read one file's content. No bundling
# with r10k.yaml/Puppetfile findings — that already happened in
# r10k_detect.sh.
#
# Deliberately INVERTS discover.sh's own "sole source-of-truth redaction
# point" convention (see discover.sh's doc comment, this task's
# <read_first>) — D-19 explicitly WANTS this one secret to leave the node,
# exactly once, on operator consent. There is no redaction here because
# reading the secret verbatim is the entire point of this task.
#
# This script's stdout is a single JSON object, emitted ONLY on success
# (exit 0):
#   {"private_key": "<verbatim file content>", "key_path": "<resolved path>"}
# A missing, unreadable, or empty key path is a genuine task FAILURE —
# die() prints "ERROR: <real reason>" to stderr and exits 1. NEVER a
# silent empty/placeholder key and NEVER a success response with no key.
set -u

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Ruby interpreter for the JSON encode below — same PATH-fallback
# convention discover.sh/r10k_detect.sh already establish (targets
# frequently have no system ruby, only the puppet-agent-bundled one).
# PCM_R10K_READ_DEPLOY_KEY_RUBY_BIN is a test-only override, mirroring
# discover.sh's PCM_RUBY_BIN / r10k_detect.sh's PCM_R10K_DETECT_RUBY_BIN.
RUBY="${PCM_R10K_READ_DEPLOY_KEY_RUBY_BIN:-}"
if [ -z "$RUBY" ]; then
  if [ -x /opt/puppetlabs/puppet/bin/ruby ]; then
    RUBY=/opt/puppetlabs/puppet/bin/ruby
  else
    RUBY=ruby
  fi
fi

# PT_key_path is the task's one optional Bolt parameter. When omitted, fall
# back to the SAME conventional candidate locations r10k_detect.sh's own
# existence-only deploy-key probe uses (kept in exact sync — see that
# script's comment) so a path the wizard's detection step surfaced is
# always resolvable here unmodified, and an operator invoking this task
# directly (e.g. via `bolt task run`) without a key_path still gets
# sensible default behavior.
KEY_PATH="${PT_key_path:-}"
if [ -z "$KEY_PATH" ]; then
  for cand in /etc/puppetlabs/r10k/ssh/id_rsa /etc/puppetlabs/r10k/ssh/id_ed25519 "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
    if [ -f "$cand" ]; then
      KEY_PATH="$cand"
      break
    fi
  done
fi

[ -n "$KEY_PATH" ] || die "no key_path parameter supplied and no conventional deploy key location was found on this host"
[ -f "$KEY_PATH" ] || die "deploy key path does not exist: $KEY_PATH"
[ -r "$KEY_PATH" ] || die "deploy key path is not readable: $KEY_PATH"

"$RUBY" -rjson -e '
path = ARGV[0]
content = begin
  File.read(path)
rescue StandardError => e
  warn "could not read deploy key content at #{path}: #{e.message}"
  exit 1
end

if content.nil? || content.empty?
  warn "deploy key file at #{path} is empty"
  exit 1
end

puts JSON.generate({"private_key" => content, "key_path" => path})
' "$KEY_PATH" || die "failed to read/encode deploy key content at $KEY_PATH"

exit 0
