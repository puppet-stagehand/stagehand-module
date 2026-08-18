#!/bin/sh
# stagehand::discover — read-only RAL enumeration of an enrolled node's current
# package/user/group/service (default) and mount/cron (opt-in) state via
# `puppet resource <type> --to_yaml` (query form only). Ships as a Bolt task
# in the puppet_core module (staged here per the adapters convention).
# Contract: this is the task-script layer of the three-layer Core Safety
# Invariant (DISC-02) and the sole source-of-truth redaction point (DISC-03) —
# see .planning/research/PITFALLS.md Pitfall 1/2/3.
#
# Task params (env, per Bolt input_method environment):
#   PT_types   JSON-array text of requested type names, e.g.
#              ["package","user","group","service"] — Bolt's environment
#              input renders an Array param this way (see 14-01-PLAN.md
#              <interfaces> for the cross-plan CLI-encoding contract with
#              Plan 14-03's handleBoltDiscover, which sends the CLI token
#              types=["package",...]).
#
# This script's stdout is a single JSON object (Contract A, 14-01-PLAN.md):
#   {"types": {"<type>": {"status": "ok"|"timeout"|"error", "resources": {...} | "error": "..."}}}
# The script ALWAYS exits 0 — a per-type timeout/error is not a task failure.
#
# POSIX/Linux-only task this phase — no discover.ps1 companion (Windows
# discovery is out of scope this phase, see 14-01-PLAN.md objective / D-05).
set -u

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# STAGEHAND_DISCOVER_PUPPET_BIN exists solely so discover_test.sh can point this
# script at a stub puppet binary on a curated PATH (mirroring
# trivy_scan_checksum_test.sh's SHIM_* pattern). It is NEVER a Bolt PT_ param
# and never influences which resource TYPE is queried.
PUPPET="${STAGEHAND_DISCOVER_PUPPET_BIN:-/opt/puppetlabs/bin/puppet}"
[ -x "$PUPPET" ] || die "puppet agent not installed at $PUPPET"

# Per-type timeout (Pitfall 2 — one slow/aged-host type must not consume the
# whole task budget). Default: timeout 60 seconds. Overridable via
# STAGEHAND_DISCOVER_TIMEOUT_SECS for the test harness only (never a Bolt PT_
# param) so discover_test.sh's timeout case doesn't have to wait out a real
# 60-second timeout.
TIMEOUT_SECS="${STAGEHAND_DISCOVER_TIMEOUT_SECS:-60}"

RAW_TYPES="${PT_types:-}"
[ -n "$RAW_TYPES" ] || die "types parameter is required"

# convert_to_json TYPE < yaml-on-stdin > json-on-stdout
#
# Converts one type's `puppet resource <type> --to_yaml` output into a JSON
# object, redacting sensitive fields BEFORE the value is placed into the
# aggregate result (Pitfall 3, "redact ASAP, closest to the secret"):
#   - every `password` attribute value is structurally rewritten to
#     "<redacted>" (walks the parsed object rather than grepping text, so it
#     is robust to formatting) — DISC-03, all types.
#   - for `cron` only, common secret-shaped substrings in string values
#     (token=…, password=…, *_KEY=…, AKIA-style AWS keys) are best-effort
#     regex-redacted (D-04) — the UI's "review carefully" warning is the
#     real safeguard for anything this regex misses.
# Returns non-zero (and no stdout) if the YAML cannot be parsed, so the
# caller reports status=error for that type instead of crashing the task.
convert_to_json() {
  ruby -ryaml -rjson -e '
type = ARGV[0]

def redact_passwords(obj)
  case obj
  when Hash
    obj.each do |k, v|
      if k.to_s == "password"
        obj[k] = "<redacted>"
      else
        redact_passwords(v)
      end
    end
  when Array
    obj.each { |e| redact_passwords(e) }
  end
  obj
end

SECRET_PATTERNS = [
  /([A-Za-z0-9_]*token[A-Za-z0-9_]*=)\S+/i,
  /([A-Za-z0-9_]*password[A-Za-z0-9_]*=)\S+/i,
  /([A-Za-z0-9_]*_KEY=)\S+/i,
  /AKIA[0-9A-Z]{16}/,
]

def redact_secret_strings(obj)
  case obj
  when Hash
    obj.each do |k, v|
      if v.is_a?(String)
        s = v.dup
        SECRET_PATTERNS.each { |re| s = s.gsub(re) { "#{$1}<redacted>" } }
        obj[k] = s
      else
        redact_secret_strings(v)
      end
    end
  when Array
    obj.each { |e| redact_secret_strings(e) }
  end
  obj
end

data = YAML.safe_load(STDIN.read)
data = {} unless data.is_a?(Hash) || data.is_a?(Array)
redact_passwords(data)
redact_secret_strings(data) if type == "cron"
puts JSON.generate(data)
' "$1"
}

