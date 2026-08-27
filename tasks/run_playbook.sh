#!/bin/sh
# stagehand::run_playbook — run a pasted Ansible playbook against the node itself
# via `ansible-playbook --connection=local -i localhost,` (Bolt pushes this
# task to the node; no separate Ansible control node exists). Ships as a
# Bolt task in the puppet_core module (staged here per the adapters
# convention, see 14.3-01-PLAN.md).
#
# Contract: playbook content and extra_vars are delivered ONLY via stdin
# JSON (Bolt input_method stdin) and are written to 0600 temp files removed
# on task exit — NEVER placed on the ansible-playbook argv (T-14.3-01,
# T-14.3-04). This script also re-validates (defense-in-depth; the console
# API is authoritative, D-04) that the playbook declares both
# `hosts: localhost` and `connection: local` before ever invoking
# ansible-playbook.
#
# Task params (stdin JSON object, per Bolt input_method stdin):
#   console_url      Console base URL (server-injected, unused by this script
#                     directly but accepted for parity with other stagehand tasks).
#   ingest_token      Server-injected (unused by this script directly).
#   playbook          Playbook YAML source (required).
#   extra_vars        JSON object text merged into the play; values may be
#                      already-resolved secret:// refs (optional).
#   tags               Comma-separated tags (optional).
#   skip_tags          Comma-separated skip-tags (optional).
#   check_mode         Boolean, default false — adds --check.
#   install_method     auto|package|pip|pipx|wsl|skip, default auto.
#
# This script's stdout is a single JSON object (D-07 — one run record for
# both the install step and the play):
#   {"install": {"method": "...", "status": "ok"|"error", "error": "..."},
#    "play":    {"status": "ok"|"failed", "output": "..."}}
# The script ALWAYS exits 0 — a failed install or a failed play is embedded
# status, not a task failure (same contract as discover.sh).
set -u

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Ruby interpreter for JSON handling. Targets frequently have NO system ruby
# on PATH — only the puppet-agent bundled one — so prefer the bundled
# interpreter and fall back to PATH ruby (dev machines / test harness).
# STAGEHAND_RUBY_BIN is a test-only override, mirroring STAGEHAND_ANSIBLE_BIN.
RUBY="${STAGEHAND_RUBY_BIN:-}"
if [ -z "$RUBY" ]; then
  if [ -x /opt/puppetlabs/puppet/bin/ruby ]; then
    RUBY=/opt/puppetlabs/puppet/bin/ruby
  else
    RUBY=ruby
  fi
fi

# json_field NAME JSON_TEXT
# Extracts a top-level field from JSON_TEXT and prints it as plain text
# (booleans/numbers stringified, nested objects/arrays re-serialized as JSON
# text — this is how extra_vars, itself JSON-object text nested inside the
# outer params object, round-trips unchanged). Prints "" (and never dies) on
# any parse error or missing key, so one malformed/optional field is never a
# reason to abort the whole task.
json_field() {
  name="$1"
  printf '%s' "$2" | "$RUBY" -rjson -e '
begin
  d = JSON.parse(STDIN.read)
  v = d[ARGV[0]]
  if v.nil?
    print ""
  elsif v == true
    print "true"
  elsif v == false
    print "false"
  elsif v.is_a?(Hash) || v.is_a?(Array)
    print JSON.generate(v)
  else
    print v.to_s
  end
rescue
  print ""
end
' "$name" 2>/dev/null
}

# json_escape TEXT is shared with the other Stagehand POSIX tasks. It prints
# a complete JSON string, including quotes, for arbitrary shell values.
if [ -n "${PT__installdir:-}" ] && [ -f "${PT__installdir}/stagehand/files/json_escape.sh" ]; then
  JSON_HELPER="${PT__installdir}/stagehand/files/json_escape.sh"
else
  JSON_HELPER="$(dirname "$0")/../files/json_escape.sh"
fi
[ -f "$JSON_HELPER" ] || die "JSON helper not found at $JSON_HELPER"
# shellcheck disable=SC1090
. "$JSON_HELPER"

# ---- read the whole stdin JSON params object once (Bolt stdin input_method) ----
RAW=$(cat)

PLAYBOOK=$(json_field playbook "$RAW")
EXTRA_VARS=$(json_field extra_vars "$RAW")
TAGS=$(json_field tags "$RAW")
SKIP_TAGS=$(json_field skip_tags "$RAW")
CHECK_MODE=$(json_field check_mode "$RAW")
INSTALL_METHOD=$(json_field install_method "$RAW")
[ -n "$INSTALL_METHOD" ] || INSTALL_METHOD="auto"

[ -n "$PLAYBOOK" ] || die "playbook parameter is required"

# ---- (1) reject a playbook that doesn't target itself locally, BEFORE the
# (system-mutating) install step below (WR-01) ----
# Server-side (handler) validation is authoritative (D-04) — this is
# defense-in-depth for direct/manual task invocation. Checked first so a
# bad playbook fails fast without ever touching the target's installed
# packages: install_ansible_run can shell out to apt-get/dnf/yum/zypper/
# pip/pipx, all of which are wasted (and, for apt-get et al., potentially
# unwanted side effects) if the play was never going to run anyway.
VALID=0
if printf '%s' "$PLAYBOOK" | grep -Fq 'hosts: localhost' \
  && printf '%s' "$PLAYBOOK" | grep -Fq 'connection: local'; then
  VALID=1
fi

if [ "$VALID" -ne 1 ]; then
  # install never ran — the JSON result shape ({"install":..., "play":...})
  # is preserved (same D-07 single-run-record contract), with install.status
  # "skipped" and a short reason instead of install_ansible_run's real
  # ok/error outcome, since that outcome was never produced.
  INSTALL_JSON=$(printf '{"method": %s, "status": "skipped", "error": %s}' \
    "$(json_escape "$INSTALL_METHOD")" \
    "$(json_escape 'install skipped: playbook failed hosts/connection validation')")
  PLAY_JSON=$(printf '{"status": "failed", "output": %s}' \
    "$(json_escape 'playbook must declare both hosts: localhost and connection: local (Bolt runs Ansible locally on the target)')")
  printf '{"install": %s, "play": %s}\n' "$INSTALL_JSON" "$PLAY_JSON"
  exit 0
fi

# ---- (2) install step, reusing install_ansible.sh's install_ansible_run ----
# install_ansible_run dispatches all six install_method strategies
# (auto/package/pip/pipx/wsl/skip, 14.3-02-PLAN.md) — this call site is
# unchanged from Plan 01: the seam already passed INSTALL_METHOD straight
# through, so a chained install's real method/status/error is embedded in
# INSTALL_JSON below and folded into this SAME run record (D-07), never a
# second Bolt invocation. Multi-host pass/fail (D-12) is Bolt-native: this
# script runs once per target, and the Go/Bolt envelope (not this task)
# marks the run failed if any host fails — no change needed here.
# STAGEHAND_PLAYBOOK_ANSIBLE_BIN is this script's own test-override env var for the
# binary the PLAY step invokes (step 4 below). It is folded into
# STAGEHAND_ANSIBLE_BIN before sourcing install_ansible.sh so the install step's
# presence-check targets the exact same binary the play step will run —
# tests only need to set one env var to control both. Neither is ever a Bolt
# param.
: "${STAGEHAND_PLAYBOOK_ANSIBLE_BIN:=${STAGEHAND_ANSIBLE_BIN:-ansible-playbook}}"
STAGEHAND_ANSIBLE_BIN="$STAGEHAND_PLAYBOOK_ANSIBLE_BIN"
export STAGEHAND_ANSIBLE_BIN