# Normalize PT_types (JSON-array text, e.g. ["package","user"]) into raw
# comma-separated tokens by stripping the array's brackets/quotes. Anything
# else in an individual element (including garbage a caller might smuggle
# into one element) is left completely intact and handled per-token below —
# one bad element is never a reason to abandon the whole request.
STRIPPED=$(printf '%s' "$RAW_TYPES" | tr -d '[]"')

BODY=""
FIRST=1

OLD_IFS=$IFS
IFS=,
set -f
for raw_token in $STRIPPED; do
IFS=$OLD_IFS
set +f

  # Trim leading/trailing whitespace a JSON-array rendering may add around
  # commas (e.g. `["package", "user"]`).
  type=$(printf '%s' "$raw_token" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')

  # Coarse charset gate (Pitfall 1 defense-in-depth, ahead of the exact-
  # match allowlist below): every one of the six legitimate type names is
  # pure lowercase ASCII, so a token containing anything else (e.g. a stray
  # `evil;rm -rf` element) can never legitimately match and is rejected
  # here — before it even reaches the case statement, and without aborting
  # the other, well-formed tokens in the same request.
  case "$type" in
    *[!a-z_]*) continue ;;
  esac

  # HARDCODED exact-match allowlist — the only six tokens `puppet resource`
  # is ever invoked with. Anything not matching is skipped, never passed to
  # puppet (DISC-02, script layer of the Core Safety Invariant).
  case "$type" in
    package|user|group|service|mount|cron) ;;
    *) continue ;;
  esac

  OUT_FILE=$(mktemp) || die "mktemp failed"
  ERR_FILE=$(mktemp) || die "mktemp failed"

  timeout "$TIMEOUT_SECS" "$PUPPET" resource "$type" --to_yaml >"$OUT_FILE" 2>"$ERR_FILE"
  rc=$?

  if [ "$rc" -eq 124 ]; then
    entry=$(printf '"%s": {"status": "timeout", "error": "timed out after %ss"}' "$type" "$TIMEOUT_SECS")
  elif [ "$rc" -ne 0 ]; then
    entry=$(printf '"%s": {"status": "error", "error": "puppet resource %s --to_yaml failed (exit %s)"}' "$type" "$type" "$rc")
  else
    resources_json=$(convert_to_json "$type" <"$OUT_FILE" 2>/dev/null)
    conv_rc=$?
    if [ "$conv_rc" -ne 0 ] || [ -z "$resources_json" ]; then
      entry=$(printf '"%s": {"status": "error", "error": "could not convert puppet resource %s output to JSON"}' "$type" "$type")
    else
      entry=$(printf '"%s": {"status": "ok", "resources": %s}' "$type" "$resources_json")
    fi
  fi

  rm -f "$OUT_FILE" "$ERR_FILE"

  if [ "$FIRST" -eq 1 ]; then
    BODY="$entry"
    FIRST=0
  else
    BODY="$BODY, $entry"
  fi
done
IFS=$OLD_IFS
set +f

printf '{"types": {%s}}\n' "$BODY"
exit 0