# Resolve install_ansible.sh: try the module-agnostic $0-relative sibling
# lookup FIRST (D-08) — a real Bolt run uploads a task's "files" entries
# into the SAME directory as the primary script (verified against Bolt
# 4.0.0's lib/bolt/shell/bash.rb run_task / lib/bolt/task.rb tasks_dir this
# phase), so this survives any future module rename with zero code changes.
# $PT__installdir/stagehand/tasks/install_ansible.sh (today's hardcoded
# module-name path) is the secondary fallback, kept for edge cases where $0
# isn't reliable — per D-07, this stays a one-off inline fix at this single
# call site, not a generalized helper.
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || die "could not resolve script dir"
if [ -f "$SCRIPT_DIR/install_ansible.sh" ]; then
  INSTALL_LIB="$SCRIPT_DIR/install_ansible.sh"
elif [ -n "${PT__installdir:-}" ] && [ -f "${PT__installdir}/stagehand/tasks/install_ansible.sh" ]; then
  INSTALL_LIB="${PT__installdir}/stagehand/tasks/install_ansible.sh"
else
  die "install_ansible.sh helper not found (checked \$0-relative and \$PT__installdir)"
fi

STAGEHAND_SOURCED=1
export STAGEHAND_SOURCED
# shellcheck disable=SC1090
. "$INSTALL_LIB"

INSTALL_JSON=$(install_ansible_run "$INSTALL_METHOD")

# ---- (3) write the playbook (and extra_vars, if present) to 0600 temp files ----
# Single EXIT trap for all three scratch files (playbook, extra_vars, and
# the ansible-playbook output capture below) — the one net-new safety step
# beyond the discover.sh template, since this script (unlike discover.sh)
# writes operator-pasted content (and, via OUT_FILE, potentially rendered
# secret values — CR-01) to disk (T-14.3-04, WR-03).
PLAYBOOK_FILE=""
EXTRA_VARS_FILE=""
OUT_FILE=""
trap 'rm -f "${PLAYBOOK_FILE:-}" "${EXTRA_VARS_FILE:-}" "${OUT_FILE:-}"' EXIT

PLAYBOOK_FILE=$(mktemp) || die "mktemp failed"
chmod 600 "$PLAYBOOK_FILE" || die "chmod failed"
printf '%s' "$PLAYBOOK" >"$PLAYBOOK_FILE"

# ---- (4) invoke ansible-playbook, playbook content only ever as a path ----
set -- --connection=local -i localhost,

if [ "$CHECK_MODE" = "true" ]; then
  set -- "$@" --check
fi

if [ -n "$EXTRA_VARS" ]; then
  EXTRA_VARS_FILE=$(mktemp) || die "mktemp failed"
  chmod 600 "$EXTRA_VARS_FILE" || die "chmod failed"
  printf '%s' "$EXTRA_VARS" >"$EXTRA_VARS_FILE"
  set -- "$@" --extra-vars "@$EXTRA_VARS_FILE"
fi

if [ -n "$TAGS" ]; then
  set -- "$@" --tags "$TAGS"
fi

if [ -n "$SKIP_TAGS" ]; then
  set -- "$@" --skip-tags "$SKIP_TAGS"
fi

set -- "$@" "$PLAYBOOK_FILE"

OUT_FILE=$(mktemp) || die "mktemp failed"
chmod 600 "$OUT_FILE" || die "chmod failed"
"$STAGEHAND_PLAYBOOK_ANSIBLE_BIN" "$@" >"$OUT_FILE" 2>&1
rc=$?
OUTPUT=$(cat "$OUT_FILE")
rm -f "$OUT_FILE"

if [ "$rc" -eq 0 ]; then
  STATUS="ok"
else
  STATUS="failed"
fi

PLAY_JSON=$(printf '{"status": "%s", "output": %s}' "$STATUS" "$(json_escape "$OUTPUT")")
printf '{"install": %s, "play": %s}\n' "$INSTALL_JSON" "$PLAY_JSON"
exit 0
